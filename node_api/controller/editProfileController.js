/*PATH: /node_api/controller/editProfileController.js*/

const bcrypt = require('bcryptjs');
const db = require('../db');
const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");

// 👇 create S3 *and use the same variable name later*
const s3 = new S3Client({
  region: "auto",
  endpoint: process.env.R2_S3_ENDPOINT,
  credentials: {
    accessKeyId: process.env.R2_ACCESS_KEY,
    secretAccessKey: process.env.R2_SECRET_KEY,
  },
  forcePathStyle: true, // ✅ important for R2
});

const SALT_ROUNDS = 12;
const BUCKET = process.env.R2_BUCKET_EMPLOYEE_PROFILE || '';
const PUBLIC_URL = process.env.R2_PUBLIC_URL_PROFILE || '';

// Normalize db.query result to a plain array of rows
async function q(sql, params) {
  const r = await db.query(sql, params);
  if (Array.isArray(r)) return r;
  if (r && Array.isArray(r.rows)) return r.rows;
  return [];
}

async function getEmployeeById(id) {
  const rows = await q(
    `SELECT id, em_id, email, employee_name, dp_id AS department_id, password
       FROM employee
      WHERE id = $1`,
    [id]
  );
  return rows[0] || null;
}

exports.updateProfile = async (req, res) => {
  const employeeId = req.employee?.id || req.user?.id;
  if (!employeeId) return res.status(401).json({ message: 'Unauthenticated' });

  const { employee_name, email, department_id } = req.body;

  try {
    const sets = [];
    const vals = [];
    let i = 1;

    if (employee_name != null) { sets.push(`employee_name = $${i++}`); vals.push(employee_name); }
    if (email != null)         { sets.push(`email = $${i++}`);         vals.push(email); }
    if (department_id != null) { sets.push(`dp_id = $${i++}`);          vals.push(department_id); }

    if (sets.length) {
      vals.push(employeeId);
      await db.query(`UPDATE employee SET ${sets.join(', ')} WHERE id = $${i}`, vals);
    }

    // ---- OPTIONAL AVATAR UPLOAD ----
    if (req.file && BUCKET) {
      const ext = (req.file.originalname.split('.').pop() || 'bin').toLowerCase();
      const key = `employee/${employeeId}/${Date.now()}.${ext}`;

      // 👇 use the same var: s3.send(...)
      await s3.send(new PutObjectCommand({
        Bucket: BUCKET,
        Key: key,
        Body: req.file.buffer,
        ContentType: req.file.mimetype || 'application/octet-stream',
      }));

      const publicUrl = PUBLIC_URL ? `${PUBLIC_URL}/${key}` : key;

      await db.query(
        `INSERT INTO employee_images
           (employee_id, file_name, file_type, file_size_bytes, file_url, created_at)
         VALUES ($1, $2, $3, $4, $5, NOW())`,
        [
          employeeId,
          req.file.originalname,
          req.file.mimetype || 'application/octet-stream',
          Number(req.file.size || 0),
          publicUrl,
        ]
      );
    }

    // ---- RETURN FRESH ROW ----
    const rows = await q(
      `SELECT
         e.id,
         e.employee_name,
         e.email,
         e.dp_id AS department_id,
         e.em_id,
         i.file_url AS profile_image_url
       FROM employee e
       LEFT JOIN LATERAL (
         SELECT file_url
         FROM employee_images ei
         WHERE ei.employee_id = e.id
         ORDER BY ei.created_at DESC, ei.id DESC
         LIMIT 1
       ) AS i ON TRUE
       WHERE e.id = $1`,
      [employeeId]
    );
    if (!rows[0]) return res.status(404).json({ message: 'User not found after update' });

    res.set('Cache-Control', 'no-store'); // ✅ discourage caching
    return res.json(rows[0]);
  } catch (err) {
    console.error('updateProfile error:', err);
    return res.status(400).json({ message: 'Failed to update profile' });
  }
};

exports.changePassword = async (req, res) => {
  const employeeId = req.employee?.id || req.user?.id;
  if (!employeeId) return res.status(401).json({ message: 'Unauthenticated' });

  const { current_password, new_password } = req.body;
  if (!current_password || !new_password) {
    return res.status(400).json({ message: 'current_password and new_password are required' });
  }

  try {
    const me = await getEmployeeById(employeeId);
    if (!me) return res.status(404).json({ message: 'User not found' });

    const ok = await bcrypt.compare(current_password, me.password);
    if (!ok) return res.status(401).json({ message: 'Current password is incorrect' });

    const hash = await bcrypt.hash(new_password, SALT_ROUNDS);
    await db.query(`UPDATE employee SET password = $1 WHERE id = $2`, [hash, employeeId]);

    return res.status(200).json({ message: 'Password updated' });
  } catch (err) {
    console.error('changePassword error:', err);
    return res.status(400).json({ message: 'Failed to change password' });
  }
};
