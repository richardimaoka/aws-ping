## How to run this sample

### pre-requisites

- AWS CLI installed on your local machine


## steps to run the example

- run `./create-key-pairs.sh`
  - this needs to be run only once in your AWS account
  - this adds `demo-key-pair` AWS key pair to all your AWS regions
- run `./create-stacks.sh`
  - this creates a CloudFormation stack from `cloudformation.yaml` in each AWS region
- run `./send-command.sh`
  - this fires `ping-all.sh` on `EC2InstancePingOrigin` to all other EC2 instances
  - go to https://console.aws.amazon.com/ec2/v2/home#Commands:sort=CommandId and find the command you executed in this step
  - the AWS web console from the above link should show the output of the command, which tells you the ping results

# save this to  ~/.ssh/demo-key-pair.pub

aws ec2 describe-regions | jq ".Regions[].RegionName" | xargs -i aws ec2 import-key-pair --key-name "demo-key-pair" --public-key-material file://~/.ssh/demo-key-pair.pub --region {}

https://stackoverflow.com/questions/45198768/how-to-find-aws-keypair-public-key
https://docs.aws.amazon.com/cli/latest/reference/ec2/import-key-pair.html

ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCDcdYpwye9H2B5LocXbpXcAAwkWDzX/sS4FW9ZCSdxo3BHqKkZX6dMxYdqM4HxnNn9Itu7FqWWKgdzuzGi/Fuu0m8XmE0Lc9V91YhkvKpGYettGzwUD5G9nFUlDFyqJV/Mc0/DrZOY2r4CY78acuVZo/9xw6T/rSJuMT96ZHfxrbxlLTK5evS4daSvUgDQwCxktXYg1fnKKVqAUvvWqwvx30cgv2cueJZINZ6aA5RKSpHMZnvnTqVWciJi/cEhgZg7uWytC2n4xIOPoumsX5nCVbH3+Ifk5V12y4xLFPLZ2TASdzYrpUuDHbufg16+lLoqxEHPvKdYlrtzDCVSGV0Z

## number of AZs in regions

https://docs.aws.amazon.com/cli/latest/reference/ec2/describe-regions.html
aws ec2 describe-regions --query "Regions[].{Name:RegionName}" --output text

https://stackoverflow.com/questions/38148397/is-there-a-way-to-pipe-the-output-of-one-aws-cli-command-as-the-input-to-another
>  it's important to wrap the "InstanceId" portion of the --query parameter value in brackets [InstanceId]
// in the below case, RegionName is wrapped into [RegionName]
aws ec2 describe-regions --query "Regions[].[RegionName]" --output text \
  | xargs -i \
    aws ec2 describe-availability-zones \
      --region {} \
      --query "AvailabilityZones[].[RegionName]" \
      --output text \
  | uniq -c

## AMI

aws ec2 describe-images \
  --query "Images[?contains(to_string(Name),\`amzn2-ami-hvm-2.0\`)] | "

https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/finding-an-ami.html
aws ec2 describe-regions --query "Regions[].[RegionName]" --output text\
  | xargs -i \
    aws ec2 describe-images \
      --region {} \
      --owners amazon \
      --filters 'Name=name,Values=amzn2-ami-hvm-2.0.????????-x86_64-gp2' 'Name=state,Values=available' \
      --query "reverse(sort_by(Images, &CreationDate))[0]"




## 
https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/finding-an-ami.html
https://qiita.com/j-un/items/b891d7b0940e70a961e7
> ちょっとしたことをするためのawscliワンライナー集
aws ec2 describe-regions | jq ".Regions[].RegionName" | xargs -i aws ec2 describe-images --owners amazon --filters 'Name=name,Values=amzn2-ami-hvm-2.0.????????-x86_64-gp2' 'Name=state
,Values=available' --region {} --output json | jq -r '.Images | sort_by(.CreationDate) | last(.[]).ImageId'

## VPC Peering

https://aws.amazon.com/about-aws/whats-new/2017/11/announcing-support-for-inter-region-vpc-peering/
> Inter-Region VPC Peering provides a simple and cost-effective way to share resources between regions or replicate data for geographic redundancy. Built on the same horizontally scaled, redundant, and highly available technology that powers VPC today, Inter-Region VPC Peering encrypts inter-region traffic with no single point of failure or bandwidth bottleneck. Traffic using Inter-Region VPC Peering always stays on the global AWS backbone and never traverses the public internet, thereby reducing threat vectors, such as common exploits and DDoS attacks.

https://docs.aws.amazon.com/vpc/latest/peering/vpc-peering-routing.html
https://docs.aws.amazon.com/vpc/latest/peering/vpc-peering-security-groups.html

You need to add:
  Security group for the peering CIDR block
  Routing in Route Table for VPC peering
  in both directions

