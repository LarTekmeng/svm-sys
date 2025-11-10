const db = require('../db');

exports.list = async(req, res) => {
    try{
        const row = await db.any(
            'SELECT id ,code FROM role'
        );
        res.json(row);
    }
    catch (e){
        console.error(e);
        res.status(500).json({ error : 'Error fetching Role' });
    }
}