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
      REGION="$2"
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
if [ -z "${REGION}" ] ; then
  >&2 echo "ERROR: Option --region needs to be specified"
  ERROR="1"
fi
if [ -n "${ERROR}" ] ; then
  exit 1
fi

######################################
# 2. Create a CloudFormation stack
######################################
AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
SSH_LOCATION="$(curl ifconfig.co 2> /dev/null)/32"

if ! STACK_INFO=$(aws cloudformation describe-stacks --stack-name "${STACK_NAME}" --region "${REGION}" 2> /dev/null) ; then
  echo "Creating a CloudFormation stack=${STACK_NAME} for region=${REGION}"
  # If it fails, an error message is displayed and it continues to the next REGION
  aws cloudformation create-stack \
    --stack-name "${STACK_NAME}" \
    --template-body file://cloudformation-vpc.yaml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameters ParameterKey=SSHLocation,ParameterValue="${SSH_LOCATION}" \
                  ParameterKey=AWSAccountId,ParameterValue="${AWS_ACCOUNT_ID}" \
    --region "${REGION}"
else
  echo "Cloudformatoin stack in ${REGION} already exists"
fi

