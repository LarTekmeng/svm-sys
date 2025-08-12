const db = require('../db');

/* Create New Document Type */
exports.create = async (req, res) => {
  const { title, description } = req.body;
  const ownerId = req.employee?.id;

  // 1) Validate inputs + authentication
  if (
    !ownerId ||
    typeof title       !== 'string' || !title.trim() ||
    typeof description !== 'string' || !description.trim()
  ) {
    return res
      .status(400)
      .json({ error: 'Missing title/description or not authenticated' });
  }

  try {
      const addDocumentType =
        `INSERT INTO document_types (title, description, owner_id, created_at) VALUES ($1, $2, $3, NOW()) RETURNING id`;

      const result = await db.one(
        addDocumentType, [title, description, ownerId]
      );

      const addDocumentTypeSetting =
        `INSERT INTO document_type_settings (document_type_id, action, forward_mode, created_at) VALUES ($1, 'Read-Only', 'Direct', NOW())`;

      await db.none(
        addDocumentTypeSetting,
        [ result.id ]
      );

    // 3) Success
    return res
      .status(201)
      .json({ message: 'Document type created', id: result.id });

  } catch (err) {
    console.error('Error creating document type:', err);
    return res.status(500).json({ error: 'Server error' });
  }
};

/* Delete Document Type*/
exports.delete = async (req, res) => {
  const { id } = req.params;
  try {
    const result = await db.result(
      'DELETE FROM document_types WHERE id = $1',
      [id]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Document type not found' });
    }

    res.status(200).json({
      message: 'Document type deleted',
      id: Number(id),
    });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Server error' });
  }
};

/* Update Document Type */
exports.update = async (req, res) => {
  const docTypeId = parseInt(req.params.id, 10);
  const { title, description } = req.body;
  const currentUser = req.employee?.id;

  // 1) Basic validation
  if (
    !currentUser ||
    typeof title       !== 'string' || !title.trim() ||
    typeof description !== 'string' || !description.trim()
  ) {
    return res.status(400).json({ error: 'Missing fields or not authenticated' });
  }

  const getOwnerId =
    `SELECT owner_id FROM document_types WHERE id = $1`;

  try {
    // 2) Fetch owner
    const row = await db.oneOrNone(
      getOwnerId,
      [docTypeId]
    );

    if (!row) {
      return res.status(404).json({ error: 'Document type not found' });
    }

    // 3) Authorization check
    if (row.owner_id !== currentUser) {
      return res.status(403).json({ error: 'Not allowed to update this document type' });
    }

    const updateDocumentType =
        `UPDATE document_types SET title = $1, description = $2, updated_at = NOW() WHERE id = $3`;
    // 4) Perform the update
    const result = await db.result(
      updateDocumentType,
      [ title.trim(), description.trim(), docTypeId ]
    );

    return res.json({
      message: 'Document type updated',
      id: docTypeId
    });
  } catch (err) {
    console.error('Error updating document type:', err);
    return res.status(500).json({ error: 'Server error' });
  }
};

exports.updateFlow = async (req, res) => {
  const docTypeId = parseInt(req.params.documentTypeId, 10);
  const ownerId   = req.employee?.id;
  const { action, forward_mode, flows } = req.body;

  if (!ownerId)
    return res.status(401).json({ error: 'Not Authenticated' });

  // 1) Ownership check
  const row = await db.oneOrNone(
    `SELECT owner_id FROM document_types WHERE id = $1`,
    [docTypeId]
  );
  if (!row)
    return res.status(404).json({ error: 'Not found' });
  if (row.owner_id !== ownerId)
    return res.status(403).json({ error: 'Forbidden to Update' });

  // 2) SQL templates
  const updateSettingSql = `
    UPDATE document_type_settings
       SET action      = $1,
           forward_mode = $2,
           updated_at   = NOW()
     WHERE document_type_id = $3
  `;
  const deleteFlowSql = `
    DELETE FROM document_type_flows
     WHERE document_type_id = $1
  `;
  const insertFlowSql = `
    INSERT INTO document_type_flows
      (document_type_id, sequence, department_id, employee_id, step_action)
    VALUES ($1, $2, $3, $4, $5)
  `;

  try {
    await db.tx(async t => {
      // A) Update the settings row
      await t.none(updateSettingSql, [action, forward_mode, docTypeId]);

      // B) Wipe out existing steps
      await t.none(deleteFlowSql, [docTypeId]);

      // C) Expand & insert each flow element
      for (const f of flows) {
        const deptAll = (f.department_id === 'all');
        const empAll  = (f.employee_id   === 'all');

        if (deptAll && empAll) {
          // → every employee in the company
          const everyone = await t.many(`
            SELECT id, dp_id FROM employee
          `);
          for (const emp of everyone) {
            await t.none(insertFlowSql, [
              docTypeId,
              f.sequence,
              emp.dp_id,
              emp.id,
              f.step_action
            ]);
          }

        } else if (deptAll) {
          // → single specific employee, but unknown department → fetch their dept
          const emp = await t.one(`
            SELECT id, dp_id
              FROM employee
             WHERE id = $1
          `, [f.employee_id]);
          await t.none(insertFlowSql, [
            docTypeId,
            f.sequence,
            emp.dp_id,
            emp.id,
            f.step_action
          ]);

        } else if (empAll) {
          // → every employee *within* a specific department
          const deptEmps = await t.many(`
            SELECT id
              FROM employee
             WHERE dp_id = $1
          `, [f.department_id]);
          for (const emp of deptEmps) {
            await t.none(insertFlowSql, [
              docTypeId,
              f.sequence,
              f.department_id,
              emp.id,
              f.step_action
            ]);
          }

        } else {
          // → one specific employee in one specific department
          await t.none(insertFlowSql, [
            docTypeId,
            f.sequence,
            f.department_id,
            f.employee_id,
            f.step_action
          ]);
        }
      }
    });

    return res.json({ message: 'Flow updated (wildcards expanded)' });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'Server error' });
  }
};



/* List document type by em_id */
exports.getId = async (req, res) => {
    const id = req.employee?.id;
    if (!id) return res.status(401).json({ error:'Not Authenticated' });
    try{
        const rows = await db.any(
                'SELECT id, title, description FROM document_types WHERE owner_id = $1',
            [id]
        );
        res.json(rows);
    }
    catch (e){
        console.error(e);
        res.status(500).json({ error: 'Error fetching document types' });
    }
};