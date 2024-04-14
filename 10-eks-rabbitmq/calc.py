import json
from time import sleep

import pika


def terraform_output(state_file_path, output_name):
    with open(state_file_path, "rt", encoding="utf-8") as file:
        state_data = json.load(file)
    output = state_data.get("outputs", {}).get(output_name, {}).get("value")
    return output


def on_request(ch, method, properties, body):
    x = float(body)
    print(f"calc({x})")
    sleep(x)
    response = x

    ch.basic_publish(
        exchange="",
        routing_key=properties.reply_to,
        properties=pika.BasicProperties(correlation_id=properties.correlation_id),
        body=str(response),
    )
    ch.basic_ack(delivery_tag=method.delivery_tag)


url = terraform_output("terraform.tfstate", "url")
connection = pika.BlockingConnection(
    pika.URLParameters(url=url)
)
channel = connection.channel()

channel.queue_declare(queue="rpc_queue")
channel.basic_qos(prefetch_count=1)
channel.basic_consume(queue="rpc_queue", on_message_callback=on_request)

print("Awaiting RPC requests")
channel.start_consuming()
