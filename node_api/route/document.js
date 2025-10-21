// routes/documents.js
'use strict';

const router = require('express').Router();
const {requireAuth}   = require('../middleware/authMiddleware');
const multer = require('multer');
const ctrl   = require('../controller/documentController');

// ---- multipart guard (avoid Busboy generic errors for wrong headers) ----
function multipartGuard(req, res, next) {
  const ct = String(req.headers['content-type'] || '');
  if (!ct.startsWith('multipart/form-data')) {
    return res.status(415).json({ error: 'Content-Type must be multipart/form-data' });
  }
  // helpful trace if client disconnects mid-upload
  req.on('aborted', () => console.warn('⚠️ request aborted by client during upload'));
  next();
}

// ---- Multer (memory) with sane limits ----
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    files: 12,                  // up to 12 files
    fileSize: 50 * 1024 * 1024, // 50MB each
    fields: 100,
    parts: 200,
  },
});

router.get('/:id/detail', requireAuth, ctrl.detail);
router.post('/:id/steps/:stepId/decision', requireAuth, ctrl.decideStep);
router.post(
  '/:id/files',
  requireAuth,
  multipartGuard,
  (req, res, next) => {
    upload.array('files', 12)(req, res, (err) => {
      if (!err) return next();
      if (err.code && err.code.startsWith('LIMIT')) {
        return res.status(413).json({ error: 'Upload too large or too many files', code: err.code, message: err.message });
      }
      return res.status(400).json({ error: 'Malformed multipart form data', message: err.message || String(err) });
    });
  },
  ctrl.addFilesToExisting
);

// ---- Create + upload files in one call ----
// Fields: document_type_id, title, description
// Files : "files": [..] (one or many)
router.post(
  '/with-files',
  requireAuth,
  multipartGuard,
  // wrap multer to normalize errors
  (req, res, next) => {
    upload.array('files', 12)(req, res, (err) => {
      if (!err) return next();
      if (err.code && err.code.startsWith('LIMIT')) {
        return res.status(413).json({ error: 'Upload too large or too many files', code: err.code, message: err.message });
      }
      return res.status(400).json({ error: 'Malformed multipart form data', message: err.message || String(err) });
    });
  },
  ctrl.createWithFiles
);

// ---- Files helpers ----
router.get('/:documentId/files', requireAuth, ctrl.listFiles);
router.delete('/:documentId/files/:fileId', requireAuth, ctrl.removeFile);
router.get('/api/documents/shared', requireAuth, ctrl.listShared);

module.exports = router;
