const db = require('../db');

exports.create = async (req, res) => {
  const { doc_title, doc_desc } = req.body;
  if (!doc_title || !doc_desc) {
    return res.status(400).json({ error: 'Missing fields' });
  }
  try {
    const result = await db.one(
      'INSERT INTO doctype (name, description) VALUES ($1, $2) RETURNING id',
      [doc_title, doc_desc]
    );
    res.status(201).json({ message: 'Document type created', id: result.id });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Server error' });
  }
};

exports.list = async (req, res) => {
  try {
    const rows = await db.any('SELECT * FROM doctype');
    res.json(rows);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Error fetching document types' });
  }
};

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
