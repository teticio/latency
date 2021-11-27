import aiohttp
import asyncio
import argparse
from timeit import default_timer as timer


async def test_latency(url, hits=1000):
    start = timer()
    for _ in range(hits):
        async with aiohttp.ClientSession() as session:
            async with session.get(url) as response:
                text = await response.text()
    end = timer()
    print(f"{(end - start) * 1000 / hits:.2f}ms")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Test latency of URL")
    parser.add_argument('url', type=str, help="URL to test")
    parser.add_argument('hits', type=int, help="Number of hits")
    args = parser.parse_args()
    asyncio.run(test_latency(args.url, args.hits))