https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Route_Tables.html
> We use the most specific route that matches the traffic to determine how to route the traffic.
So, the route table like below is OK, because the traffict to the local VPC hits the most specific rule at the top.

Destination   Target                Status Propagated
10.107.0.0/16	local	                active No	 
0.0.0.0/0     igw-0b4cd0225df0db8d0	active No	
10.0.0.0/8    pcx-0a70630b326d29d6c	active No

https://docs.aws.amazon.com/cli/latest/reference/ec2/describe-instances.html
aws ec2 describe-instances --filters "Name=tag:aws:cloudformation:stack-name,Values=PingMainVPC" \
  | jq  ".Reservations[].Instances[].InstanceId" \
  | xargs -i 

aws ec2 describe-instances --filters "Name=tag:aws:cloudformation:stack-name,Values=PingMainVPC" \
  | jq  ".Reservations[].Instances[].PrivateIpAddress"

- Placement.AvailabilityZone
- PrivateIpAddress

https://docs.aws.amazon.com/cli/latest/reference/ec2/create-route.html
aws ec2 create-route \
  --route-table-id ${MAIN_VPC_ROUTE_TABLE} \
  --destination-cidr-block 0.0.0.0/0 \
  --vpc-peering-connection-id ${...}

aws ec2 describe-regions --query "Regions[].RegionName" | jq -r '.[]' | xargs -i aws ec2 describe-availability-zones --query "AvailabilityZones[].ZoneName" --region {}


Error ....
> Waiter StackCreateComplete failed: Waiter encountered a terminal failure state
Which is because of a CloudFormation error as follows:
> Your request for accessing resources in this region is being validated, and you will not be able to launch additional resources in this region until the validation is complete. We will notify you by email once your request has been validated. While normally resolved within minutes, please allow up to 4 hours for this process to complete. If the issue still persists, please let us know by writing to aws-verification@amazon.com for further assistance. (Service: AmazonEC2; Status Code: 400; Error Code: PendingVerification; Request ID: 4da3fbd6-e09c-4ce2-b3b2-fa56bfc17d1f)


eu-north-1
ap-south-1
eu-west-3
eu-west-2
eu-west-1
ap-northeast-2
ap-northeast-1
sa-east-1
ca-central-1
ap-southeast-1
ap-southeast-2
eu-central-1
us-east-1
us-east-2
us-west-1
us-west-2

## update stack
STACK_NAME=PingCrossRegionExperiment
AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
SSH_LOCATION="$(curl ifconfig.co 2> /dev/null)/32"

for REGION in $(aws ec2 describe-regions --query "Regions[].RegionName" --output text)
do 
  echo "Updatiing a CloudFormation stack=${STACK_NAME} for region=${REGION}"

  # If it fails, an error message is displayed and it continues to the next REGION
  aws cloudformation update-stack \
    --stack-name "${STACK_NAME}" \
    --template-body file://cloudformation-vpc.yaml \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameters ParameterKey=SSHLocation,ParameterValue="${SSH_LOCATION}" \
                  ParameterKey=AWSAccountId,ParameterValue="${AWS_ACCOUNT_ID}" \
    --region "${REGION}" \
    --output text
done 


## Athena 

https://aws.amazon.com/blogs/big-data/create-tables-in-amazon-athena-from-nested-json-and-mappings-using-jsonserde/

https://docs.aws.amazon.com/en_us/athena/latest/ug/creating-tables.html#all-tables-are-external

```
CREATE EXTERNAL TABLE results (
  metadata struct<source_region:STRING,
                  target_region:STRING,
                  test_uuid:STRING
                 >,
  rtt_summary struct<packets_transmitted:INT,
                     packets_received:INT,
                     packets_loss_percentage:DOUBLE,
                     time:struct<unit:string,value:DOUBLE>
                    >,
  rtt_statistics struct<min:struct<unit:string,value:DOUBLE>,
                        avg:struct<unit:string,value:DOUBLE>,
                        max:struct<unit:string,value:DOUBLE>,
                        mdev:struct<unit:string,value:DOUBLE>
                       >
)                 
ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'
LOCATION 's3://samplebucket-richardimaoka-sample-sample/aws-iperf-cross-region'
```


```
SELECT 
  metadata.test_uuid,
  metadata.target_region,
  metadata.source_region,
  rtt_statistics.min.value as min_value,
  rtt_statistics.min.unit  as min_unit,
  rtt_statistics.max.value as max_value,
  rtt_statistics.max.unit  as max_unit,
  rtt_statistics.avg.value as avg_value,
  rtt_statistics.avg.unit  as avg_unit
FROM
  "aws_ping_cross_region"."results"
limit 10;
```

# Submodule 
- git submodule add https://github.com/richardimaoka/ping-to-json.git
- git clone --recurse-submodules https://github.com/richardimaoka/aws-iperf-cross-region
- git submodule update --init --recursive
  - https://github.blog/2016-02-01-working-with-submodules/