// routes/documents.js
'use strict';

const router = require('express').Router();
const { requireAuth } = require('../middleware/authMiddleware');
const { requireAssigneeForStep } = require('../middleware/stepGuard'); // optional but recommended
const multer = require('multer');
const ctrl   = require('../controller/documentController');

// ---- multipart guard (avoid Busboy generic errors for wrong headers) ----
function multipartGuard(req, res, next) {
  const ct = String(req.headers['content-type'] || '');
  if (!ct.startsWith('multipart/form-data')) {
    return res.status(415).json({ error: 'Content-Type must be multipart/form-data' });
  }
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

/* =========================================================
   STATIC ROUTES FIRST (avoid :id capturing 'shared')
   ========================================================= */
// List read-only documents shared with me
// NOTE: your previous path '/api/documents/shared' was wrong once mounted.
// Final URL becomes:  <mount-prefix>/documents/shared/mine
router.get('/shared/mine', requireAuth, ctrl.listShared);

/* =========================================================
   DETAIL + ACTIONS
   ========================================================= */
// Document detail
router.get('/:id/detail', requireAuth, ctrl.detail);

// Single "decision" endpoint (your controller enforces assignee-only)
router.post('/:id/steps/:stepId/decision', requireAuth, ctrl.decideStep);

// OPTIONAL: explicit approve/reject routes with server-side guard
router.post('/:id/steps/:stepId/approve', requireAuth, requireAssigneeForStep, (req, res) => {
  req.body.decision = 'APPROVED';
  return ctrl.decideStep(req, res);
});
router.post('/:id/steps/:stepId/reject', requireAuth, requireAssigneeForStep, (req, res) => {
  req.body.decision = 'REJECTED';
  return ctrl.decideStep(req, res);
});

/* =========================================================
   FILES
   ========================================================= */
// Add files to existing document
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

// List files of a document
router.get('/:documentId/files', requireAuth, ctrl.listFiles);

// Delete one file
router.delete('/:documentId/files/:fileId', requireAuth, ctrl.removeFile);

/* =========================================================
   CREATE DOCUMENT + FILES (one call)
   ========================================================= */
router.post(
  '/with-files',
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
  ctrl.createWithFiles
);

module.exports = router;
