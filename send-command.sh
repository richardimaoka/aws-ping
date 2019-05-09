DEFAULT_REGION=$(aws configure get region)

PING_ORIGIN_EC2=$(aws ec2 describe-instances  \
 --filters "Name=tag:aws:cloudformation:stack-name,Values=PingExperiment" "Name=tag:aws:cloudformation:logical-id,Values=EC2InstancePingOrigin"\
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
