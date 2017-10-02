#!/bin/sh
##################################################
###### The script does the following:
# - creates a key based on the profile name
# - creates a security group called ssh-access-SG, then deletes after execution
# - creates a micro instance with aws cli and docker installed, then terminates once the image is taken
# - polls the image until the user data load has completed
# - verifies that aws cli and docker are installed
# - creates an AMI based on the instance
# - terminates the instance
# - deletes the ssh-access-SG security group
###### Other notes:
# - images instances based on the image id supplied
# - uses default profile if none is supplied.
# - default ssh user is centos
# - only the image id needs changing as they are region specific.
##################################################

set -x

echo "###################### Creating an AMI ########################"

### Validate we have enough parameters
if (( $# < 1 )); then
    echo "###### Error, not enough arguments supplied. Please get a valid AMI for your default region. Read the script header for more information ###### \n/ec2-create-docker-image.sh <image-id> [profile optional]"
    exit 1
fi

### The ec2 user for login: centos|ec2-user|ubuntu etc etc
EC2_USER=centos

### Name for the instance tag
INSTANCE_TAG="Centos7 with Docker and aws cli"

################ Set the node instance type - leave alone
INSTANCE_TYPE=t2.micro

### The image ID
IMAGE_ID=$1

if [ -z "$2" ]
  then
    echo "Using default profile"
    PROFILE="default"
  else
    PROFILE=$2
fi

echo $PROFILE

### Create the audit log
LOG_FILE="create-docker-image-audit.log"
echo "The following things happened:" | tee $LOG_FILE

### Create a private key using the profile name that can be used to login and verify the build
### $PROFILE.pem
aws ec2 create-key-pair --key-name $PROFILE --query 'KeyMaterial' --output text >>$PROFILE.pem
echo "\t created a new key named: $PROFILE" | tee -a $LOG_FILE
### Change the permissions on the pem
chmod 400 $PROFILE.pem
echo "\t changed permissions on the key to: 400" | tee -a $LOG_FILE

###
####################### Load balancer
### Create the security group so we can login to verify the user data worked
SSH_PORT=22
SECURITY_GROUP_NAME=ssh-access-SG

SECURITY_GROUP_ID=$(aws ec2 create-security-group --profile $PROFILE --group-name $SECURITY_GROUP_NAME \
    --description "Security group for SSH access" --query 'GroupId' --output text)
echo "\t created a new security group named: $SECURITY_GROUP_NAME, id: $SECURITY_GROUP_ID" | tee -a $LOG_FILE
### Open up port 22
aws ec2 authorize-security-group-ingress --profile $PROFILE --group-id $SECURITY_GROUP_ID \
    --protocol tcp --port $SSH_PORT --cidr 0.0.0.0/0
echo "\t opened up port: $SSH_PORT" | tee -a $LOG_FILE
### Create a name tag so it looks nicer in the console
aws ec2 create-tags --profile $PROFILE --resources $SECURITY_GROUP_ID --tags Key=Name,Value=$SECURITY_GROUP_NAME
echo "\t tagged security group" | tee -a $LOG_FILE


###### To have custom scripts run on an instance at first boot up time add this:
###### --user-data file://user-data-centos7.sh
###### anywhere before the --query flag
###### To create an instance that you can ssh in to, add this --key-name <key-name> where <key-name> is a key
###### that you have access to and
###### e.g. aws ec2 run-instances --profile $PROFILE --image-id $IMAGE_ID --instance-type $INSTANCE_TYPE --key-name <keyname> --user-data file://user-data-centos.sh --associate-public-ip-address --query 'Instances[0].InstanceId' --output text
###### exists in your region.
INSTANCE_ID=$(aws ec2 run-instances --profile $PROFILE --image-id $IMAGE_ID --instance-type $INSTANCE_TYPE \
    --key-name $PROFILE --user-data file://user-data-centos7.sh --security-group-ids $SECURITY_GROUP_ID \
    --associate-public-ip-address \
    --query 'Instances[0].InstanceId' --output text)

echo "\t created a new instance with id: $INSTANCE_ID" | tee -a $LOG_FILE
### Change the tag name to something meaningful
aws ec2 create-tags --profile $PROFILE --resources $INSTANCE_ID --tags Key=Name,Value="$INSTANCE_TAG"
echo "\t tagged instance: $INSTANCE_TAG" | tee -a $LOG_FILE

### Make sure the status is ok, which means up and running
aws ec2 wait instance-status-ok --profile $PROFILE --instance-ids $INSTANCE_ID
echo "\t instance came up" | tee -a $LOG_FILE

NODE_IP=$(aws ec2 describe-instances --profile $PROFILE --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)


while true
do
  ssh -o "StrictHostKeyChecking no" -i "$PROFILE.pem" $EC2_USER@$NODE_IP ls /var/lib/cloud/instances/$INSTANCE_ID/boot-finished > /dev/null 2>&1
  if [ $? -eq 0 ] ; then
      echo "the job is done"
      break
  else
     echo [INFO] Sleeping for 30 secs
     sleep 30;
  fi
done

### Validate aws is installed
ssh -o "StrictHostKeyChecking no" -i "$PROFILE.pem" $EC2_USER@$NODE_IP aws --version

ssh -o "StrictHostKeyChecking no" -i "$PROFILE.pem" $EC2_USER@$NODE_IP docker --version

### Once it's up and running then we can create the new image id - this appears in the Image/AMI section of the
### management console. The name is unique, so change to something meaningful
NEW_IMAGE_ID=$(aws ec2 create-image --profile $PROFILE --instance-id $INSTANCE_ID --name "AMI Template with Docker and aws cli" \
    --description "Image that contains aws cli and docker" --query 'ImageId' --output text)

echo "\t created a new image (AMI): $NEW_IMAGE_ID" | tee -a $LOG_FILE
aws ec2 create-tags --profile $PROFILE --resources $NEW_IMAGE_ID  --tags Key=Name,Value="$INSTANCE_TAG"

### Let's make sure the image is available
aws ec2 wait image-available --profile $PROFILE --image-ids $NEW_IMAGE_ID
echo "\t image now available" | tee -a $LOG_FILE

### Once it becomes available, we can delete the old instance
aws ec2 terminate-instances --profile $PROFILE --instance-ids $INSTANCE_ID
echo "\t deleted old instance: $INSTANCE_ID" | tee -a $LOG_FILE

aws ec2 wait instance-terminated --profile $PROFILE --instance-ids $INSTANCE_ID

### Revoke security group access
aws ec2 revoke-security-group-ingress --profile $PROFILE --group-id $SECURITY_GROUP_ID --protocol \
    tcp --port $SSH_PORT --cidr 0.0.0.0/0
echo "\t revoked security group access" | tee -a $LOG_FILE

### Delete the security group
aws ec2 delete-security-group --profile $PROFILE --group-id $SECURITY_GROUP_ID
echo "\t deleted security group" | tee -a $LOG_FILE