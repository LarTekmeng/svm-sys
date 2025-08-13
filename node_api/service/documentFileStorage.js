// documentFileStorage.js
'use strict';

const { PutObjectCommand, DeleteObjectCommand } = require('@aws-sdk/client-s3');
const { client } = require('./r2');

const BUCKET = process.env.R2_BUCKET_EMPLOYEE_FILES;
const PREFIX = (process.env.R2_PREFIX_DOCUMENT || 'documents').replace(/\/+$/, '');
const PUBLIC_BASE = (process.env.R2_PUBLIC_URL_FILE || '').replace(/\/+$/, '');

if (!BUCKET) {
  throw new Error('R2_BUCKET_EMPLOYEE_FILES is not set');
}

function safeName(name) {
  return name.replace(/[^\w.\-() ]+/g, '_');
}

function buildKey(documentId, originalname) {
  return `${PREFIX}/${documentId}/${Date.now()}_${safeName(originalname || 'file')}`;
}

async function uploadBuffer({ documentId, buffer, contentType, originalname }) {
  const Key = buildKey(documentId, originalname);
  try {
    await client().send(new PutObjectCommand({
      Bucket: BUCKET,
      Key,
      Body: buffer,
      ContentType: contentType || 'application/octet-stream',
    }));
  } catch (e) {
    e.message = `R2 PutObject failed (bucket=${BUCKET}, key=${Key}, endpoint=${process.env.R2_S3_ENDPOINT}): ${e.message}`;
    e.uploadKey = Key; // expose for cleanup
    throw e;
  }
  const publicUrl = PUBLIC_BASE ? `${PUBLIC_BASE}/${Key}` : Key;
  return { key: Key, publicUrl };
}

async function deleteKey(key) {
  try {
    await client().send(new DeleteObjectCommand({ Bucket: BUCKET, Key: key }));
  } catch (_e) {
    // best-effort; ignore
  }
}

module.exports = { uploadBuffer, deleteKey, buildKey };
