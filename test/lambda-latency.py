import os
import hcl
import json
import boto3
import botocore
import argparse

if __name__ == '__main__':
    with open(os.path.join(os.path.dirname(__file__), 'variables.tf')) as file:
        variables = hcl.load(file)
    region = variables['variable']['region']['default']
    parser = argparse.ArgumentParser(description="Test latency of URL")
    parser.add_argument('url', type=str, help="URL to test")
    parser.add_argument('hits', type=int, help="Number of hits")
    args = parser.parse_args()
    config = botocore.config.Config(read_timeout=300, region_name=region)
    lambda_client = boto3.client('lambda', config=config)
    ms = lambda_client.invoke(FunctionName='test-latency',
                              InvocationType='RequestResponse',
                              Payload=json.dumps({
                                  "url": args.url,
                                  "hits": args.hits
                              }))['Payload'].read().decode()
    print(f"{float(ms):.2f}ms")
