const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();
const comprehend = new AWS.Comprehend();
exports.handler = async (event) => {
  const { trackingId, status, origin, destination } = JSON.parse(event.body);
  const keyPhrases = await comprehend.detectKeyPhrases({ Text: status, LanguageCode: 'en' }).promise();
  const anomaly = keyPhrases.KeyPhrases.some(p => p.Text.toLowerCase().includes('delay')) ? 'Potential Delay' : 'Normal';
  const shipment = { id: Date.now().toString(), trackingId, status, origin, destination, anomaly, createdAt: new Date().toISOString() };
  await dynamodb.put({ TableName: 'Shipments', Item: shipment }).promise();
  return { statusCode: 201, body: JSON.stringify(shipment) };
};