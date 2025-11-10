const express = require('express');
const router = express.Router();
const controller = require('../controller/roleController');

// GET /api/departments
router.get('/', controller.list);

module.exports = router;