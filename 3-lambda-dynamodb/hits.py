import boto3


def lambda_handler(event, context):
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('latency')
    try:
        hits = table.get_item(Key={'id': 0})['Item']['hits'] + 1
    except:
        hits = 1
    table.put_item(Item={'id': 0, 'hits': hits})
    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "text/plain",
        },
        'body': str(hits)
    }
