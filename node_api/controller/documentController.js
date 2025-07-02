const db = require('../db');

// GET /documents
exports.list = async (req, res) => {
  const sql = 'SELECT * FROM document';
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
  const { doctype_id, doc_title, doc_desc } = req.body;

  // ✅ Improved validation: also handles empty strings
  if (!doctype_id || !doc_title?.trim() || !doc_desc?.trim()) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  try {
    const result = await db.one(
      `INSERT INTO document (doctype_id, doc_title, doc_desc)
       VALUES ($1, $2, $3)
       RETURNING id`,
      [doctype_id, doc_title.trim(), doc_desc.trim()]
    );

    res.status(201).json({
      message: 'Document created',
      document: {
        id: result.id,
        doctype_id,
        doc_title: doc_title.trim(),
        doc_desc: doc_desc.trim()
      }
    });
  } catch (err) {
    console.error('Error creating document:', err);
    res.status(500).json({ error: 'Error creating document' });
  }
};

// Placeholder for future method
exports.add = async (req, res) => {
  res.status(501).json({ message: 'Not implemented yet' });
};
