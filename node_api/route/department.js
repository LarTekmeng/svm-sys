/* This is Route*/

const router = require('express').Router();
const ctrl   = require('../controller/departmentController');

router.get('/all', ctrl.all);

module.exports = router;