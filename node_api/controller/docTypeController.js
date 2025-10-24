// controller/documentTypeController.js
const db = require('../db');

// helpers
const getMe = (req) => ({
  id:   req.user?.id ?? req.employee?.id ?? null,
  role: req.user?.role ?? req.employee?.role ?? null,
});
const isAdminReq = (req) => getMe(req).role === 'ADMIN';

/* Create New Document Type */
exports.create = async (req, res) => {
  const { title, description } = req.body;
  const ownerId = getMe(req).id;

  if (!ownerId || !title?.trim() || !description?.trim()) {
    return res.status(400).json({ error: 'Missing title/description or not authenticated' });
  }

  try {
    const addDocumentType = `
      INSERT INTO document_types (title, description, owner_id, created_at)
      VALUES ($1, $2, $3, NOW())
      RETURNING id
    `;
    const { id } = await db.one(addDocumentType, [title.trim(), description.trim(), ownerId]);

    const addDocumentTypeSetting = `
      INSERT INTO document_type_settings (document_type_id, action, forward_mode, created_at)
      VALUES ($1, 'Read-Only', 'Direct', NOW())
      ON CONFLICT (document_type_id) DO NOTHING
    `;
    await db.none(addDocumentTypeSetting, [id]);

    return res.status(201).json({ message: 'Document type created', id });
  } catch (err) {
    console.error('Error creating document type:', err);
    return res.status(500).json({ error: 'Server error' });
  }
};

/* Delete Document Type (owner OR admin) */
exports.delete = async (req, res) => {
  const { id } = req.params;

  try {
    const me = getMe(req);
    if (!me.id) return res.status(401).json({ error: 'Not Authenticated' });

    const own = await db.oneOrNone('SELECT owner_id FROM document_types WHERE id = $1', [id]);
    if (!own) return res.status(404).json({ error: 'Document type not found' });
    if (!isAdminReq(req) && own.owner_id !== me.id) return res.status(403).json({ error: 'Forbidden' });

    const result = await db.tx(async t => {
      await t.none('DELETE FROM document_type_flows WHERE document_type_id = $1', [id]);
      await t.none('DELETE FROM document_type_settings WHERE document_type_id = $1', [id]);

      const used = await t.one('SELECT COUNT(*)::int AS c FROM documents WHERE document_type_id = $1', [id]);
      if (used.c > 0) throw new Error('Cannot delete: there are documents using this type');

      return t.result('DELETE FROM document_types WHERE id = $1', [id]);
    });

    if (result.rowCount === 0) return res.status(404).json({ error: 'Document type not found' });
    res.status(200).json({ message: 'Document type deleted', id: Number(id) });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: e.message || 'Server error' });
  }
};

/* Update Document Type (owner OR admin) */
exports.update = async (req, res) => {
  const docTypeId = parseInt(req.params.id, 10);
  const { title, description } = req.body;
  const currentUser = getMe(req).id;

  if (!currentUser || !title?.trim() || !description?.trim()) {
    return res.status(400).json({ error: 'Missing fields or not authenticated' });
  }

  try {
    const row = await db.oneOrNone(`SELECT owner_id FROM document_types WHERE id = $1`, [docTypeId]);
    if (!row) return res.status(404).json({ error: 'Document type not found' });
    if (!isAdminReq(req) && row.owner_id !== currentUser) {
      return res.status(403).json({ error: 'Not allowed to update this document type' });
    }

    await db.result(
      `UPDATE document_types SET title = $1, description = $2, updated_at = NOW() WHERE id = $3`,
      [title.trim(), description.trim(), docTypeId]
    );

    return res.json({ message: 'Document type updated', id: docTypeId });
  } catch (err) {
    console.error('Error updating document type:', err);
    return res.status(500).json({ error: 'Server error' });
  }
};

