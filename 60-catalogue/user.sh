#!/bin/bash
component=$1
environment=$2
dnf install ansible -y # whereever ansible installs it becomes ansible server
REPO_URL=https://github.com/Deepthi-GH/ansible-roboshop-roles-tf.git
ANSIBLE_DIR=ansible-roboshop-roles-tf
REPO_DIR=/opt/roboshop/ansible

mkdir -p /var/log/roboshop
mkdir -p $REPO_DIR
touch ansible.log
cd $REPO_DIR
if [ -d $ANSIBLE_DIR]
then
    cd $ANSIBLE_DIR
    git pull 
else
    git clone $REPO_URL
    cd $ANSIBLE_DIR
fi 

echo "environment is: $2"
ansible-playbook -e component=$component -e env=$environment main.yml