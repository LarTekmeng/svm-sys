/*PATH: /node_api/controller/employeeController.js*/
const db = require('../db');

// GET /employees
exports.list = async (req, res) => {
  try {
    const rows = await db.any('SELECT * FROM employee');
    res.json(rows);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Error fetching employees' });
  }
};

// GET /employees/:employeeId   <-- make sure your route uses :employeeId
exports.getByEmployeeId = async (req, res) => {
  const { employeeId } = req.params;

  try {
    const sql = `
      SELECT
        e.id,
        e.employee_name,
        e.email,
        e.dp_id AS department_id,
        e.em_id,
        d.name AS department_name,
        i.file_url AS profile_image_url
      FROM employee e
      LEFT JOIN department d ON e.dp_id = d.id
      LEFT JOIN LATERAL (
        SELECT file_url
        FROM employee_images ei
        WHERE ei.employee_id = e.id
        ORDER BY ei.created_at DESC, ei.id DESC
        LIMIT 1
      ) AS i ON TRUE
      WHERE e.id = $1;

    `;

    const row = await db.oneOrNone(sql, [employeeId]);
    if (!row) return res.status(404).json({ error: 'Employee not found' });

    return res.json(row);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Server error' });
  }
};

// GET /employees/department/:departmentId
exports.getByDepartment = async (req, res) => {
  const { departmentId } = req.params;
  try {
    const rows = await db.any(
      'SELECT id, employee_name, dp_id FROM employee WHERE dp_id = $1',
      [departmentId]
    );
    res.json(rows);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Error fetching employee by department' });
  }
};
