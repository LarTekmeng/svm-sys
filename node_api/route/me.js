// route/me.js
const express = require('express');
const router = express.Router();
const multer = require('multer');

// Use memory storage so we can push straight to R2
const upload = multer({ storage: multer.memoryStorage() });

const Me = require('../controller/editProfileController');

// If you already have an auth middleware, import it here:
const auth = require('../middleware/authMiddleware'); // must set req.employee or req.user with { id, em_id, ... }

// Self-service routes
router.patch('/me', auth, upload.single('avatar'), Me.updateProfile);
router.patch('/me/password', auth, Me.changePassword);

// Admin-only (optional): attach your RBAC middleware if you have one
// const { requireRole } = require('./authMiddleware');
// router.post('/employees/:id/password-reset', auth, requireRole('ADMIN'), Me.adminResetPassword);

module.exports = router;
