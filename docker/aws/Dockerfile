See 'docker exec --help'.
fergusmacdermot@fergus:~/Documents/git-repo-orig/mvp-servers-setup/cloud/aws/general-scripts$ docker run -it awscli run.sh
docker: Error response from daemon: oci runtime error: container_linux.go:262: starting container process caused "exec: \"run.sh\": executable file not found in $PATH".
fergusmacdermot@fergus:~/Documents/git-repo-orig/mvp-servers-setup/cloud/aws/general-scripts$ docker run -it awscli /script/./run.sh
+ :
+ sleep 300
^Cfergusmacdermot@fergus:~/Documents/git-repo-orig/mvp-servers-setup/cloud/aws/general-scripts$ docker run -it awscli aws --version
aws-cli/1.11.162 Python/2.7.13 Linux/4.9.41-moby botocore/1.7.20
fergusmacdermot@fergus:~/Documents/git-repo-orig/mvp-servers-setup/cloud/aws/general-scripts$ docker run -it awscli aws describe-instances
usage: aws [options] <command> <subcommand> [<subcommand> ...] [parameters]

FROM alpine:3.6
RUN apk update && apk add tzdata bash curl less groff jq python py-pip py2-pip && \ 
     pip install --upgrade pip awscli s3cmd && \
     mkdir /root/.aws

RUN mkdir /script

WORKDIR /script
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
COPY run.sh /script

#ENTRYPOINT ["./run.sh"]
