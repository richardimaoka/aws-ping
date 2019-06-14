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
    '--source-az' )
      if [ -z "$2" ]; then
          echo "option --source-az requires an argument -- $1" 1>&2
          exit 1
      fi
      SOURCE_AZ="$2"
      shift 2
      ;;
    '--target-az' )
      if [ -z "$2" ]; then
          echo "option --target-az requires an argument -- $1" 1>&2
          exit 1
      fi
      TARGET_AZ="$2"
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
if [ -z "${SOURCE_AZ}" ] ; then
  >&2 echo "ERROR: option --source-az needs to be passed"
  ERROR="1"
fi
if [ -z "${TARGET_AZ}" ] ; then
  >&2 echo "ERROR: option --target-az needs to be passed"
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
# 2.1. Create the source EC2 instance
######################################
SOURCE_INSTANCE_TYPE=$(echo "${INPUT_JSON}" | jq -r ".\"$SOURCE_AZ\".instance_type")
SOURCE_IMAGE_ID=$(echo "${INPUT_JSON}" | jq -r ".\"$SOURCE_AZ\".image_id")
SOURCE_SECURITY_GROUP_ID=$(echo "${INPUT_JSON}" | jq -r ".\"$SOURCE_AZ\".security_group")
SOURCE_SUBNET_ID=$(echo "${INPUT_JSON}" | jq -r ".\"$SOURCE_AZ\".subnet_id")
SOURCE_INSTANCE_PROFILE=$(echo "${INPUT_JSON}" | jq -r ".\"$SOURCE_AZ\".instance_profile")
SOURCE_REGION=$(echo "${INPUT_JSON}" | jq -r ".\"$SOURCE_AZ\".region")

if ! SOURCE_OUTPUTS=$(aws ec2 run-instances \
  --image-id "${SOURCE_IMAGE_ID}" \
  --instance-type "${SOURCE_INSTANCE_TYPE}" \
  --key-name "demo-key-pair" \
  --iam-instance-profile Name="${SOURCE_INSTANCE_PROFILE}" \
  --network-interfaces \
    "AssociatePublicIpAddress=true,DeviceIndex=0,Groups=${SOURCE_SECURITY_GROUP_ID},SubnetId=${SOURCE_SUBNET_ID}" \
  --tag-specifications \
    "ResourceType=instance,Tags=[{Key=experiment-name,Value=${STACK_NAME}}]" \
  --user-data file://user-data.txt \
  --region "${SOURCE_REGION}"
) ; then
  exit 1
fi

######################################
# 2.2. Create the target EC2 instance
######################################
TARGET_INSTANCE_TYPE=$(echo "${INPUT_JSON}" | jq -r ".\"$TARGET_AZ\".instance_type")
TARGET_IMAGE_ID=$(echo "${INPUT_JSON}" | jq -r ".\"$TARGET_AZ\".image_id")
TARGET_SECURITY_GROUP_ID=$(echo "${INPUT_JSON}" | jq -r ".\"$TARGET_AZ\".security_group")
TARGET_SUBNET_ID=$(echo "${INPUT_JSON}" | jq -r ".\"$TARGET_AZ\".subnet_id")
TARGET_INSTANCE_PROFILE=$(echo "${INPUT_JSON}" | jq -r ".\"$TARGET_AZ\".instance_profile")
TARGET_REGION=$(echo "${INPUT_JSON}" | jq -r ".\"$TARGET_AZ\".region")

if ! TARGET_OUTPUTS=$(aws ec2 run-instances \
  --image-id "${TARGET_IMAGE_ID}" \
  --instance-type "${TARGET_INSTANCE_TYPE}" \
  --key-name "demo-key-pair" \
  --iam-instance-profile Name="${TARGET_INSTANCE_PROFILE}" \
  --network-interfaces \
    "AssociatePublicIpAddress=true,DeviceIndex=0,Groups=${TARGET_SECURITY_GROUP_ID},SubnetId=${TARGET_SUBNET_ID}" \
  --tag-specifications \
    "ResourceType=instance,Tags=[{Key=experiment-name,Value=${STACK_NAME}}]" \
  --user-data file://user-data.txt \
  --region "${TARGET_REGION}"
) ; then
  exit 1
fi

SOURCE_INSTANCE_ID=$(echo "${SOURCE_OUTPUTS}" | jq -r ".Instances[].InstanceId")
TARGET_INSTANCE_ID=$(echo "${TARGET_OUTPUTS}" | jq -r ".Instances[].InstanceId")
TARGET_PRIVATE_IP=$(echo "${TARGET_OUTPUTS}" | jq -r ".Instances[].NetworkInterfaces[].PrivateIpAddress")

##############################################
# 2.3. Wait for the EC2 instances to be ready
##############################################
echo "Waiting for the EC2 instances to be status = ok: source = ${SOURCE_INSTANCE_ID}(${SOURCE_AZ}) and target = ${TARGET_INSTANCE_ID}(${TARGET_AZ})"
if ! aws ec2 wait instance-status-ok --instance-ids "${SOURCE_INSTANCE_ID}" --region "${SOURCE_REGION}" ; then
  >&2 echo "ERROR: failed to wait on the source EC2 instance = ${SOURCE_INSTANCE_ID}"
  exit 1
elif ! aws ec2 wait instance-status-ok --instance-ids "${TARGET_INSTANCE_ID}" --region "${TARGET_REGION}" ; then
  >&2 echo "ERROR: failed to wait on the source EC2 instance = ${TARGET_INSTANCE_ID}"
  exit 1
fi

######################################################
# 3 Send the command and sleep to wait
######################################################
echo "Sending command to the source EC2=${SOURCE_INSTANCE_ID}(${SOURCE_AZ})"
COMMANDS="/home/ec2-user/aws-ping/ping-target.sh"
COMMANDS="${COMMANDS} --target-az ${TARGET_AZ}"
COMMANDS="${COMMANDS} --target-ip ${TARGET_PRIVATE_IP}"
COMMANDS="${COMMANDS} --test-uuid ${TEST_EXECUTION_UUID}"
COMMANDS="${COMMANDS} --s3-bucket ${S3_BUCKET_NAME}"
if ! aws ssm send-command \
  --instance-ids "${SOURCE_INSTANCE_ID}" \
  --document-name "AWS-RunShellScript" \
  --comment "aws-ping command to run ping and save results to S3" \
  --parameters commands=["${COMMANDS}"] \
  --region "${SOURCE_REGION}" > /dev/null ; then
  >&2 echo "ERROR: failed to send command to = ${SOURCE_INSTANCE_ID}"
fi

# No easy way to signal the end of the command, so sleep to wait enough 
sleep 90s

######################################################
# 4.3 Terminate the EC2 instances
######################################################
echo "Terminate the EC2 instances source=${SOURCE_INSTANCE_ID}(${SOURCE_AZ}) target=${TARGET_INSTANCE_ID}(${TARGET_AZ})"
if ! aws ec2 terminate-instances --instance-ids "${SOURCE_INSTANCE_ID}" --region "${SOURCE_REGION}" > /dev/null ; then
  >&2 echo "ERROR: failed terminate the source EC2 instance = ${SOURCE_INSTANCE_ID}"
  exit 1
fi
if ! aws ec2 terminate-instances --instance-ids "${TARGET_INSTANCE_ID}" --region "${TARGET_REGION}" > /dev/null ; then
  >&2 echo "ERROR: failed terminate the target EC2 instance = ${TARGET_INSTANCE_ID}"
  exit 1
fi
