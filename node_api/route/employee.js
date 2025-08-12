// routes/employees.js
const router = require('express').Router();
const ctrl   = require('../controller/employeeController');
const authMiddleware = require('../middleware/authMiddleware');

router.get('/',     ctrl.list);
router.get('/:employeeId',  ctrl.getByEmployeeId);
router.get('/department/:departmentId', ctrl.getByDepartment)

module.exports = router;
