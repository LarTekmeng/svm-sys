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