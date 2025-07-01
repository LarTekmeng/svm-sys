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

// GET /employees/:id
exports.getByEmployeeId = async (req, res) => {
  const { employeeId } = req.params;

  try {
    const employee = await db.oneOrNone(
      `SELECT
         e.employee_name,
         e.email,
         e.dp_id,
         e.em_id,
         d.name AS dp_name,
         f.file_url
       FROM employee e
       LEFT JOIN department d ON e.dp_id = d.id
       LEFT JOIN file_upload f ON e.id = f.employee_id
       WHERE e.em_id = $1`,
      [employeeId]
    );

    if (!employee) {
      // return so we never fall through to another res.* call
      return res.status(404).json({ error: 'Employee not found' });
    }

    // only one response for the successful path
    return res.json( employee );

  } catch (err) {
    console.error(err);
    // headersSent check is handled by Express if you have an error‐handler later
    return res.status(500).json({ error: 'Server error' });
  }
};

