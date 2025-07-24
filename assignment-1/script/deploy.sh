#!/bin/bash

STAGE=$1

if [[ -z "$STAGE" ]]; then
  echo "Usage: ./deploy.sh <dev|prod>"
  exit 1
fi

CONFIG_FILE="${STAGE}_config"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Config file $CONFIG_FILE not found!"
  exit 1
fi

# Load configuration
source $CONFIG_FILE

echo "Launching EC2 instance in $STAGE environment..."

INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --security-group-ids $SG_ID \
  --subnet-id $SUBNET_ID \
  --associate-public-ip-address \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Launched instance ID: $INSTANCE_ID"

# Wait until the instance is running
echo "Waiting for instance to start..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

# Get public IP address
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo "Instance is running. Public IP: $PUBLIC_IP"

echo "Copying install_app.sh to instance..."
scp -i "$KEY_PATH" -o StrictHostKeyChecking=no install_app.sh ec2-user@$PUBLIC_IP:/home/ec2-user/

echo "Running install script on instance..."
ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no ec2-user@$PUBLIC_IP 'chmod +x install_app.sh && ./install_app.sh'

echo "Waiting 30 seconds for app to start..."
sleep 30

echo "Testing application..."
curl http://$PUBLIC_IP:8080/hello

echo "Deployment complete. App should be reachable at http://$PUBLIC_IP:8080/hello"

echo "Sleeping for 30 mins to save cost..."
sleep 1800

echo "Stopping the EC2 instance..."
aws ec2 stop-instances --instance-ids $INSTANCE_ID

echo "Done!"
