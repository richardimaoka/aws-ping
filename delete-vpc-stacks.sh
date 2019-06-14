#!/bin/sh

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
if [ -z "${STACK_NAME}" ] ; then
  echo "ERROR: Option --stack-name needs to be specified"
  exit 1
fi

REGIONS=$(aws ec2 describe-regions --query "Regions[].RegionName" --output text)

for REGION in ${REGIONS}
do
  echo "Deleting the CloudFormation stack=${STACK_NAME} for region=${REGION} if exists."
  aws cloudformation delete-stack --stack-name "${STACK_NAME}" --region "${REGION}"
done 
