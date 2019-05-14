DEFAULT_REGION=$(aws configure get region)
S3_BUCKET_NAME="samplebucket-richardimaoka-sample-sample"

for OPT in "$@"
do
    case "$OPT" in
      '--s3-bucket' )
        if [ -z "$2" ]; then
            echo "option --s3-bucket requires an argument -- $1" 1>&2
            exit 1
        fi
        S3_BUCKET_NAME="$2"
        ;;
    esac
done

PING_ORIGIN_EC2=$(aws ec2 describe-instances  \
 --filters "Name=tag:aws:cloudformation:stack-name,Values=PingExperiment" \
           "Name=tag:aws:cloudformation:logical-id,Values=EC2InstancePingOrigin" \
           "Name=instance-state-name,Values=running" \
 --query "Reservations[].Instances[].InstanceId" \
 --output text)

echo "Running a remote command to send ping from ${PING_ORIGIN_EC2}"

aws ssm send-command \
  --instance-ids "${PING_ORIGIN_EC2}" \
  --document-name "AWS-RunShellScript" \
  --comment "aws-ping command to run ping to all relevant EC2 instances in all the regions" \
  --parameters commands=["/home/ec2-user/aws-ping/ping-all.sh --region ${DEFAULT_REGION}"] \
  --output text \
  --query "Command.CommandIad"
