#!/bin/sh

STACK_NAME="PingExperiment"

for region in $(aws ec2 describe-regions --query "Regions[].RegionName" | jq -r '.[]')
do
  EC2_INSTANCES=$(aws ec2 describe-instances \
    --filters "Name=tag:aws:cloudformation:stack-name,Values=${STACK_NAME}" \
    --query "Reservations[].Instances[]" \
    --output json
    --region ${region}
  )

  for instance in $(echo ${EC2_INSTANCES} | jq -c '.')
  do
    AVAILABILITY_ZONE=$(echo "${instance}" | jq -r '.Placement.AvailabilityZone')
    LOCAL_IP_ADDRESS=$(echo "${instance}" | jq -r '.PrivateIpAddress')

    if [ -n "${AVAILABILITY_ZONE}" ] && [ -n "${LOCAL_IP_ADDRESS}" ]; then
      echo "Pinging an instance in ${AVAILABILITY_ZONE}"
      ping -c 30 "${LOCAL_IP_ADDRESS}"
    fi
  done
done