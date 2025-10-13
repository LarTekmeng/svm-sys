/*PATH: /node_api/service/r2.js*/
'use strict';

const { S3Client } = require('@aws-sdk/client-s3');

let _client;
function client() {
  if (_client) return _client;

  const endpoint = process.env.R2_S3_ENDPOINT;
  const accessKeyId = process.env.R2_ACCESS_KEY;
  const secretAccessKey = process.env.R2_SECRET_KEY;

  if (!endpoint || !accessKeyId || !secretAccessKey) {
    throw new Error('R2 env missing: R2_S3_ENDPOINT / R2_ACCESS_KEY / R2_SECRET_KEY');
  }

  _client = new S3Client({
    region: 'auto',
    endpoint,
    credentials: { accessKeyId, secretAccessKey },
    forcePathStyle: true, // important for R2
  });
  return _client;
}

module.exports = { client };
