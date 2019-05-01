#!/bin/sh

# Any subsequent(*) commands which fail will cause the shell script to exit immediately
set -e

AWS_ACCOUNT_ID="$(aws sts get-caller-identity | jq -r '.Account')" \
SSH_LOCATION="$(curl ifconfig.co 2> /dev/null)/32"
STACK_NAME_VPC_MAIN="PingMainVPC"

echo "creating the main CloudFormation stack"
aws cloudformation create-stack \
  --stack-name "${STACK_NAME_VPC_MAIN}" \
  --template-body file://cloudformation.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameters ParameterKey=SSHLocation,ParameterValue="${SSH_LOCATION}" \
               ParameterKey=PeerRequesterAccountId,ParameterValue="${AWS_ACCOUNT_ID}"

echo "Waiting until the Cloudformation VPC main stack is CREATE_COMPLETE"
aws cloudformation wait stack-create-complete --stack-name "${STACK_NAME_VPC_MAIN}"

echo "creating a sub CloudFormation stack"
aws cloudformation create-stack \
  --stack-name "substack" \
  --template-body file://cloudformation.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameters ParameterKey=SSHLocation,ParameterValue="${SSH_LOCATION}" \
               ParameterKey=PeerRequesterAccountId,ParameterValue="${AWS_ACCOUNT_ID}" \
  --region "us-east-1"               
