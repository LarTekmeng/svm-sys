const { S3Client } = require('@aws-sdk/client-s3');

let _client;
function client() {
    if (_client) return _client;
    _client = new S3Client({
        region: 'auto',
        endpoint: process.env.R2_S3_ENDPOINT,
        credentials: {
            accessKeyId: process.env.R2_ACCESS_KEY,
            secretAccessKey: process.env.R2_SECRET_KEY,
        },
        forcePathStyle: true,
    });
    return _client
}

module.exports = { client };