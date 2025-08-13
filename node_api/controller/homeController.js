const db = require('../db');

exports.overview = async (req, res) => {
    const employeeId = req.employee?.id;
    if (!employeeId) return res.status(401).json({ error: 'Not Authentication' });

    try{
        const uploadedByMe = await db.any(
            `
                SELECT d.id, d.title, d.description, d.status, d.created_at, d.updated_at, dt.title as document_type_title
                FROM documents d
                LEFT JOIN document_types dt ON dt.id = d.document_type_id
                WHERE d.uploader_id = $1
                ORDER BY d.created_at DESC
            `, [employeeId]
        );

        const assignedToMe = await db.any(
            `
                SELECT DISTINCT d.id, d.title, d.description, d.status, d.created_at, d.updated_at, ds.sequence, ds.status AS step_status, ds.step_action, dt.title AS document_type_title
                FROM documents d
                JOIN document_steps ds ON ds.document_id = d.id
                LEFT JOIN document_types dt ON dt.id = d.document_type_id
                WHERE ds.employee_id = $1
                ORDER BY d.updated_at DESC, ds.sequence ASC
            `, [employeeId]
        );
        res.json({ uploadedByMe, assignedToMe});
    }
    catch (e){
        console.error(e);
        res.status(500).json({ error: 'Internal server error' });
    }
};