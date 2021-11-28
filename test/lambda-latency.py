import json
import boto3
import argparse

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Test latency of URL")
    parser.add_argument('url', type=str, help="URL to test")
    parser.add_argument('hits', type=int, help="Number of hits")
    args = parser.parse_args()
    lambda_client = boto3.client('lambda')
    ms = lambda_client.invoke(FunctionName='test-latency',
                              InvocationType='RequestResponse',
                              Payload=json.dumps({
                                  "url": args.url,
                                  "hits": args.hits
                              }))['Payload'].read().decode()
    print(f"{float(ms):.2f}ms")
