import argparse
import asyncio
import json
import math
import random
import uuid
from time import sleep, time

import aio_pika
from tqdm.auto import tqdm


def terraform_output(state_file_path, output_name):
    with open(state_file_path, "rt", encoding="utf-8") as file:
        state_data = json.load(file)
    output = state_data.get("outputs", {}).get(output_name, {}).get("value")
    return output


class RpcClient:
    def __init__(self):
        self.loop = asyncio.get_event_loop()
        self.connection = None
        self.channel = None
        self.callback_queue = None
        self.futures = {}

    async def connect(self):
        url = terraform_output("terraform.tfstate", "url")
        self.connection = await aio_pika.connect_robust(url=url, loop=self.loop)

        self.channel = await self.connection.channel()
        self.callback_queue = await self.channel.declare_queue(exclusive=True)

        await self.channel.set_qos(prefetch_count=1)
        await self.callback_queue.consume(self.on_response)

    async def disconnect(self):
        await self.connection.close()

    async def on_response(self, message: aio_pika.IncomingMessage):
        async with message.process():
            self.futures[message.correlation_id].set_result(message.body)

    async def call(self, n):
        correlation_id = str(uuid.uuid4())
        future = self.loop.create_future()

        await self.channel.default_exchange.publish(
            aio_pika.Message(
                body=str(n).encode(),
                correlation_id=correlation_id,
                reply_to=self.callback_queue.name,
            ),
            routing_key="rpc_queue",
        )

        self.futures[correlation_id] = future
        result = await future
        return float(result)


async def main(args):
    rpc_client = RpcClient()
    await rpc_client.connect()

    async def calc(x, progress):
        response = await rpc_client.call(x)
        assert math.fabs(response - x) < 1e-6
        progress.update(1)

    start = time()
    with tqdm(total=args.calculations) as progress:
        tasks = [
            calc(random.uniform(0, args.max), progress)
            for _ in range(args.calculations)
        ]
        await asyncio.gather(*tasks)

    print(f"{time() - start:.2f} seconds")
    await rpc_client.disconnect()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Test latency of RabbitMQ queue")
    parser.add_argument("calculations", type=int, help="Number of calculations")
    parser.add_argument("max", type=float, help="Max value of x")
    args = parser.parse_args()
    asyncio.run(main(args))
