import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('latency')


def lambda_handler(event, context):
    try:
        hits = table.get_item(Key={'id': 0})['Item']['hits'] + 1
        table.update_item(Key={'id': 0},
                          UpdateExpression='SET hits = :hits',
                          ExpressionAttributeValues={':hits': hits})
    except:
        hits = 1
        table.put_item(Item={'id': 0, 'hits': hits})
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'text/plain',
        },
        'body': str(hits)
    }
