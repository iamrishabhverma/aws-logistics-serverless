const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();
exports.handler = async () => {
  const data = await dynamodb.scan({ TableName: 'Shipments' }).promise();
  return { statusCode: 200, body: JSON.stringify(data.Items) };
};