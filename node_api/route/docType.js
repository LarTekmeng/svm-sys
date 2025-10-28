// routes/docTypes.js
'use strict';

const router = require('express').Router();
const ctrl   = require('../controller/docTypeController'); // ← keep name consistent
const { requireAuth } = require('../middleware/authMiddleware');

// List doctypes (ADMIN → all; EMPLOYEE → mine)
router.get('/:id', requireAuth, ctrl.getId);


// Create a new doctype (owner = current user)
router.post('/', requireAuth, ctrl.create);

// Flow endpoints MUST come before "/:id" to avoid param-capture issues
router.get('/:documentTypeId/flow', requireAuth, ctrl.getFlow);
router.post('/:documentTypeId/flow', requireAuth, ctrl.updateFlow);

// Update / Delete by id (owner OR admin)
router.put('/:id', requireAuth, ctrl.update);
router.delete('/:id', requireAuth, ctrl.delete);

module.exports = router;
