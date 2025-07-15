const db = require('../db');

/* Create New Document Type */
exports.create = async (req, res) => {
    const { doc_title, doc_desc } = req.body;
    const em_id = req.employee?.em_id;
    if (!doc_title || !doc_desc) {
        return res.status(400).json({ error: 'Missing fields or authentication' });
    }
    try {
        const result = await db.one(
        'INSERT INTO doctype (name, description, em_id) VALUES ($1, $2, $3) RETURNING id',
        [doc_title, doc_desc, em_id]
        );
        res.status(201).json({ message: 'Document type created', id: result.id });
    } catch (e) {
        console.error(e);
        res.status(500).json({ error: 'Server error' });
    }
};

/* List all Document Type */
exports.list = async (req, res) => {
  try {
    const rows = await db.any('SELECT * FROM doctype');
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
      'DELETE FROM doctype WHERE id = $1',
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
  const { id } = req.params;
  const { doc_title, doc_desc } = req.body;

  if (!doc_title || !doc_desc) {
    return res.status(400).json({ error: 'Missing fields' });
  }

  try {
    const result = await db.result(
      'UPDATE doctype SET name = $1, description = $2 WHERE id = $3',
      [doc_title, doc_desc, id]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Document type not found' });
    }

    res.status(200).json({
      message: 'Document type updated',
      id: Number(id),
    });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Server error' });
  }
};

/* List document type by em_id */
exports.getId = async (req, res) => {
    const em_id = req.employee?.em_id;
    if (!em_id) return res.status(401).json({ error:'Not Authenticated' });
    try{
        const rows = await db.any(
            'SELECT id, name, description FROM doctype WHERE em_id = $1',
            [em_id]
        );
        res.json(rows);
    }
    catch (e){
        console.error(e);
        res.status(500).json({ error: 'Error fetching document types' });
    }
};