// routes/auth.js
const router = require('express').Router();
const ctrl   = require('../controller/authController');

router.post('/register', ctrl.register);
router.post('/login',    ctrl.login);
router.post('/refresh', ctrl.refresh);


module.exports = router;
