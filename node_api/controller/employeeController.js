/* PATH: /node_api/controller/employeeController.js */
'use strict';
const db = require('../db');

/** GET /api/employees */
exports.list = async (_req, res) => {
  try {
    const rows = await db.any(`
      SELECT
        e.id,
        e.employee_name,
        e.email,
        e.dp_id                                    AS department_id,
        e.em_id,
        d.name                                     AS department_name,      -- matches schema
        COALESCE(i.file_url, '')                   AS profile_image_url,    -- no e.profile_image_url in table
        e.role_id,
        r.code                                     AS role_code             -- role has only (id, code)
      FROM employee e
      LEFT JOIN department d ON d.id = e.dp_id
      LEFT JOIN role r       ON r.id = e.role_id
      LEFT JOIN LATERAL (
        SELECT file_url
        FROM employee_images ei
        WHERE ei.employee_id = e.id
        ORDER BY ei.created_at DESC, ei.id DESC
        LIMIT 1
      ) AS i ON TRUE
      ORDER BY e.id DESC
    `);
    res.json(rows);
  } catch (e) {
    console.error('GET /api/employees error:', e);
    res.status(500).json({ error: 'Error fetching employees' });
  }
};

/** GET /api/employees/:employeeId
 * Accepts either em_id (string) or numeric e.id
 */
exports.getByEmployeeId = async (req, res) => {
  const { employeeId } = req.params;
  try {
    const row = await db.oneOrNone(
      `
      SELECT
        e.id,
        e.employee_name,
        e.email,
        e.dp_id                                    AS department_id,
        e.em_id,
        d.name                                     AS department_name,
        COALESCE(i.file_url, '')                   AS profile_image_url,
        e.role_id,
        r.code                                     AS role_code
      FROM employee e
      LEFT JOIN department d ON d.id = e.dp_id
      LEFT JOIN role r       ON r.id = e.role_id
      LEFT JOIN LATERAL (
        SELECT file_url
        FROM employee_images ei
        WHERE ei.employee_id = e.id
        ORDER BY ei.created_at DESC, ei.id DESC
        LIMIT 1
      ) AS i ON TRUE
      WHERE
        e.em_id = $1
        OR ($1 ~ '^\\d+$' AND e.id = ($1)::int)
      LIMIT 1
    `,
      [employeeId]
    );

    if (!row) return res.status(404).json({ error: 'Employee not found' });
    res.json(row);
  } catch (e) {
    console.error('GET /api/employees/:employeeId error:', e);
    res.status(500).json({ error: 'Server error' });
  }
};

/** GET /api/employees/department/:departmentId */
exports.getByDepartment = async (req, res) => {
  const { departmentId } = req.params;
  try {
    const rows = await db.any(
      `
      SELECT
        e.id,
        e.employee_name,
        e.email,
        e.dp_id                                    AS department_id,
        e.em_id,
        d.name                                     AS department_name,
        COALESCE(i.file_url, '')                   AS profile_image_url,
        e.role_id,
        r.code                                     AS role_code
      FROM employee e
      LEFT JOIN department d ON d.id = e.dp_id
      LEFT JOIN role r       ON r.id = e.role_id
      LEFT JOIN LATERAL (
        SELECT file_url
        FROM employee_images ei
        WHERE ei.employee_id = e.id
        ORDER BY ei.created_at DESC, ei.id DESC
        LIMIT 1
      ) AS i ON TRUE
      WHERE e.dp_id = $1
      ORDER BY e.id DESC
    `,
      [departmentId]
    );
    res.json(rows);
  } catch (e) {
    console.error('GET /api/employees/department/:departmentId error:', e);
    res.status(500).json({ error: 'Error fetching employee by department' });
  }
};
