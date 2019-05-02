#!/bin/sh

STACK_NAME="PingExperiment"

for region in $(aws ec2 describe-regions --query "Regions[].RegionName" | jq -r '.[]')
do 
  echo "Deleting the CloudFormation stack=${STACK_NAME} for region=${region} if exists."
  aws cloudformation delete-stack --stack-name "${STACK_NAME}" --region "${region}"
done 
