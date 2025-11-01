// middleware/stepGuard.js
const db = require('../db');

/**
 * Only the assignee of a PENDING step can act (approve/reject).
 * Admins are NOT exempt — they must also be the assignee.
 */
async function requireAssigneeForStep(req, res, next) {
  const stepId = Number(req.params.stepId || req.body.stepId);
  if (!stepId) return res.status(400).json({ error: 'Missing stepId' });

  const step = await db.oneOrNone(
    'SELECT employee_id, status FROM document_steps WHERE id = $1',
    [stepId]
  );
  if (!step) return res.status(404).json({ error: 'Step not found' });

  if (step.employee_id !== req.user.id || step.status !== 'PENDING') {
    return res.status(403).json({ error: 'You are not allowed to act on this step' });
  }
  next();
}

module.exports = { requireAssigneeForStep };
