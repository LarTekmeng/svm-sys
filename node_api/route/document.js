const router = require('express').Router();
const ctrl   = require('../controller/documentController');

router.get('/list',  ctrl.list);
router.post('/create', ctrl.create);


module.exports = router;