# import json
# import boto3
# import time
# import os
# import urllib3


# s3 = boto3.client('s3')
# http = urllib3.PoolManager()

# slack_token = os.environ['SLACK_TOKEN']
# slack_channel = os.environ['SLACK_CHANNEL']

# # list of user IDs
# slack_user_ids = ["U03V6VD8JHL"]     # Mujeeb     
                

# #  send slack message func
# def send_to_slack(message):
#     # format slack user_id
#     user_mentions = " ".join([f"<@{user_id}>" for user_id in slack_user_ids])
    
#     slack_message = {
#         "channel": slack_channel,
#         "text": f"{user_mentions} {message}"
#     }
#     response = http.request(
#         'POST',
#         'https://slack.com/api/chat.postMessage',
#         body=json.dumps(slack_message),
#         headers={
#             'Content-Type': 'application/json',
#             'Authorization': f'Bearer {slack_token}'
#         }
#     )
#     if response.status != 200:
#         print(f"Failed to send message to Slack: {response.status}, {response.data}")

# # POST REQUEST
# def lambda_handler(event, context):
#     print("Received event:", json.dumps(event))  # Debugging: log the entire event

#     bucket_name = 'byt-test-prod'

#     try:
#         body = event.get('body')
#         if not body:
#             return {
#                 'statusCode': 400,
#                 'body': json.dumps({'error': 'Request body is missing'})
#             }

#         data = json.loads(body)
#         event_type = data.get("event_type")
#         if event_type not in ["subscription_created", "subscription_updated"]:
#             return {
#                 'statusCode': 400,
#                 'body': json.dumps({'error': 'Unknown event type'})
#             }

#         timestamp = int(time.time())
#         object_key = f"bronze/{event_type}/{event_type}_{timestamp}.json"

#         s3.put_object(
#             Bucket=bucket_name,
#             Key=object_key,
#             Body=json.dumps(data),
#             ContentType='application/json'
#         )
  
#         # success_message = f"Data successfully written to S3 with object key: {object_key}"
#         # send_to_slack(success_message)

#         return {
#             'statusCode': 200,
#             'body': json.dumps({'message': 'Data successfully written to S3', 'object_key': object_key})
#         }

#     except json.JSONDecodeError:
#         # slack errors message
#         error_message = f'Invalid JSON format in {event_type} Shopify flow app' 
#         send_to_slack(f"Error in Lambda Function: {error_message}")
#         return {
#             'statusCode': 400,
#             'body': json.dumps({'error': error_message})
#         }
#     except Exception as e:
#         error_message = f"Unexpected error in {event_type}: {str(e)}"
#         send_to_slack(f"Error in Lambda function: {error_message}")
#         return {
#             'statusCode': 500,
#             'body': json.dumps({'error': error_message})
#         }