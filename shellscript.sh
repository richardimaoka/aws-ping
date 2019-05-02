#!/bin/sh

AWS_ACCOUNT_ID="$(aws sts get-caller-identity | jq -r '.Account')" \
SSH_LOCATION="$(curl ifconfig.co 2> /dev/null)/32"
STACK_NAME="PingExperiment"

STACK_EXISTS=$(aws cloudformation describe-stacks --stack-name "${STACK_NAME}" 2>/dev/null)

if [ -z "${STACK_EXISTS}" ]; then
  echo "creating the main CloudFormation stack"
  aws cloudformation create-stack \
    --stack-name "${STACK_NAME}" \
    --template-body file://cloudformation.yaml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameters ParameterKey=SSHLocation,ParameterValue="${SSH_LOCATION}" \
                 ParameterKey=AWSAccountIdForMainVPC,ParameterValue="${AWS_ACCOUNT_ID}"
fi

echo "Waiting until the Cloudformation VPC main stack is CREATE_COMPLETE"
aws cloudformation wait stack-create-complete --stack-name "${STACK_NAME}"

MAIN_VPC_ID=$(aws cloudformation describe-stacks --stack-name "${STACK_NAME}" --query "Stacks[].Outputs[?OutputKey=='VPCId'].OutputValue" --output text)
PEER_ROLE_ARN=$(aws cloudformation describe-stacks --stack-name "${STACK_NAME}" --query "Stacks[].Outputs[?OutputKey=='PeerRoleArn'].OutputValue" --output text)
DEFAULT_REGION=$(aws configure get region)
echo "${DEFAULT_REGION}"
echo "creating a sub CloudFormation stack"
aws cloudformation create-stack \
  --stack-name "${STACK_NAME}" \
  --template-body file://cloudformation.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameters ParameterKey=SSHLocation,ParameterValue="${SSH_LOCATION}" \
               ParameterKey=AWSAccountIdForMainVPC,ParameterValue="${AWS_ACCOUNT_ID}" \
               ParameterKey=PeerVpcId,ParameterValue="${MAIN_VPC_ID}" \
               ParameterKey=PeerRoleArn,ParameterValue="${PEER_ROLE_ARN}" \
               ParameterKey=PeerRegion,ParameterValue="${DEFAULT_REGION}" \
  --region "us-east-1"               
