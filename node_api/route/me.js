const express = require('express');
const router = express.Router();
const multer = require('multer');
const upload = multer({ storage: multer.memoryStorage() });

const Me = require('../controller/editProfileController');
const { requireAuth } = require('../middleware/authMiddleware');

router.patch('/', requireAuth, upload.single('avatar'), Me.updateProfile);
router.patch('/password', requireAuth, Me.changePassword);

module.exports = router;
