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
MAIN_ROUTE_TABLE=$(aws cloudformation describe-stacks --stack-name "${STACK_NAME}" --query "Stacks[].Outputs[?OutputKey=='RouteTable'].OutputValue" --output text)
DEFAULT_REGION=$(aws configure get region)

for region in $(aws ec2 describe-regions --query "Regions[].RegionName" | jq -r '.[]')
do 
  echo "Creating a CloudFormation stack=${STACK_NAME} for region=${region}"
  aws cloudformation create-stack \
    --stack-name "${STACK_NAME}" \
    --template-body file://cloudformation.yaml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameters ParameterKey=SSHLocation,ParameterValue="${SSH_LOCATION}" \
                ParameterKey=AWSAccountIdForMainVPC,ParameterValue="${AWS_ACCOUNT_ID}" \
                ParameterKey=PeerVpcId,ParameterValue="${MAIN_VPC_ID}" \
                ParameterKey=PeerRoleArn,ParameterValue="${PEER_ROLE_ARN}" \
                ParameterKey=PeerRegion,ParameterValue="${DEFAULT_REGION}" \
    --region "${region}"

  # Doing this in CloudFormation is pretty tediuos as described in README.md, so doing it in AWS CLI
  echo "Adding VPC peering route to the main VPC's route table"
  VPC_PEERING_CONNECTION=$(aws cloudformation describe-stacks --stack-name "${STACK_NAME}" --query "Stacks[].Outputs[?OutputKey=='PeerRoleArn'].OutputValue" --output text)
  VPC_CIDR_BLOCK=$(aws cloudformation describe-stacks --stack-name "${STACK_NAME}" --query "Stacks[].Outputs[?OutputKey=='VPCCidrBlock'].OutputValue" --output text)
  aws ec2 create-route \
    --route-table-id ${MAIN_ROUTE_TABLE} \
    --destination-cidr-block ${VPC_CIDR_BLOCK} \
    --vpc-peering-connection-id ${VPC_PEERING_CONNECTION}

done 

