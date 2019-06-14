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
          echo "option --stack-name requires an argument -- $1" 1>&2
          exit 1
      fi
      STACK_NAME="$2"
      shift 2
      ;;
    '--region' )
      if [ -z "$2" ]; then
          echo "option --region requires an argument -- $1" 1>&2
          exit 1
      fi
      REGION="$2"
      shift 2
      ;;
    '--test-uuid' )
      if [ -z "$2" ]; then
          echo "option --test-uuid requires an argument -- $1" 1>&2
          exit 1
      fi
      TEST_EXECUTION_UUID="$2"
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

######################################
# 1.2 Validate options
######################################
if [ -z "${STACK_NAME}" ] ; then
  >&2 echo "ERROR: option --stack-name needs to be passed"
  ERROR="1"
fi
if [ -z "${REGION}" ] ; then
  >&2 echo "ERROR: option --region needs to be passed"
  ERROR="1"
fi
if [ -z "${TEST_EXECUTION_UUID}" ] ; then
  >&2 echo "ERROR: option --test-uuid needs to be passed"
  ERROR="1"
fi
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

######################################
# 2. main loop
######################################
AVAILABILITY_ZONES=$(aws ec2 describe-availability-zones --query "AvailabilityZones[?State=='available']")
AVAILABILITY_ZONES_INNER_LOOP="${AVAILABILITY_ZONES}"
for SOURCE_AVAILABILITY_ZONE in $AVAILABILITY_ZONES
do
  # to avoid the same pair appear twice
  AVAILABILITY_ZONES_INNER_LOOP=$(echo "${AVAILABILITY_ZONES_INNER_LOOP}" | grep -v "${SOURCE_AVAILABILITY_ZONE}")
  for TARGET_AVAILABILITY_ZONE in $AVAILABILITY_ZONES_INNER_LOOP
  do
    echo "${INPUT_JSON}" | \
      ./run-ec2-instance.sh \
        --stack-name "${STACK_NAME}" \
        --source-az "${SOURCE_AVAILABILITY_ZONE}" \
        --target-az "${TARGET_AVAILABILITY_ZONE}" \
        --test-uuid "${TEST_EXECUTION_UUID}" \
        --s3-bucket "${S3_BUCKET_NAME}"
  done
done
