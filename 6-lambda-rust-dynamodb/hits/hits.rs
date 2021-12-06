use aws_config::meta::region::RegionProviderChain;
use aws_sdk_dynamodb::model::AttributeValue;
use aws_sdk_dynamodb::Client;
use lambda_runtime::{handler_fn, Context, Error};
use serde_json::{json, Value};
use std::collections::HashMap;

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

    let response = &client
        .get_item()
        .table_name(table_name.to_string())
        .key(key_name.to_string(), AttributeValue::N("0".to_string()))
        .send()
        .await
        .expect("Failed to get item");
    let item = response.item();

    let default_value = AttributeValue::N("0".to_string());
    let mut default_item = HashMap::new();
    default_item.insert(item_name.to_string(), default_value.clone());
    let item = match item.unwrap_or(&default_item).get(item_name) {
        Some(value) => value,
        None => &default_value
    };
    let hits = match item {
        AttributeValue::N(value) => value,
        _ => "0",
    };

    let hits = hits.parse::<i32>().unwrap() + 1;
    client
        .update_item()
        .table_name(table_name.to_string())
        .key(key_name.to_string(), AttributeValue::N("0".to_string()))
        .update_expression("SET hits = :hits".to_string())
        .expression_attribute_values(":hits".to_string(), AttributeValue::N(hits.to_string()))
        .send()
        .await
        .expect("Failed to update item");

    Ok(json!({
        "statusCode": 200,
        "headers": {
            "Content-Type": "text/plain",
        },
        "body": hits.to_string()
    }))
}
