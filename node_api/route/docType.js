// routes/docTypes.js
const router = require('express').Router();
const ctrl   = require('../controller/docTypeController');
const {requireAuth} = require('../middleware/authMiddleware');
router.post('/add', requireAuth, ctrl.create);
router.delete('/:id', requireAuth, ctrl.delete);
router.put('/:id', requireAuth, ctrl.update);
router.get('/:id', requireAuth, ctrl.getId);
router.put('/:documentTypeId/flow', requireAuth, ctrl.updateFlow);
router.get('/:documentTypeId/flow', requireAuth, ctrl.getFlow);

module.exports = router;
