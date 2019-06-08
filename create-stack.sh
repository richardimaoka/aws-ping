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
    '--region' )
      if [ -z "$2" ]; then
          echo "option -f or --region requires an argument -- $1" 1>&2
          exit 1
      fi
      AZ="$2"
      shift 2
      ;;
  esac
done

######################################
# 1.2 Validate options
######################################
if [ -z "${STACK_NAME}" ] ; then
  >&2 echo "ERROR: Option --stack-name needs to be specified"
  ERROR="1"
fi
if [ -z "${AZ}" ] ; then
  >&2 echo "ERROR: Option --region needs to be specified"
  ERROR="1"
fi
if [ -n "${ERROR}" ] ; then
  exit 1
fi

######################################
# 2 Create a CloudFormation stack
######################################
AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
SSH_LOCATION="$(curl ifconfig.co 2> /dev/null)/32"

if ! STACK_INFO=$(aws cloudformation describe-stacks --stack-name "${STACK_NAME}" --region "${AZ}" 2> /dev/null) ; then
  echo "Creating a CloudFormation stack=${STACK_NAME} for region=${AZ}"
  # If it fails, an error message is displayed and it continues to the next AZ
  STACK_INFO=$(aws cloudformation create-stack \
    --stack-name "${STACK_NAME}" \
    --template-body file://cloudformation-vpc.yaml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameters ParameterKey=SSHLocation,ParameterValue="${SSH_LOCATION}" \
                  ParameterKey=AWSAccountId,ParameterValue="${AWS_ACCOUNT_ID}" \
    --region "${AZ}"
  )
elif [ "CREATE_COMPLETED" != "$(echo "${STACK_INFO}" | jq -r '.Stacks[].StackStatus')" ] ; then
  echo "Waiting until the CloudFormation stack is CREATE_COMPLETE for ${AZ}"
  if ! aws cloudformation wait stack-create-complete --stack-name "${STACK_NAME}" --region "${AZ}"; then
    >&2 echo "ERROR: CloudFormation wait failed for ${AZ}"
    exit 1
  fi
else
  echo "Cloudformatoin stack in ${AZ} already exists"
fi

###############################################
# 2 Create a Subnet for each Availability Zone
###############################################

SUBNETS=$(aws ec2 describe-subnets \
  --filters "Name=tag:experiment-name,Values=${STACK_NAME}" \
  --region "${REGION}"
)

# AZ: Availability Zone
for AZ in $(aws ec2 describe-availability-zones \
  --query "AvailabilityZones[?State=='available'].ZoneName" \
  --output text \
  --region "${REGION}")
do
  if [ -z "$(echo "${SUBNETS}" | jq -r ".Subnets[] | select(.AvailabilityZone==\"${AZ}\")")" ] ; then
    echo "Creating a subnet in ${AZ}"
    # VPC_CIDR_BLOCK=
    # SUBNET_CIDR_BLOCK=
    # SUBNET=$(aws ec2 create-subnet
    #   --cidr-block SUBNET_CIDR_BLOCK
    #   --vpc-id 
    # )
    # aws ec2 wait subnet-available
    # aws ec2 associate-route-table
    #   --cidr-block SUBNET_CIDR_BLOCK
    #   --vpc-id 

  else      
    echo "A subnet in ${AZ} already exists"
  fi
done
