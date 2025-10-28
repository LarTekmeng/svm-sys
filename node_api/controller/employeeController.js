/* PATH: /node_api/controller/employeeController.js */
'use strict';
const db = require('../db');

/**
 * GET /api/employees
 * Returns employees shaped for the Flutter Employee model + role fields.
 */
exports.list = async (_req, res) => {
  try {
    const rows = await db.any(`
      SELECT
        e.id,
        e.employee_name,
        e.email,
        e.dp_id                                    AS department_id,
        e.em_id,
        d.name AS department_name,
        COALESCE(i.file_url, e.profile_image_url)  AS profile_image_url,
        e.role_id,
        r.code                                     AS role_code,
        r.name                                     AS role_name
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

/**
 * GET /api/employees/:employeeId
 * Supports BOTH:
 *  - numeric id   (e.id = :employeeId)
 *  - string em_id (e.em_id = :employeeId)
 */
exports.getByEmployeeId = async (req, res) => {
  const { employeeId } = req.params;
  try {
    const isNumeric = /^\d+$/.test(String(employeeId));
    const row = await db.oneOrNone(
      `
      SELECT
        e.id,
        e.employee_name,
        e.email,
        e.dp_id                                    AS department_id,
        e.em_id,
        d.name AS department_name,
        COALESCE(i.file_url, e.profile_image_url)  AS profile_image_url,
        e.role_id,
        r.code                                     AS role_code,
        r.name                                     AS role_name
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
      WHERE ${isNumeric ? 'e.id' : 'e.em_id'} = $1
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

/**
 * GET /api/employees/department/:departmentId
 */
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
        d.name AS department_name,
        COALESCE(i.file_url, e.profile_image_url)  AS profile_image_url,
        e.role_id,
        r.code                                     AS role_code,
        r.name                                     AS role_name
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
