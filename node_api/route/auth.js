// routes/auth.js
const router = require('express').Router();
const ctrl   = require('../controller/authController');
const authMiddleware = require('../middleware/authMiddleware');

router.post('/register', ctrl.register);
router.post('/login',  authMiddleware,  ctrl.login);
router.post('/refresh', ctrl.refresh);


module.exports = router;
