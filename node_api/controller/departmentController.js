/* This is Controller*/

const db = require('../db');

exports.all = async (req, res) => {
    try{
        const rows = await db.any('SELECT * FROM department');
        res.json(rows);
    }
    catch (e){
        console.error(e);
        res.status(500).json({ error: 'Error fetching Department' });
    }
}

exports.create = async (req, res) => {
  try {
    const { name } = req.body || {};
    const trimmed = (name || '').trim();

    // basic validation
    if (!trimmed) return res.status(400).json({ error: 'name is required' });
    if (trimmed.length > 100) {
      return res.status(400).json({ error: 'name must be <= 100 characters' });
    }

    // optional: enforce uniqueness at app level (DB has no unique constraint)
    const exists = await db.oneOrNone('SELECT id FROM department WHERE LOWER(name)=LOWER($1)', [trimmed]);
    if (exists) return res.status(409).json({ error: 'Department name already exists' });

    const inserted = await db.one(
      'INSERT INTO department (name) VALUES ($1) RETURNING id, name',
      [trimmed]
    );
    res.status(201).json(inserted);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Error creating department' });
  }
};