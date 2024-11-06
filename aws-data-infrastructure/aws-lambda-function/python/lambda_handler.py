import json

def lambda_handler(event, context):
   message = 'Hello {} !'.format(event['key1'])
   return {
       'statusCode': 200,
       'body' : json.dumps('Hello from Lambda')
   }
