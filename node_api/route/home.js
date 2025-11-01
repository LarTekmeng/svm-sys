const router = require('express').Router();
const ctrl = require('../controller/homeController');
const { requireAuth } = require('../middleware/authMiddleware');

router.get('/overview', requireAuth, ctrl.overview);

module.exports = router;