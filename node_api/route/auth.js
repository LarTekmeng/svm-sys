// routes/auth.js
const router = require('express').Router();
const ctrl   = require('../controller/authController');
const { requireAuth } = require('../middleware/authMiddleware');

router.post('/register', ctrl.register);
router.post('/login', ctrl.login);
router.post('/refresh', requireAuth, ctrl.refresh);


module.exports = router;
