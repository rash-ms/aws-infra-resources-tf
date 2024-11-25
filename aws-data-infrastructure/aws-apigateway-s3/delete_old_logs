#!/bin/bash

# Get ACTIVE_STAGE and LOG_GROUP_PREFIX from arguments
ACTIVE_STAGE=$1
LOG_GROUP_PREFIX=$2

if [[ -z "$ACTIVE_STAGE" || -z "$LOG_GROUP_PREFIX" ]]; then
  echo "Error: ACTIVE_STAGE and LOG_GROUP_PREFIX arguments are required"
  exit 1
fi

# List all API Gateway execution log groups
echo "Fetching all log groups for prefix: $LOG_GROUP_PREFIX..."
LOG_GROUPS=$(aws logs describe-log-groups \
  --log-group-name-prefix "$LOG_GROUP_PREFIX" \
  --query "logGroups[*].logGroupName" --output text)

# Loop through log groups and delete unused ones
for LOG_GROUP in $LOG_GROUPS; do
  if [[ $LOG_GROUP != *$ACTIVE_STAGE ]]; then
    echo "Deleting old log group: $LOG_GROUP"
    aws logs delete-log-group --log-group-name "$LOG_GROUP"
  else
    echo "Skipping active log group: $LOG_GROUP"
  fi
done

echo "Log group cleanup completed."
