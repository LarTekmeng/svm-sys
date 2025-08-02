const db = require('../db');

// GET /documents
exports.list = async (req, res) => {
  const sql = `
    SELECT
      d.id,
      d.title,
      d.description,
      d.status,
      dt.title AS document_type,
      e.employee_name AS uploader
    FROM documents d
    JOIN document_types dt ON d.document_type_id = dt.id
    JOIN employee e       ON d.uploader_id       = e.id
  `;

  try {
    const rows = await db.any(sql);
    return res.json(rows);
  } catch (e) {
    console.error('Error fetching documents:', e);
    return res.status(500).json({ error: 'Error fetching documents' });
  }
};

// POST /documents
exports.create = async (req, res) => {
  const { document_type_id, title, description } = req.body;

  // ✅ Handles missing / empty strings
  if (
    !document_type_id ||
    typeof title       !== 'string' || !title.trim() ||
    typeof description !== 'string' || !description.trim()
  ) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  const sql = `
    INSERT INTO documents
      (document_type_id, uploader_id, title, description)
    VALUES ($1, $2, $3, $4)
    RETURNING id;
  `;

  try {
    const { id } = await db.one(
      sql,
      [document_type_id, req.employee.id, title.trim(), description.trim()]
    );

    return res.status(201).json({
      message: 'Document created',
      document: {
        id,
        document_type_id,
        title:       title.trim(),
        description: description.trim()
      }
    });
  } catch (err) {
    console.error('Error creating document:', err);
    return res.status(500).json({ error: 'Error creating document' });
  }
};

// Placeholder for future method
exports.add = async (req, res) => {
  return res.status(501).json({ message: 'Not implemented yet' });
};
