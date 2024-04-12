import argparse
import json
import random
import requests
from time import sleep, time

import boto3
from tqdm.auto import tqdm


def terraform_output(state_file_path, output_name):
    with open(state_file_path, "rt", encoding="utf-8") as file:
        state_data = json.load(file)
    output = state_data.get("outputs", {}).get(output_name, {}).get("value")
    return output


dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table("latency")
url = terraform_output("terraform.tfstate", "url")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Test latency of SQS queue")
    parser.add_argument("calculations", type=int, help="Number of calculations")
    parser.add_argument("max", type=int, help="Max value of x")
    args = parser.parse_args()

    table.update_item(
        Key={"id": 0},
        UpdateExpression="SET done = :done",
        ExpressionAttributeValues={":done": 0},
    )

    start = time()
    for i in tqdm(range(args.calculations)):
        response = requests.post(
            url,
            json={"x": random.uniform(0, args.max)},
            timeout=30,
        )

    while True:
        done = table.get_item(Key={"id": 0})["Item"]["done"]
        if done == args.calculations:
            break
        sleep(1)
        print(".", end="", flush=True)

    print()
    print(f"{time() - start:.2f} seconds")
