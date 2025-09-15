import json

def lambda_handler(event, context):
    # Get greeting from environment variable or use default
    greeting = "Hello World!"
    
    # Check if environment variable exists
    if 'greeting' in event:
        greeting = event['greeting']
    
    # Return response
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps({
            'message': greeting,
            'input': event
        })
    }