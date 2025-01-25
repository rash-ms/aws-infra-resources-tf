import json
import boto3
import os
import urllib3

s3 = boto3.client('s3')
http = urllib3.PoolManager()

slack_token = os.environ['SLACK_TOKEN']
slack_channel = os.environ['SLACK_CHANNEL']
slack_user_ids = ["U03V6VD8JHL"]     # Mujeeb     

# send slack message func
def send_to_slack(message):
    # format slack user_id
    user_mentions = " ".join([f"<@{user_id}>" for user_id in slack_user_ids])
    
    slack_message = {
        "channel": slack_channel,
        "text": f"{user_mentions} {message}"
    }
    response = http.request(
        'POST',
        'https://slack.com/api/chat.postMessage',
        body=json.dumps(slack_message),
        headers={
            'Content-Type': 'application/json',
            'Authorization': f'Bearer {slack_token}'
        }
    )
    if response.status != 200:
        print(f"Failed to send message to Slack: {response.status}, {response.data}")

# def load_schema():
#     response = s3.get_object(Bucket="my-schema-bucket", Key="schema.json")
#     schema = json.loads(response['Body'].read().decode('utf-8'))
#     return schema

def load_schema():
    # Assuming schema.json is in the same directory as lambda-func.py
    schema_path = os.path.join(os.path.dirname(__file__), 'schema.json')
    with open(schema_path, 'r') as schema_file:
        schema = json.load(schema_file)
    return schema


# Process data dynamically based on schema properties
def process_data(data, schema):
    processed_data = {}
    for field, specs in schema.get("properties", {}).items():
        processed_data[field] = data.get(field, None)  # Set to None if the field is missing

    return processed_data
