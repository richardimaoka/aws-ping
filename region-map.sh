#!/bin/sh

echo "Copy and paste the below output to the 'Mappings' section of the cloudformation.yaml file.\n"
echo "Mappings:"
echo "  RegionMap:"

# Second octet of the IP address
SECOND_OCTET="101"

# https://stackoverflow.com/questions/38148397/is-there-a-way-to-pipe-the-output-of-one-aws-cli-command-as-the-input-to-another
#   > it's important to wrap the "InstanceId" portion of the --query parameter value in brackets [InstanceId]
# In the below case, RegionName is wrapped into [RegionName]
for REGION in $(aws ec2 describe-regions --query "Regions[].[RegionName]" --output text)
do 
    NUM_AVAILABILITY_ZONES=$(aws ec2 describe-availability-zones \
      --region "${REGION}" \
      --query "AvailabilityZones[] | length(@)"
    )

    # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/finding-an-ami.html
    AMI_LINUX2=$(aws ec2 describe-images \
      --region "${REGION}" \
      --owners amazon \
      --filters 'Name=name,Values=amzn2-ami-hvm-2.0.????????-x86_64-gp2' 'Name=state,Values=available' \
      --query "reverse(sort_by(Images, &CreationDate))[0].ImageId" \
      --output text
    )

    echo "    ${REGION}:"
    echo "      NumberOfAvailabilityZones: ${NUM_AVAILABILITY_ZONES}"
    echo "      RegionSubnet: 10.${SECOND_OCTET}"
    echo "      AmazonLinux2AMI: ${AMI_LINUX2}"
    SECOND_OCTET=$((SECOND_OCTET+1))
done 
