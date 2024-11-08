import json
import boto3
import time
import os
import urllib3
from datetime import datetime
from helper_function import *


# POST REQUEST
def lambda_handler(event, context):
    print("Received event:", json.dumps(event))  # Debugging: log the entire event

    bucket_name = 'byt-test-prod'

    try:
        schema = load_schema()

        body = event.get('body')
        if not body:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Request body is missing'})
            }

        data = json.loads(body)

        processed_data = process_data(data, schema)
        validate(instance=processed_data, schema=schema)

        event_type = data.get("event_type")
        if event_type not in ["subscription_created", "subscription_updated"]:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Unknown event type'})
            }

        timestamp = datetime.now().strftime('%Y%m%d%H%M%S')
        object_key = f"bronze/{event_type}/{event_type}_{timestamp}.json"

        s3.put_object(
            Bucket=bucket_name,
            Key=object_key,
            Body=json.dumps(data),
            ContentType='application/json'
        )
  
        # success_message = f"Data successfully written to S3 with object key: {object_key}"
        # send_to_slack(success_message)

        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Data successfully written to S3', 'object_key': object_key})
        }

    except ValidationError as e:
        error_message = f'Schema validation failed in {event_type}: {str(e)}'
        send_to_slack(f"Error in Lambda function: {error_message}")
        return {
            'statusCode': 400,
            'body': json.dumps({'error': error_message})
        }
    except json.JSONDecodeError:
        error_message = f'Invalid JSON format in {event_type} Shopify flow app' 
        send_to_slack(f"Error in Lambda function: {error_message}")
        return {
            'statusCode': 400,
            'body': json.dumps({'error': error_message})
        }
    except Exception as e:
        error_message = f"Unexpected error in {event_type}: {str(e)}"
        send_to_slack(f"Error in Lambda function: {error_message}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': error_message})
        }
