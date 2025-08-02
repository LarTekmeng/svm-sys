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
    // 2) Use a transaction so settings only get seeded if the type is created
    const newId = await db.tx(async t => {
      const { id } = await t.one(
        `INSERT INTO document_types
           (title, description, owner_id)
         VALUES ($1, $2, $3)
         RETURNING id`,
        [ title.trim(), description.trim(), ownerId ]
      );

      await t.none(
        `INSERT INTO document_type_settings
           (document_type_id, action, forward_mode)
         VALUES ($1, 'Read-Only', 'Direct')`,
        [ id ]
      );

      return id;
    });

    // 3) Success
    return res
      .status(201)
      .json({ message: 'Document type created', id: newId });

  } catch (err) {
    console.error('Error creating document type:', err);
    return res.status(500).json({ error: 'Server error' });
  }
};


/* List all Document Type */
exports.list = async (req, res) => {
  try {
    const rows = await db.any('SELECT id, title, description FROM document_types');
    res.json(rows);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Error fetching document types' });
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

  try {
    // 2) Fetch owner
    const row = await db.oneOrNone(
      `SELECT owner_id
         FROM document_types
        WHERE id = $1`,
      [docTypeId]
    );

    if (!row) {
      return res.status(404).json({ error: 'Document type not found' });
    }

    // 3) Authorization check
    if (row.owner_id !== currentUser) {
      return res.status(403).json({ error: 'Not allowed to update this document type' });
    }

    // 4) Perform the update
    const result = await db.result(
      `UPDATE document_types
          SET title       = $1,
              description = $2,
              update_at  = NOW()
        WHERE id = $3`,
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