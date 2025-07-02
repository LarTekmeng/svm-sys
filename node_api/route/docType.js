// routes/docTypes.js
const router = require('express').Router();
const ctrl   = require('../controller/docTypeController');

router.post('/add', ctrl.create);
router.get('/list',  ctrl.list);
router.delete('/:id', ctrl.delete);
router.put('/:id', ctrl.update);

module.exports = router;
