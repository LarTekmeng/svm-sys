const db = require('../db');

exports.overview = async (req, res) => {
    const employeeId = req.employee?.id;
    if (!employeeId) return res.status(401).json({ error: 'Not Authentication' });

    try{
        const uploadedByMe = await db.any(
            `
                SELECT d.id, d.title, d.description, d.status, d.created_at, d.updated_at, dt.title
                AS document_type_title
                FROM documents d
                LEFT JOIN document_types dt ON dt.id = d.document_type_id
                WHERE d.uploader_id = $1
                ORDER BY d.created_at DESC
            `, [employeeId]
        );

        const assignedToMe = await db.any(
          `
          WITH assigned AS (
            SELECT DISTINCT
              d.id, d.title, d.description, d.status, d.created_at, d.updated_at,
              dt.title AS document_type_title,
              ds.sequence, ds.status AS step_status, ds.step_action,
              'ASSIGNED'::text AS inbox_type,
              TRUE AS requires_action
            FROM documents d
            JOIN document_steps ds ON ds.document_id = d.id
            LEFT JOIN document_types dt ON dt.id = d.document_type_id
            WHERE ds.employee_id = $1
            -- Optional: uncomment if you want only actionable steps
            -- AND ds.status = 'PENDING'
          ),
          shared AS (
            SELECT DISTINCT
              d.id, d.title, d.description, d.status, d.created_at, d.updated_at,
              dt.title AS document_type_title,
              NULL::int  AS sequence,
              NULL::text AS step_status,
              NULL::text AS step_action,
              'SHARED'::text AS inbox_type,
              FALSE AS requires_action
            FROM documents d
            JOIN document_type_settings s ON s.document_type_id = d.document_type_id
            JOIN document_type_flows f    ON f.document_type_id = d.document_type_id
                                         AND f.employee_id = $1
            LEFT JOIN document_types dt   ON dt.id = d.document_type_id
            WHERE s.action = 'Read-Only'
              AND d.uploader_id <> $1
              -- Safety: if a step was accidentally created for me, don’t duplicate
              AND NOT EXISTS (
                SELECT 1 FROM document_steps x
                WHERE x.document_id = d.id AND x.employee_id = $1
              )
          )
          SELECT * FROM assigned
          UNION ALL
          SELECT * FROM shared
          ORDER BY created_at DESC, updated_at DESC
          `,
          [employeeId]
        );

        const shareToMe = await db.any(
        `
            SELECT DISTINCT d.id, d.title, d.description, d.status, d.created_at, d.updated_at, dt.title AS document_type_title
            FROM documents d
            JOIN document_type_settings s ON s.document_type_id = d.document_type_id
            JOIN document_type_flows f ON f.document_type_id = d.document_type_id
            LEFT JOIN document_types dt ON dt.id = d.document_type_id
            WHERE s.action = 'Read-Only'
                AND f.employee_id = $1
                AND d.uploader_id <> $1
            ORDER BY d.created_at DESC
        `, [employeeId]
        );
        res.json({ uploadedByMe, assignedToMe, shareToMe });
    }
    catch (e){
        console.error(e);
        res.status(500).json({ error: 'Internal server error' });
    }
};