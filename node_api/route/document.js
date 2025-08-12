const router = require('express').Router();
const auth   = require('../middleware/authMiddleware');
const multer = require('multer');

// memory storage; 30MB per file, adjust as needed
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 30 * 1024 * 1024 },
});

const ctrl = require('../controller/documentController');

// List & simple create (JSON)
router.get('/', auth, ctrl.list);
router.post('/', auth, ctrl.create);

// Register-style: create + upload files in one call
// Send fields: document_type_id, title, description
// Send files:  "files": [..]  (one or many)
router.post('/with-files', auth, upload.array('files'), ctrl.createWithFiles);

// Files helpers
router.get('/:documentId/files', auth, ctrl.listFiles);
router.delete('/:documentId/files/:fileId', auth, ctrl.removeFile);

module.exports = router;
