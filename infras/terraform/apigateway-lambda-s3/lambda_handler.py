import json
import boto3
import os
from datetime import datetime
import fastjsonschema
from helper_function import *

# Initialize the S3 client
s3 = boto3.client('s3')

# POST REQUEST
def lambda_handler(event, context):
    print("Received event:", json.dumps(event))  # Debugging: log the entire event

    bucket_name = 'byt-test-prod'

    try:
        # Load the schema
        schema = load_schema()

        body = event.get('body')
        if not body:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Request body is missing'})
            }

        # Parse the JSON payload
        data = json.loads(body)
        event_type = data.get("event_type")

        processed_data = process_data(data, schema)

        # validate = fastjsonschema.compile(schema)
        # validate(processed_data)  

        if event_type not in ["subscription_created", "subscription_updated"]:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Unknown event type'})
            }

        # Generate a timestamped object key
        timestamp = datetime.now().strftime('%Y%m%d%H%M%S')
        object_key = f"bronze/{event_type}/{event_type}_{timestamp}.json"

        # Write the processed data to S3
        s3.put_object(
            Bucket=bucket_name,
            Key=object_key,
            Body=json.dumps(processed_data),
            ContentType='application/json'
        )

        # Return success response
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Data successfully written to S3', 
                                'object_key': object_key, 
                                'event_type': event_type,
                                'processed_data': processed_data
                                })
        }

    except fastjsonschema.JsonSchemaException as e:
        error_message = f"Schema validation failed in {event_type}: {str(e)}"
        send_to_slack(f"Error in Lambda function: {error_message}")
        return {
            'statusCode': 400,
            'body': json.dumps({'error': error_message})
        }
    
    except json.JSONDecodeError:
        error_message = f"Invalid JSON format in {event_type} Shopify flow app"
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

