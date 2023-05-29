import json

def lambda_handler(event, context):


    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "hello world - We are going to create a DevOps as a service powered by IA"

        }),
    }
