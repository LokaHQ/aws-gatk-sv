#!/bin/bash

set -x

whoami
sudo yum update -y
sudo amazon-linux-extras install docker -y

sudo service docker start
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user
newgrp docker

docker info
sudo systemctl status docker
docker run hello-world