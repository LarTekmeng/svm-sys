// routes/employees.js
const router = require('express').Router();
const ctrl   = require('../controller/employeeController');

router.get('/', ctrl.list);
router.get('/department/:departmentId', ctrl.getByDepartment);
router.get('/:employeeId', ctrl.getByEmployeeId);
router.put('/:id', ctrl.update);
router.delete('/:id', ctrl.delete);

module.exports = router;
