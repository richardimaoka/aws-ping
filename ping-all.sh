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

  echo "The results are saved in s3:..."

  for region in $(aws ec2 describe-regions --query "Regions[].RegionName" --region "${CURRENT_REGION}" | jq -r '.[]')
  do
    echo "------------------------------------------------------------"
    echo "Ping experiment for ${region}"
    echo "------------------------------------------------------------"

    EC2_INSTANCES=$(aws ec2 describe-instances \
      --filters "Name=tag:aws:cloudformation:stack-name,Values=${STACK_NAME}" \
      --query "Reservations[].Instances[]" \
      --region "${region}"
    )

    for instance in $(echo "${EC2_INSTANCES}" | jq -c '.[]')
    do
      AVAILABILITY_ZONE=$(echo "${instance}" | jq -r '.Placement.AvailabilityZone')
      TARGET_IP_ADDRESS=$(echo "${instance}" | jq -r '.PrivateIpAddress')
      TAG=

      if [ -n "${AVAILABILITY_ZONE}" ] && [ -n "${TARGET_IP_ADDRESS}" ]; then
        echo "traceroute ${LOCAL_IPV4}"
        traceroute "${LOCAL_IPV4}"
        echo "Pinging an instance in ${AVAILABILITY_ZONE} from ${LOCAL_IPV4}"
        ping -c 30 "${TARGET_IP_ADDRESS}"
        echo "------------------------------------------------------------"
      fi
    done
  done

  echo "traceroute ${LOCAL_IPV4}"
    
  aws s3 cp \
    "aggregated/${TEST_EXECUTION_UUID}.log" \
    "s3://${BUCKET_NAME}/aggregated/"
  
else
  echo "--region option must be passed but was empty"
fi

