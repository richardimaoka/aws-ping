
echo "Running a remote command to start the iperf server on ${IPERF_SERVER_INSTANCE_ID}"

PING_ORIGIN_EC2=$(aws ec2 aws ec2 describe-instances  \
 --filters "Name=tag:aws:cloudformation:stack-name,Values=PingExperiment" \
 --query "Reservations[].Instances[].InstanceId" \
 --text
)

aws ssm send-command \
  --instance-ids "${PING_ORIGIN_EC2}" \
  --document-name "AWS-RunShellScript" \
  --comment "aws-ping command to run ping to all relevant EC2 instances in all the regions" \
  --parameters commands=["/home/ec2-user/aws-ping/ping-all.sh"] \
  --output text \
  --query "Command.CommandId"