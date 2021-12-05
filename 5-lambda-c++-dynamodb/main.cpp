#include <string>
#include <iostream>

#include <aws/core/Aws.h>
#include <aws/core/utils/Outcome.h>
#include <aws/core/platform/Environment.h>
#include <aws/core/client/ClientConfiguration.h>
#include <aws/core/auth/AWSCredentialsProvider.h>
#include <aws/dynamodb/DynamoDBClient.h>
#include <aws/dynamodb/model/AttributeDefinition.h>
#include <aws/dynamodb/model/GetItemRequest.h>
#include <aws/dynamodb/model/UpdateItemRequest.h>
#include <aws/lambda-runtime/runtime.h>

using namespace aws::lambda_runtime;

static char const TAG[] = "lambda";

invocation_response my_handler(invocation_request const &request,
                               Aws::DynamoDB::DynamoDBClient const &dynamoClient)
{
   std::string hits;

   Aws::DynamoDB::Model::GetItemRequest getRequest;
   getRequest.SetTableName("latency");
   Aws::DynamoDB::Model::AttributeValue key;
   key.SetN(0);
   getRequest.AddKey("id", key);
   getRequest.SetProjectionExpression("hits");
   const Aws::DynamoDB::Model::GetItemOutcome &getResult = dynamoClient.GetItem(getRequest);
   const Aws::Map<Aws::String, Aws::DynamoDB::Model::AttributeValue> &item = getResult.GetResult().GetItem();

   if (item.size() > 0)
      hits = std::to_string(std::stoi(item.begin()->second.GetN()) + 1);
   else
      hits = "1";

   Aws::DynamoDB::Model::UpdateItemRequest updateRequest;
   updateRequest.SetTableName("latency");
   updateRequest.AddKey("id", key);
   updateRequest.SetUpdateExpression("SET hits = :hits");
   Aws::DynamoDB::Model::AttributeValue attributeUpdatedValue;
   attributeUpdatedValue.SetN(hits);
   Aws::Map<Aws::String, Aws::DynamoDB::Model::AttributeValue> expressionAttributeValues;
   expressionAttributeValues[":hits"] = attributeUpdatedValue;
   updateRequest.SetExpressionAttributeValues(expressionAttributeValues);
   const Aws::DynamoDB::Model::UpdateItemOutcome &updateResult = dynamoClient.UpdateItem(updateRequest);

   return invocation_response::success(
       "{\"statusCode\": 200, \"headers\": {\"Content-Type\": \"text/plain\"}, \"body\": \"" + hits + "\"}",
       "application/json");
}

int main()
{
   Aws::SDKOptions options;
   Aws::InitAPI(options);
   {
      Aws::Client::ClientConfiguration config;
      config.region = Aws::Environment::GetEnv("AWS_REGION");
      config.caFile = "/etc/pki/tls/certs/ca-bundle.crt";
      config.disableExpectHeader = true;
      auto credentialsProvider = Aws::MakeShared<Aws::Auth::EnvironmentAWSCredentialsProvider>(TAG);
      Aws::DynamoDB::DynamoDBClient dynamoClient(credentialsProvider, config);

      auto handler_fn = [&dynamoClient](invocation_request const &req)
      {
         return my_handler(req, dynamoClient);
      };
      run_handler(handler_fn);
   }
   ShutdownAPI(options);
   return 0;
}
