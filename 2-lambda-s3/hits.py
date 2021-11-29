import boto3


def lambda_handler(event, context):
    s3 = boto3.resource('s3')
    bucket = s3.Bucket('latency-lambda-s3')
    try:
        hits = int(bucket.Object('hits').get()['Body'].read().decode()) + 1
    except:
        hits = 1
    bucket.Object('hits').put(Body=str(hits).encode())
    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "text/plain",
        },
        'body': str(hits)
    }
