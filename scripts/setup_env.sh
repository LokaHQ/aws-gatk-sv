#!/bin/bash

set -x

whoami
sudo yum update -y
sudo yum install -y jq

# Install docker
sudo amazon-linux-extras install docker -y

sudo service docker start
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user
newgrp docker

# Install pip packages
python3 -m pip install jinja2