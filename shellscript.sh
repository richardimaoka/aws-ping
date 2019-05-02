#!/bin/sh

AWS_ACCOUNT_ID="$(aws sts get-caller-identity | jq -r '.Account')" \
SSH_LOCATION="$(curl ifconfig.co 2> /dev/null)/32"
STACK_NAME_VPC_MAIN="PingMainVPC"

STACK_EXISTS=$(aws cloudformation describe-stacks --stack-name "${STACK_NAME_VPC_MAIN}")

if [ -z "${STACK_EXISTS}" ]; then
  echo "creating the main CloudFormation stack"
  aws cloudformation create-stack \
    --stack-name "${STACK_NAME_VPC_MAIN}" \
    --template-body file://cloudformation.yaml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameters ParameterKey=SSHLocation,ParameterValue="${SSH_LOCATION}" \
                 ParameterKey=AWSAccountIdForMainVPC,ParameterValue="${AWS_ACCOUNT_ID}"
fi

echo "Waiting until the Cloudformation VPC main stack is CREATE_COMPLETE"
aws cloudformation wait stack-create-complete --stack-name "${STACK_NAME_VPC_MAIN}"

aws cloudformation describe-stacks --stack-name "${STACK_NAME_VPC_MAIN}" 
MAIN_VPC_ID=$(aws cloudformation describe-stacks --stack-name "${STACK_NAME_VPC_MAIN}" --query "Stacks[].Outputs[?OutputKey=='VPCId'].OutputValue" --output text)
PEER_ROLE_ARN=$(aws cloudformation describe-stacks --stack-name "${STACK_NAME_VPC_MAIN}" --query "Stacks[].Outputs[?OutputKey=='PeerRoleARN'].OutputValue" --output text)


echo "creating a sub CloudFormation stack"
aws cloudformation create-stack \
  --stack-name "substack" \
  --template-body file://cloudformation.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameters ParameterKey=SSHLocation,ParameterValue="${SSH_LOCATION}" \
               ParameterKey=AWSAccountIdForMainVPC,ParameterValue="${AWS_ACCOUNT_ID}" \
               ParameterKey=PeerVpcId,ParameterValue="${MAIN_VPC_ID}" \
               ParameterKey=PeerRoleARN,ParameterValue="${PEER_ROLE_ARN}" \
  --region "us-east-1"               
