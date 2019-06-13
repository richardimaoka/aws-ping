
AZ_LIST=$(aws ec2 describe-availability-zones --query "AvailabilityZones[?State=='available'].ZoneName" --output text --region "${AZ}")
AZ_LIST_INNER_LOOP=$(echo "${AZ_LIST}") # to avoid the same pair appear twice
TEMPFILE=$(mktemp)
for AZ1 in $AZS
do
  AZ_LIST_INNER_LOOP=$(echo "${AZ_LIST_INNER_LOOP}" | grep -v "${AZ1}")
  for AZ2 in $AZ_LIST_INNER_LOOP
  do
    echo "${AZ11} ${AZ12}" >> "${TEMPFILE}"
  done
done

#####################################################
# 3. main loop
######################################################
# Pick up one availability zone pair at a time
# AZ_PAIRS will remove the picked-up element at the end of an iteration
AZ_PAIRS=$(cat "${TEMPFILE}")
while PICKED_UP=$(echo "${AZ_PAIRS}" | shuf -n 1) && [ -n "${PICKED_UP}" ]
do
  SOURCE_AZ=$(echo "${PICKED_UP}" | awk '{print $1}')
  TARGET_AZ=$(echo "${PICKED_UP}" | awk '{print $2}')

  echo "PAIR: ${SOURCE_AZ} ${TARGET_AZ}"

  SOURCE_INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:experiment-name,Values=${STACK_NAME}" \
    --query "Reservations[*].Instances[*].InstanceId" \
    --output text \
    --region "${REGION}"
  )
  TARGET_INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:experiment-name,Values=${STACK_NAME}" \
    --query "Reservations[*].Instances[*].InstanceId" \
    --output text \
    --region "${REGION}"
  )

  if [ -z "${SOURCE_INSTANCE_ID}" ] && [ -z "${TARGET_INSTANCE_ID}" ] ; then
    echo "Running the EC2 instances in the source region=${SOURCE_AZ} and the target region=${TARGET_AZ}" 
    # Run this in background, so that the next iteration can be started without waiting
    (echo "${EC2_INPUT_JSON}" | \
      ./run-ec2-instance.sh \
        --stack-name "${STACK_NAME}" \
        --source-region "${SOURCE_AZ}" \
        --target-region "${TARGET_AZ}" \
        --test-uuid "${TEST_EXECUTION_UUID}" \
        --s3-bucket "${S3_BUCKET_NAME}"
    ) &

    ######################################################
    # For the next iteration
    ######################################################
    AZ_PAIRS=$(echo "${AZ_PAIRS}" | grep -v "${PICKED_UP}")
    sleep 5s # To let EC2 be captured the by describe-instances commands
  fi
done
