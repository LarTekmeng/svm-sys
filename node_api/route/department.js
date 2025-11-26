const express = require('express');
const router = express.Router();
const controller = require('../controller/departmentController');

// GET /api/departments - Get all departments
router.get('/', controller.all);

// POST /api/departments - Create new department
router.post('/', controller.create);

// PUT /api/departments/:id - Update department by ID
router.put('/:id', controller.update);

// DELETE /api/departments/:id - Delete department by ID
router.delete('/:id', controller.delete);

module.exports = router;