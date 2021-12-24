use aws_config::meta::region::RegionProviderChain;
use aws_sdk_dynamodb::model::AttributeValue;
use aws_sdk_dynamodb::Client;
use lambda_runtime::{handler_fn, Context, Error};
use serde_json::{json, Value};

#[tokio::main]
async fn main() -> Result<(), Error> {
    let region_provider = RegionProviderChain::default_provider();
    let shared_config = aws_config::from_env().region(region_provider).load().await;
    let client = Client::new(&shared_config);
    let func = handler_fn(|event, context| func(event, context, &client));
    lambda_runtime::run(func).await?;
    Ok(())
}

async fn func(_event: Value, _: Context, client: &Client) -> Result<Value, Error> {
    let table_name = "latency";
    let item_name = "hits";
    let key_name = "id";
    let id = AttributeValue::N(String::from("0"));

    let response = client
        .get_item()
        .table_name(table_name)
        .key(key_name, id.clone())
        .send()
        .await?;
    let item = response.item();

    let hits = if let Some(item) = item {
        if let Some(item) = item.get(item_name) {
            if let AttributeValue::N(value) = item {
                value
            } else {
                "0"
            }
        } else {
            "0"
        }
    } else {
        "0"
    };

    let hits = (hits.parse::<i32>()? + 1).to_string();
    client
        .update_item()
        .table_name(table_name)
        .key(key_name, id)
        .update_expression(String::from("SET hits = :hits"))
        .expression_attribute_values(String::from(":hits"), AttributeValue::N(hits.clone()))
        .send()
        .await?;

    Ok(json!({
        "statusCode": 200,
        "headers": {
            "Content-Type": "text/plain",
        },
        "body": &hits
    }))
}