/* Create/Replace Flow & Settings (owner OR admin) */
exports.updateFlow = async (req, res) => {
  const docTypeId = parseInt(req.params.documentTypeId, 10);
  const me        = getMe(req);
  let { action, forward_mode, flows } = req.body;

  if (!me.id) return res.status(401).json({ error: 'Not Authenticated' });

  action = (action === 'Read-Only') ? 'Read-Only' : 'Ask for Permission';
  forward_mode = (forward_mode === 'Step by Step') ? 'Step by Step' : 'Direct';

  const row = await db.oneOrNone(`SELECT owner_id FROM document_types WHERE id = $1`, [docTypeId]);
  if (!row) return res.status(404).json({ error: 'Not found' });
  if (!isAdminReq(req) && row.owner_id !== me.id) {
    return res.status(403).json({ error: 'Forbidden to Update' });
  }

  const upsertSettingSql = `
    INSERT INTO document_type_settings
      (document_type_id, action, forward_mode, created_at, updated_at)
    VALUES ($3, $1, $2, NOW(), NOW())
    ON CONFLICT (document_type_id)
    DO UPDATE SET action = EXCLUDED.action, forward_mode = EXCLUDED.forward_mode, updated_at = NOW()
  `;
  const deleteFlowSql = `DELETE FROM document_type_flows WHERE document_type_id = $1`;
  const insertFlowSql = `
    INSERT INTO document_type_flows
      (document_type_id, sequence, department_id, employee_id, step_action)
    VALUES ($1, $2, $3, $4, $5)
    ON CONFLICT (document_type_id, sequence, employee_id) DO NOTHING
  `;

  try {
    await db.tx(async t => {
      const isReadOnly = (action === 'Read-Only');
      const effectiveMode = isReadOnly ? 'Direct' : forward_mode;

      await t.none(upsertSettingSql, [action, effectiveMode, docTypeId]);

      const hasFlowsPayload = Array.isArray(flows);
      if (hasFlowsPayload) {
        await t.none(deleteFlowSql, [docTypeId]);
        for (const f of (flows || [])) {
          const seq      = Number(f.sequence) || 1;
          const stepAct  = isReadOnly ? 'READ-ONLY' : (f.step_action || 'APPROVAL');
          const deptAll  = (f.department_id === 'all');
          const empAll   = (f.employee_id   === 'all');

          if (deptAll && empAll) {
            const everyone = await t.any(`SELECT id, dp_id FROM employee`);
            for (const emp of everyone) {
              await t.none(insertFlowSql, [docTypeId, seq, emp.dp_id, emp.id, stepAct]);
            }
          } else if (deptAll) {
            const emp = await t.one(`SELECT id, dp_id FROM employee WHERE id = $1`, [f.employee_id]);
            await t.none(insertFlowSql, [docTypeId, seq, emp.dp_id, emp.id, stepAct]);
          } else if (empAll) {
            const deptEmps = await t.any(`SELECT id FROM employee WHERE dp_id = $1`, [f.department_id]);
            for (const emp of deptEmps) {
              await t.none(insertFlowSql, [docTypeId, seq, f.department_id, emp.id, stepAct]);
            }
          } else {
            await t.none(insertFlowSql, [docTypeId, seq, f.department_id, f.employee_id, stepAct]);
          }
        }
      }
    });

    return res.json({ message: 'Flow & settings updated' });
  } catch (e) {
    console.error('updateFlow error:', e);
    return res.status(500).json({ error: 'Server error' });
  }
};

/* List document types (ADMIN → all, EMPLOYEE → mine) */
exports.getId = async (req, res) => {
  const me = getMe(req);
  if (!me.id) return res.status(401).json({ error:'Not Authenticated' });
  try{
    const rows = isAdminReq(req)
      ? await db.any('SELECT id, title, description FROM document_types ORDER BY created_at DESC')
      : await db.any('SELECT id, title, description FROM document_types WHERE owner_id = $1 ORDER BY created_at DESC', [me.id]);
    res.json(rows);
  } catch (e){
    console.error(e);
    res.status(500).json({ error: 'Error fetching document types' });
  }
};

/* Fetch settings + flow (owner OR admin) */
exports.getFlow = async (req, res) => {
  try {
    const docTypeId = parseInt(req.params.documentTypeId, 10);
    const me        = getMe(req);
    if (!me.id) return res.status(401).json({ error: 'Not Authenticated' });

    const row = await db.oneOrNone('SELECT owner_id FROM document_types WHERE id = $1', [docTypeId]);
    if (!row) return res.status(404).json({ error: 'Not Found!' });
    if (!isAdminReq(req) && row.owner_id !== me.id) return res.status(403).json({ error: 'Forbidden' });

    const settings = await db.oneOrNone(
      `SELECT action, forward_mode FROM document_type_settings WHERE document_type_id = $1 LIMIT 1`,
      [docTypeId]
    );

    const flows = await db.any(
      `SELECT f.sequence, f.department_id, d.name AS department_name,
              f.employee_id, e.employee_name, f.step_action
       FROM document_type_flows f
       LEFT JOIN department d ON d.id = f.department_id
       LEFT JOIN employee  e ON e.id = f.employee_id
       WHERE f.document_type_id = $1
       ORDER BY f.sequence ASC, f.employee_id ASC`,
      [docTypeId]
    );

    const s = settings ?? { action: 'Read-Only', forward_mode: 'Direct' };
    if (s.action === 'Read-Only') s.forward_mode = 'Direct';
    const actions = (s.action === 'Read-Only') ? ['READ-ONLY'] : ['APPROVAL', 'SIGNATURE'];

    return res.json({
      document_type_id: docTypeId,
      settings: s,
      flows: flows.map(f => ({
        sequence: f.sequence,
        department_id: f.department_id,
        department: f.department_id ? { id: f.department_id, name: f.department_name } : null,
        employee_id: f.employee_id,
        employee: f.employee_id ? { id: f.employee_id, name: f.employee_name } : null,
        step_action: f.step_action,
      })),
      actions,
    });
  } catch (err) {
    console.error('getFlow error:', err);
    return res.status(500).json({ error: 'Server error' });
  }
};
