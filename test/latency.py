import aiohttp
import asyncio
import argparse
from timeit import default_timer as timer


async def test_latency(url, hits=1000):
    async with aiohttp.ClientSession() as session:
        start = timer()
        for _ in range(hits):
            async with session.get(url) as response:
                text = await response.text()
        end = timer()
    return (end - start) * 1000 / hits


def lambda_handler(event, context):
    return asyncio.run(test_latency(event['url'], event['hits']))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Test latency of URL")
    parser.add_argument('url', type=str, help="URL to test")
    parser.add_argument('hits', type=int, help="Number of hits")
    args = parser.parse_args()
    ms = asyncio.run(test_latency(args.url, args.hits))
    print(f"{ms:.2f}ms")
