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

exports.update = async (req, res) => {
    try{
        const { id } = req.params;
        const { name } = req.body || {};
        const trimmed = (name || '').trim();

        if (!trimmed) return res.status(400).json({ error: 'name is required' });
        if (trimmed.length > 100) {
            return res.status(400).json({ error: 'name must be <= 100 characters' });
        }
        const existing = await db.oneOrNone('SELECT id FROM department WHERE id=$1', [id]);
        if (!existing) return res.status(404).json({ error: 'Department not found' });

        const duplicate = await db.oneOrNone(
            'SELECT id FROM department WHERE LOWER(name)=LOWER($1) AND id !=$2',
            [trimmed, id]
        );

        if (duplicate) return res.status(409).json({ error: 'Department name already exists' });
        const updated = await db.one(
            'UPDATE department SET name=$1 WHERE id=$2 RETURNING id, name',
            [trimmed, id]
        );
        res.json(updated);
    } catch(e){
        console.error(e);
        res.status(500).json({ error: 'Error updating department'});
    }

};

exports.delete = async (req, res) => {
    try{
        const { id } = req.params;

        const existing = await db.oneOrNone('SELECT id FROM department WHERE id=$1', [id]);
        if (!existing) return res.status(404).json({ error: 'Department not found'});

        await db.none('DELETE FROM department WHERE id=$1', [id]);
        res.status(204).send();
    }
    catch(e){
        console.error(e);
        res.status(500).json({ error: 'Error deleting department' });
    }
};