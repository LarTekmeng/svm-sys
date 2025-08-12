const router = require('express').Router();
const ctrl = require('../controller/homeController');
const auth = require('../middleware/authMiddleware');

router.get('/overview', auth, ctrl.overview);

module.exports = router;