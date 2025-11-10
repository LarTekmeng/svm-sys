const express = require('express');
const router = express.Router();
const controller = require('../controller/departmentController');

// GET /api/departments
router.get('/', controller.all);
// POST /api/departments
router.post('/', controller.create);

module.exports = router;
