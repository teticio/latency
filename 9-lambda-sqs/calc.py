import json
from time import sleep

import boto3

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table("latency")


def lambda_handler(event, context):
    for record in event["Records"]:
        x = json.loads(record["body"])["x"]
        print("Calculating", x)
        sleep(x)

        table.update_item(
            Key={"id": 0},
            UpdateExpression="ADD done :inc",
            ExpressionAttributeValues={":inc": 1},
        )

    return {"statusCode": 200, "body": json.dumps({"result": x})}
