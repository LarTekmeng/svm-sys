// routes/docTypes.js
const router = require('express').Router();
const ctrl   = require('../controller/docTypeController');
const authMiddleware = require('../middleware/authMiddleware');
router.post('/add', authMiddleware, ctrl.create);
router.get('/list', authMiddleware,  ctrl.list);
router.delete('/:id', ctrl.delete);
router.put('/:id', ctrl.update);
router.get('/:em_id', authMiddleware, ctrl.get_by_id);

module.exports = router;
