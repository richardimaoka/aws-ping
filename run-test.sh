#!/bin/sh

# cd to the current directory as it runs other shell scripts
cd "$(dirname "$0")" || exit

############################################################
# Kill the child (background) processes on Ctrl+C = (SIG)INT
############################################################
# This script runs run-ec2-instance.sh in the background
# https://superuser.com/questions/543915/whats-a-reliable-technique-for-killing-background-processes-on-script-terminati/562804
trap 'kill -- -$$' INT

#################################
# 0.1 Parse the options
#################################
TEST_EXECUTION_UUID=$(uuidgen)
S3_BUCKET_NAME="samplebucket-richardimaoka-sample-sample"
for OPT in "$@"
do
    case "$OPT" in
      '--stack-name' )
        if [ -z "$2" ]; then
            echo "option --stack-name requires an argument -- $1" 1>&2
            exit 1
        fi
        STACK_NAME="$2"
        shift 2
        ;;
      '--s3-bucket' )
        if [ -z "$2" ]; then
            echo "option --s3-bucket requires an argument -- $1" 1>&2
            exit 1
        fi
        S3_BUCKET_NAME="$2"
        shift 2
        ;;
      '-f' | '--file-name' )
        if [ -z "$2" ]; then
            echo "option -f or --file-name requires an argument -- $1" 1>&2
            exit 1
        fi
        FILE_NAME="$2"
        shift 2
        ;;
    esac
done

#################################
# 0.2 Error handling
#################################
if [ -z "${STACK_NAME}" ] ; then
  >&2 echo "ERROR: option --stack-name needs to be passed"
  ERROR="1"
if [ -z "${S3_BUCKET_NAME}" ] ; then
  >&2 echo "ERROR: option --s3-bucket needs to be passed"
  ERROR="1"
fi
# Input from stdin or --filename option
if [ -z "${FILE_NAME}" ] ; then
  if ! INPUT_JSON=$(cat | jq -r ".") ; then 
    >&2 echo "ERROR: Failed to read input JSON from stdin"
    ERROR="1"
  fi
else
  if ! INPUT_JSON=$(jq -r "." < "${FILE_NAME}"); then
    >&2 echo "ERROR: Failed to read input JSON from ${FILE_NAME}"
    ERROR="1"
  fi
fi
if [ -n "${ERROR}" ] ; then
  exit 1
fi

#####################################################
# 2. Prepare AVAILABILITY_ZONE_PAIRS for efficient
# loop in the next step
#####################################################
for REGION in $(aws ec2 describe-regions --query "Regions[].[RegionName]" --output text)
do
  echo "Running the test in the region = ${REGION}" 
  echo "${EC2_INPUT_JSON}" | \
    ./run-test-region.sh \
      --stack-name "${STACK_NAME}" \
      --region "${REGION}" \
      --test-uuid "${TEST_EXECUTION_UUID}" \
      --s3-bucket "${S3_BUCKET_NAME}"      
done
 
#####################################################
# 3. main loop
######################################################
# Pick up one availability zone pair at a time
# AVAILABILITY_ZONE_PAIRS will remove the picked-up element at the end of an iteration
while PICKED_UP=$(echo "${AVAILABILITY_ZONE_PAIRS}" | shuf -n 1) && [ -n "${PICKED_UP}" ]
do
  SOURCE_AVAILABILITY_ZONE=$(echo "${PICKED_UP}" | awk '{print $1}')
  TARGET_AVAILABILITY_ZONE=$(echo "${PICKED_UP}" | awk '{print $2}')

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
    # Run this in background, so that the next iteration can be started without waiting
    (echo "${EC2_INPUT_JSON}" | \
      ./run-ec2-instance.sh \
        --stack-name "${STACK_NAME}" \
        --source-region "${SOURCE_AVAILABILITY_ZONE}" \
        --target-region "${TARGET_AVAILABILITY_ZONE}" \
        --test-uuid "${TEST_EXECUTION_UUID}" \
        --s3-bucket "${S3_BUCKET_NAME}"
    ) &

    ######################################################
    # For the next iteration
    ######################################################
    AVAILABILITY_ZONE_PAIRS=$(echo "${AVAILABILITY_ZONE_PAIRS}" | grep -v "${PICKED_UP}")
    sleep 5s # To let EC2 be captured the by describe-instances commands

  # elif [ -n "${SOURCE_INSTANCE_ID}" ] && [ -z "${TARGET_INSTANCE_ID}" ] ; then
  #   echo "${SOURCE_REGION} has EC2 running. So try again in the next iteration"
  # elif [ -z "${SOURCE_INSTANCE_ID}" ] && [ -n "${TARGET_INSTANCE_ID}" ] ; then
  #   echo "${TARGET_REGION} has EC2 running. So try again in the next iteration"
  # elif [ -n "${SOURCE_INSTANCE_ID}" ] && [ -n "${TARGET_INSTANCE_ID}" ] ; then
  #   echo "Both ${SOURCE_REGION} and ${TARGET_INSTANCE_ID} has EC2 running. So try again in the next iteration"
  # else
  #   echo "WAZZUP!??"
  fi
done
done

