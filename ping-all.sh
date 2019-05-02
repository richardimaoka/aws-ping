#!/bin/sh

STACK_NAME="PingExperiment"

for region in $(aws ec2 describe-regions --query "Regions[].RegionName" | jq)
do
  EC2_INSTANCES=$(aws ec2 describe-instances \
    --filters "Name=tag:aws:cloudformation:stack-name,Values=${STACK_NAME}" \
    --region ${region}
  )
  for instance in $(echo ${EC2_INSTANCES} | jq -c '.')
  do
    echo "$instance"
  done
done
