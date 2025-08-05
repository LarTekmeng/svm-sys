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
    const docTypeId = parseInt(req.params.id, 10);
    const ownerId = req.employee?.id;
    const {action, forward_mode, flows} = req.body;
    if(!ownerId) return res.status(401).json({error: 'Not Authenticated'});

    const sql1 = `SELECT owner_id FROM document_types WHERE id = $1`;

    const row = await db.oneOrNone(
        sql1,
        [docTypeId]
    );

    if(!row) return res.status(404).json({error: 'Not found'});
    if(row.owner_id != ownerId) return res.status(403).json({error: 'Forbidden to Update'});

    const updateSetting =
        `UPDATE document_type_settings SET action = $1, forward_mode = $2, updated_at = NOW() WHERE document_type_id = $3`;
    const deleteFlow =
        `DELETE FROM document_type_flows WHERE document_type_id = $1`;
    const updateFlow =
        `INSERT INTO document_type_flows (document_type_id, sequence, department_id, employee_id, step_action) VALUES ($1, $2, $3, $4, $5)`;
    try{
        await db.tx(async t => {
            await t.none(
                updateSetting,
                [action, forward_mode, docTypeId]
            );

            await t.none(
                deleteFlow,
                [docTypeId]
            );

            for( const f of flows ) {
                await t.none(
                    updateFlow,
                    [docTypeId, f.sequence, f.department_id, f.employee_id, f.step_action]
                );
            }
        });
        res.json({message : 'Flow updated'})
    }
    catch (e){
        console.error(e);
        res.status(500).json({error : 'Server error'});
    }
}


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