var AWS = require('aws-sdk');
AWS.config.update({ region: process.env.AWS_REGION });

var ddb = new AWS.DynamoDB({ apiVersion: '2012-08-10' });

exports.lambda_handler = async function (event) {
  var hits;

  data = await ddb.getItem({
    TableName: 'latency',
    Key: {
      'id': { N: '0' }
    }
  }).promise();
  try {
    hits = parseInt(data.Item.hits.N) + 1;
  } catch {
    hits = 1;
  }
  await ddb.updateItem({
    TableName: 'latency',
    Key: {
      'id': { N: '0' }
    },
    UpdateExpression: 'SET hits = :hits',
    ExpressionAttributeValues: {
      ':hits': { N: String(hits) }
    }
  }).promise();
  return {
    'statusCode': 200,
    'headers': {
      'Content-Type': 'text/plain',
    },
    'body': String(hits)
  };
}
