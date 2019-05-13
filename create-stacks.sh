#!/bin/sh

# parse options
MULTI_REGION="true"
for OPT in "$@"
do
    case "$OPT" in
        '--single-region' )
          MULTI_REGION="false"
    esac
done

AWS_ACCOUNT_ID="$(aws sts get-caller-identity | jq -r '.Account')" \
SSH_LOCATION="$(curl ifconfig.co 2> /dev/null)/32"
STACK_NAME="PingExperiment"
DEFAULT_REGION=$(aws configure get region)

if ! aws cloudformation describe-stacks --stack-name "${STACK_NAME}" 2>/dev/null ; then
  echo "creating the main CloudFormation stack for ${DEFAULT_REGION}"
  aws cloudformation create-stack \
    --stack-name "${STACK_NAME}" \
    --template-body file://cloudformation.yaml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameters ParameterKey=SSHLocation,ParameterValue="${SSH_LOCATION}" \
                 ParameterKey=AWSAccountIdForMainVPC,ParameterValue="${AWS_ACCOUNT_ID}" \
    --output text
fi

echo "Waiting until the Cloudformation VPC main stack is CREATE_COMPLETE in ${DEFAULT_REGION}"
aws cloudformation wait stack-create-complete --stack-name "${STACK_NAME}"

if [ "${MULTI_REGION}" = "true" ]; then
  MAIN_VPC_ID=$(aws cloudformation describe-stacks --stack-name "${STACK_NAME}" --query "Stacks[].Outputs[?OutputKey=='VPCId'].OutputValue" --output text)
  PEER_ROLE_ARN=$(aws cloudformation describe-stacks --stack-name "${STACK_NAME}" --query "Stacks[].Outputs[?OutputKey=='PeerRoleArn'].OutputValue" --output text)
  MAIN_ROUTE_TABLE=$(aws cloudformation describe-stacks --stack-name "${STACK_NAME}" --query "Stacks[].Outputs[?OutputKey=='RouteTable'].OutputValue" --output text)

  for region in $(aws ec2 describe-regions --query "Regions[].RegionName" | jq -r '.[]')
  do 
    if [ "${region}" != "${DEFAULT_REGION}" ]; then
      if ! aws cloudformation describe-stacks --stack-name "${STACK_NAME}" --region "${region}" 2> /dev/null; then
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
          --region "${region}" \
          --output text
      fi
    fi
  done 

  for region in $(aws ec2 describe-regions --query "Regions[].RegionName" | jq -r '.[]')
  do 
    if [ "${region}" != "${DEFAULT_REGION}" ]; then
      echo "Waiting until the Cloudformation stack is CREATE_COMPLETE for ${region}"
      if aws cloudformation wait stack-create-complete --stack-name "${STACK_NAME}" --region "${region}"; then
        # Doing this in the shell script, because doing the same in CloudFormation is pretty
        # tediuos as described in README.md, so doing it in AWS CLI
        echo "Adding VPC peering route to the route table of the main VPC"
        VPC_PEERING_CONNECTION=$(aws cloudformation describe-stacks --stack-name "${STACK_NAME}" --query "Stacks[].Outputs[?OutputKey=='VPCPeeringConnection'].OutputValue" --output text --region "${region}")
        VPC_CIDR_BLOCK=$(aws cloudformation describe-stacks --stack-name "${STACK_NAME}" --query "Stacks[].Outputs[?OutputKey=='VPCCidrBlock'].OutputValue" --output text --region "${region}")
        aws ec2 create-route \
          --route-table-id "${MAIN_ROUTE_TABLE}" \
          --destination-cidr-block "${VPC_CIDR_BLOCK}" \
          --vpc-peering-connection-id "${VPC_PEERING_CONNECTION}" \
          --output text
      else
        echo "ERROR: Could not add VPC peering to the route table of the main VPC"
      fi
    fi
  done 
fi