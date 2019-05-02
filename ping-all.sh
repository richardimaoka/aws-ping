#!/bin/sh

STACK_NAME="PingExperiment"
LOCAL_IPV4=$(curl http://169.254.169.254/latest/meta-data/local-ipv4 2> /dev/null)


for region in $(aws ec2 describe-regions --query "Regions[].RegionName" | jq -r '.[]')
do
  echo "------------------------------------------------------------"
  echo "Ping experiment for ${region}"
  echo "------------------------------------------------------------"

  EC2_INSTANCES=$(aws ec2 describe-instances \
    --filters "Name=tag:aws:cloudformation:stack-name,Values=${STACK_NAME}" \
    --query "Reservations[].Instances[]" \
    --region ${region}
  )

  for instance in $(echo ${EC2_INSTANCES} | jq -c '.[]')
  do
    AVAILABILITY_ZONE=$(echo "${instance}" | jq -r '.Placement.AvailabilityZone')
    TARGETIP__ADDRESS=$(echo "${instance}" | jq -r '.PrivateIpAddress')

    if [ -n "${AVAILABILITY_ZONE}" ] && [ -n "${TARGET_IP_ADDRESS}" ]; then
      echo "Pinging an instance in ${AVAILABILITY_ZONE} from ${LOCAL_IPV4}"
      ping -c 30 "${TARGET_IP_ADDRESS}"
    fi
  done
done
