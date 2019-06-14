#!/bin/sh

# cd to the current directory as it runs other shell scripts
cd "$(dirname "$0")" || exit

AVAILABILITY_ZONES=$(aws ec2 describe-availability-zones --query "AvailabilityZones[?State=='available']")
AVAILABILITY_ZONES_INNER_LOOP=$(echo "${AVAILABILITY_ZONES}")
for SORUCE_AVAILABILITY_ZONE in $AVAILABILITY_ZONES
do
  # to avoid the same pair appear twice
  AVAILABILITY_ZONES_INNER_LOOP=$(echo "${AVAILABILITY_ZONES_INNER_LOOP}" | grep -v "${AVAILABILITY_ZONE}")
  for TARGET_AVAILABILITY_ZONE in $AVAILABILITY_ZONES_INNER_LOOP
    echo "${EC2_INPUT_JSON}" | \
      ./run-ec2-instance.sh \
        --stack-name "${STACK_NAME}" \
        --source-region "${SORUCE_AVAILABILITY_ZONE}" \
        --target-region "${TARGET_AVAILABILITY_ZONE}" \
        --test-uuid "${TEST_EXECUTION_UUID}" \
        --s3-bucket "${S3_BUCKET_NAME}"
  do
done