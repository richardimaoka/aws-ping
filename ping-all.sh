#!/bin/sh

STACK_NAME="PingExperiment"
LOCAL_IPV4=$(curl http://169.254.169.254/latest/meta-data/local-ipv4 2> /dev/null)
S3_BUCKET_NAME="samplebucket-richardimaoka-sample-sample"

for OPT in "$@"
do
  case "$OPT" in
    '--region' )
      if [ -z "$2" ]; then
          echo "option --region requires an argument -- $1" 1>&2
          exit 1
      fi
      CURRENT_REGION="$2"
      shift 2
      ;;
    '--s3-bucket' )
      if [ -z "$2" ]; then
          echo "option --s3-bucket requires an argument -- $1" 1>&2
          exit 1
      fi
      S3_BUCKET_NAME="$2"
      ;;
    -*)
      echo "illegal option -- $1" 1>&2
      exit 1
      ;;
  esac
done

if [ -n "${CURRENT_REGION}" ]; then

  UUID=$(uuidgen)
  FILE_NAME="${UUID}.log"

  echo "The results are saved in s3."
  echo "s3://${S3_BUCKET_NAME}/${FILE_NAME}" | tee /tmp/"${FILE_NAME}"
  echo "https://s3.console.aws.amazon.com/s3/object/${S3_BUCKET_NAME}/${FILE_NAME}" | tee -a /tmp/"${FILE_NAME}"

  for region in $(aws ec2 describe-regions --query "Regions[].RegionName" --region "${CURRENT_REGION}" | jq -r '.[]')
  do
    echo "------------------------------------------------------------" >> /tmp/"${FILE_NAME}"
    echo "Ping experiment for ${region}" >> /tmp/"${FILE_NAME}"
    echo "------------------------------------------------------------" >> /tmp/"${FILE_NAME}"

    EC2_INSTANCES=$(aws ec2 describe-instances \
      --filters "Name=tag:aws:cloudformation:stack-name,Values=${STACK_NAME}" \
      --query "Reservations[].Instances[]" \
      --region "${region}"
    )

    for instance in $(echo "${EC2_INSTANCES}" | jq -c '.[]')
    do
      AVAILABILITY_ZONE=$(echo "${instance}" | jq -r '.Placement.AvailabilityZone')
      TARGET_IP_ADDRESS=$(echo "${instance}" | jq -r '.PrivateIpAddress')
      TAG=$(echo "${instance}" \
        | jq -c '.Tags[] | select(.Key == "aws:cloudformation:logical-id")'
      )
      if [ -n "${AVAILABILITY_ZONE}" ] && [ -n "${TARGET_IP_ADDRESS}" ]; then
        echo "${TAG}" >> /tmp/"${FILE_NAME}"
        echo "" >> /tmp/"${FILE_NAME}"
        echo "traceroute ${TARGET_IP_ADDRESS}" >> /tmp/"${FILE_NAME}"
        traceroute "${TARGET_IP_ADDRESS}" >> /tmp/"${FILE_NAME}"
        echo "" >> /tmp/"${FILE_NAME}"
        echo "Pinging an instance in ${AVAILABILITY_ZONE} from ${LOCAL_IPV4}" >> /tmp/"${FILE_NAME}"
        ping -c 30 "${TARGET_IP_ADDRESS}" >> /tmp/"${FILE_NAME}"
        echo "------------------------------------------------------------" >> /tmp/"${FILE_NAME}"
      fi
    done
  done

  aws s3 cp \
    /tmp/"${FILE_NAME}" \
    "s3://${S3_BUCKET_NAME}/${FILE_NAME}"

else
  echo "--region option must be passed but was empty" | tee -a /tmp/"${FILE_NAME}"
fi