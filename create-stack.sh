#!/bin/sh

# cd to the current directory as it runs other shell scripts
cd "$(dirname "$0")" || exit

######################################
# 1.1 Parse options
######################################
for OPT in "$@"
do
  case "$OPT" in
    '--stack-name' )
      if [ -z "$2" ]; then
          echo "option -f or --stack-name requires an argument -- $1" 1>&2
          exit 1
      fi
      STACK_NAME="$2"
      shift 2
      ;;
  esac
done

######################################
# 1.2 Validate options
######################################
if [ -z "${STACK_NAME}" ] ; then
  >&2 echo "ERROR: Option --stack-name needs to be specified"
  exit 1
fi

######################################
# 2. Create a CloudFormation stack
######################################
AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
SSH_LOCATION="$(curl ifconfig.co 2> /dev/null)/32"

SECOND_OCTET=101
for REGION in $(aws ec2 describe-regions --query "Regions[].RegionName" --output text)
do
  if ! aws cloudformation describe-stacks --stack-name "${STACK_NAME}" --region "${REGION}" > /dev/null 2>&1 ; then
    echo "Creating a CloudFormation stack=${STACK_NAME} for region=${REGION}"

    NUM_AVAILABILITY_ZONES=$(aws ec2 describe-availability-zones --query "AvailabilityZones[?State=='available'] --region "${REGION}" | length(@)") 
    VPC_CIDR_BLOCK="10.${SECOND_OCTET}.0.0/16"
    REGION_SUBNET="10.${SECOND_OCTET}"
    echo "${REGION}: ${NUM_AVAILABILITY_ZONES}"

    # If it fails, an error message is displayed and it continues to the next REGION
    aws cloudformation create-stack \
      --stack-name "${STACK_NAME}" \
      --template-body file://cloudformation-vpc.yaml \
      --capabilities CAPABILITY_NAMED_IAM \
      --parameters ParameterKey=SSHLocation,ParameterValue="${SSH_LOCATION}" \
                   ParameterKey=AWSAccountId,ParameterValue="${AWS_ACCOUNT_ID}" \
                   ParameterKey=VPCCidrBlock,ParameterValue="${VPC_CIDR_BLOCK}" \
                   ParameterKey=RegionSubnet,ParameterValue="${REGION_SUBNET}" \
                   ParameterKey=NumAvailabilityZones,ParameterValue="${NUM_AVAILABILITY_ZONES}" \
      --region "${REGION}" 1>/dev/null


    SECOND_OCTET=$((SECOND_OCTET+1))
  else
    echo "Cloudformatoin stack in ${REGION} already exists"
  fi


done

