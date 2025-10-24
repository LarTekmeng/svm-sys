// controller/homeController.js
const db = require('../db');

exports.overview = async (req, res) => {
  const user = req.user || req.employee;
  if (!user?.id) return res.status(401).json({ error: 'Not Authentication' });

  const admin = user.role === 'ADMIN';

  try {
    const uploadedByMe = await db.any(`
      SELECT d.id, d.title, d.description, d.status, d.created_at, d.updated_at,
             dt.title AS document_type_title
      FROM documents d
      LEFT JOIN document_types dt ON dt.id = d.document_type_id
      WHERE d.uploader_id = $1
      ORDER BY d.created_at DESC
    `, [user.id]);

    const assignedTo = await db.any(`
      WITH assigned AS (
        SELECT DISTINCT
          d.id, d.title, d.description, d.status, d.created_at, d.updated_at,
          dt.title AS document_type_title,
          ds.id       AS step_id,
          ds.sequence AS sequence,
          ds.status   AS step_status,
          ds.step_action,
          'ASSIGNED'::text AS inbox_type,
          (ds.status = 'PENDING' AND ds.employee_id = $1) AS can_act
        FROM documents d
        JOIN document_steps ds ON ds.document_id = d.id
        LEFT JOIN document_types dt ON dt.id = d.document_type_id
        ${admin ? '' : 'WHERE ds.employee_id = $1'}
      ),
      shared AS (
        SELECT DISTINCT
          d.id, d.title, d.description, d.status, d.created_at, d.updated_at,
          dt.title AS document_type_title,
          NULL::int  AS step_id,
          NULL::int  AS sequence,
          NULL::text AS step_status,
          NULL::text AS step_action,
          'SHARED'::text AS inbox_type,
          FALSE AS can_act
        FROM documents d
        JOIN document_type_settings s ON s.document_type_id = d.document_type_id
        JOIN document_type_flows f    ON f.document_type_id = d.document_type_id
        LEFT JOIN document_types dt   ON dt.id = d.document_type_id
        WHERE s.action = 'Read-Only'
          ${admin ? '' : 'AND f.employee_id = $1 AND d.uploader_id <> $1'}
          AND NOT EXISTS (
            SELECT 1 FROM document_steps x
            WHERE x.document_id = d.id
            ${admin ? '' : 'AND x.employee_id = $1'}
          )
      )
      SELECT * FROM assigned
      UNION ALL
      SELECT * FROM shared
      ORDER BY created_at DESC, updated_at DESC
    `, [user.id]); // user.id passed so can_act can be computed for Admin too

    const shareToMe = admin ? [] : await db.any(`
      SELECT DISTINCT d.id, d.title, d.description, d.status, d.created_at, d.updated_at,
             dt.title AS document_type_title
      FROM documents d
      JOIN document_type_settings s ON s.document_type_id = d.document_type_id
      JOIN document_type_flows f ON f.document_type_id = d.document_type_id
      LEFT JOIN document_types dt ON dt.id = d.document_type_id
      WHERE s.action = 'Read-Only'
        AND f.employee_id = $1
        AND d.uploader_id <> $1
      ORDER BY d.created_at DESC
    `, [user.id]);

    res.json({ uploadedByMe, assignedToMe: assignedTo, shareToMe });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Internal server error' });
  }
};
