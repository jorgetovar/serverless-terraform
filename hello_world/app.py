import json

import requests

def lambda_handler(event, context):

    response = requests.get("https://test-api.k6.io/public/crocodiles/")
    if response.status_code == 200:
        data = response.json()
        random_info = data['name']
    else:
        random_info = "No data!"

    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "hello world - We are going to create a DevOps as a service powered by IA",
            "random_info": random_info

        }),
    }
