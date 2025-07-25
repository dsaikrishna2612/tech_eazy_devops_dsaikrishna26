#!/bin/bash
# Replace BUCKET_NAME with your bucket variable if needed
BUCKET_NAME="your-bucket-name"

# Upload system logs after shutdown
aws s3 cp /var/log/cloud-init.log s3://$BUCKET_NAME/logs/cloud-init.log

# Upload app logs (if exists)
if [ -d "/app/logs/" ]; then
  aws s3 cp /app/logs/ s3://$BUCKET_NAME/app/logs/ --recursive
fi
