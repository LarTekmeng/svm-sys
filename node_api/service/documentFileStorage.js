const { PutObjectCommand, DeleteObjectCommand } = require('@aws-sdk/client-s3');
const { client } = require('./r2');

const BUCKET = process.env.R2_BUCKET_EMPLOYEE_FILES;
const PREFIX = (process.env.R2_PREFIX_DOCUMENT || 'documents').replace(/\/+$/,''); // no trailing slash
const PUBLIC_BASE = (process.env.R2_PUBLIC_URL_FILE || '').replace(/\/+$/,'');

function safeName(name) {
  return name.replace(/[^\w.\-() ]+/g, '_');
}

function buildKey(documentId, originalname) {
  return `${PREFIX}/${documentId}/${Date.now()}_${safeName(originalname)}`;
}

async function uploadBuffer({ documentId, buffer, contentType, originalname }) {
  const Key = buildKey(documentId, originalname);
  await client().send(new PutObjectCommand({
    Bucket: BUCKET,
    Key,
    Body: buffer,
    ContentType: contentType || 'application/octet-stream',
  }));
  const publicUrl = PUBLIC_BASE ? `${PUBLIC_BASE}/${Key}` : Key;
  return { key: Key, publicUrl };
}

async function deleteKey(key) {
  await client().send(new DeleteObjectCommand({ Bucket: BUCKET, Key: key }));
}

module.exports = { uploadBuffer, deleteKey };
