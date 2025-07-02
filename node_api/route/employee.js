// routes/employees.js
const router = require('express').Router();
const ctrl   = require('../controller/employeeController');

router.get('/',     ctrl.list);
router.get('/:employeeId',  ctrl.getByEmployeeId);

module.exports = router;
