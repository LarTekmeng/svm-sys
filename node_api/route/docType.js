// routes/docTypes.js
const router = require('express').Router();
const ctrl   = require('../controller/docTypeController');
const authMiddleware = require('../middleware/authMiddleware');
router.post('/add', authMiddleware, ctrl.create);
router.delete('/:id', authMiddleware, ctrl.delete);
router.put('/:id', authMiddleware, ctrl.update);
router.get('/:id', authMiddleware, ctrl.getId);
router.put('/:documentTypeId/flow', authMiddleware, ctrl.updateFlow);
router.get('/:documentTypeId/flow', authMiddleware, ctrl.getFlow);

module.exports = router;
