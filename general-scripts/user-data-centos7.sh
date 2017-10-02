#!/bin/bash

set -x

## https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo BEGIN
date '+%Y-%m-%d %H:%M:%S'

### Run the update
sudo yum -y update

### Install docker
curl -fsSL https://get.docker.com/ | sh

### Start the service
sudo systemctl start docker

### Check the service runs
sudo systemctl status docker

### Add the service to start up
sudo systemctl enable docker

### Add the centos to the docker group
sudo usermod -aG docker centos

### install unzip and some other useful utilities
sudo yum -y install unzip telnet wget

### Add the aws cli
curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip"

### unzip
unzip awscli-bundle.zip

### install
./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws


### add to path
export PATH=/usr/local/bin:$PATH

### Add to the bash profile
echo "echo $PATH | grep /usr/local/bin"  | tee -a ~/.bash_profile
echo "export PATH=/usr/local/bin:$PATH" | tee -a ~/.bash_profile

echo END