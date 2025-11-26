/* PATH: /node_api/controller/employeeController.js */
'use strict';
const db = require('../db');
const multer = require('multer');
const bcrypt = require('bcrypt');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');

// Configure S3 client for R2
const s3 = new S3Client({
  region: 'auto',
  endpoint: process.env.R2_S3_ENDPOINT,
  credentials: {
    accessKeyId: process.env.R2_ACCESS_KEY,
    secretAccessKey: process.env.R2_SECRET_KEY,
  },
});

// Configure multer middleware for file uploads
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 5 * 1024 * 1024, // 5MB limit
  },
  fileFilter: (req, file, cb) => {
    // Accept only image files
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Only image files are allowed'), false);
    }
  },
});

// Upload function for R2
async function uploadToR2(key, body, contentType) {
  await s3.send(new PutObjectCommand({
    Bucket:      process.env.R2_BUCKET_EMPLOYEE_PROFILE,
    Key:         key,
    Body:        body,
    ContentType: contentType,
  }));
}

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

/** PUT /api/employees/:id - Update employee */
exports.update = [
  upload.single('profile_image'),
  async (req, res) => {
    const { id } = req.params;
    const { employee_name, email, password, dp_id, role_id } = req.body || {};

    if (!employee_name || !email || !dp_id) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    try {
      await db.tx(async (t) => {
        // 1) Check if employee exists
        const existing = await t.oneOrNone(
          'SELECT id, em_id FROM employee WHERE id = $1',
          [id]
        );
        if (!existing) {
          throw Object.assign(new Error('Employee not found'), { http: 404 });
        }

        // 2) Check for email duplication (excluding current employee)
        const emailDup = await t.oneOrNone(
          'SELECT id FROM employee WHERE email = $1 AND id != $2',
          [email, id]
        );
        if (emailDup) {
          throw Object.assign(new Error('Email already in use'), { http: 409 });
        }

        // 3) Validate department exists
        const deptExists = await t.oneOrNone(
          'SELECT id FROM department WHERE id = $1',
          [dp_id]
        );
        if (!deptExists) {
          throw Object.assign(new Error('Department not found'), { http: 400 });
        }

        // 4) Validate role if provided
        if (role_id) {
          const roleExists = await t.oneOrNone(
            'SELECT id FROM role WHERE id = $1',
            [role_id]
          );
          if (!roleExists) {
            throw Object.assign(new Error('Role not found'), { http: 400 });
          }
        }

        // 5) Prepare update data
        const updateData = {
          employee_name,
          email,
          dp_id: parseInt(dp_id, 10),
        };

        // Add role_id if provided
        if (role_id) {
          updateData.role_id = parseInt(role_id, 10);
        }

        // 6) Hash password if provided
        if (password && password.trim() !== '') {
          updateData.password = await bcrypt.hash(password, 10);
        }

        // 7) Build dynamic UPDATE query
        const fields = Object.keys(updateData);
        const setClause = fields.map((f, i) => `${f} = $${i + 1}`).join(', ');
        const values = fields.map(f => updateData[f]);
        values.push(id); // Add id for WHERE clause

        const updated = await t.one(
          `UPDATE employee
           SET ${setClause}
           WHERE id = $${values.length}
           RETURNING id, employee_name, email, dp_id, em_id, role_id`,
          values
        );

        // 8) Handle profile image upload if provided
        if (req.file) {
          const f = req.file;
          const ts = Date.now();
          const key = `employees/${id}/${ts}-${f.originalname}`;
          await uploadToR2(key, f.buffer, f.mimetype);
          const fileUrl = `${(process.env.R2_PUBLIC_URL_PROFILE || '').replace(/\/+$/, '')}/${key}`;

          // Insert new image record
          await t.none(
            `INSERT INTO employee_images (employee_id, file_name, file_type, file_size_bytes, file_url)
             VALUES ($1, $2, $3, $4, $5)`,
            [id, f.originalname, f.mimetype, f.size, fileUrl]
          );
        }

        res.json({
          message: 'Employee updated successfully',
          employee: updated,
        });
      });
    } catch (e) {
      if (e.http) return res.status(e.http).json({ error: e.message });
      console.error('Update employee error:', e);
      res.status(500).json({ error: 'Server error' });
    }
  },
];

/* =======================================================
   DELETE EMPLOYEE
   - Deletes employee and related records (images, etc.)
   ======================================================= */
exports.delete = async (req, res) => {
  const { id } = req.params;

  try {
    await db.tx(async (t) => {
      // 1) Check if employee exists
      const existing = await t.oneOrNone(
        'SELECT id, employee_name FROM employee WHERE id = $1',
        [id]
      );
      if (!existing) {
        throw Object.assign(new Error('Employee not found'), { http: 404 });
      }

      // 2) Delete related records first (cascade)
      // Delete employee images
      await t.none('DELETE FROM employee_images WHERE employee_id = $1', [id]);

      // Add other related deletes as needed
      // await t.none('DELETE FROM employee_documents WHERE employee_id = $1', [id]);
      // await t.none('DELETE FROM employee_attendance WHERE employee_id = $1', [id]);

      // 3) Delete the employee
      await t.none('DELETE FROM employee WHERE id = $1', [id]);

      res.status(200).json({
        message: `Employee ${existing.employee_name} deleted successfully`,
      });
    });
  } catch (e) {
    if (e.http) return res.status(e.http).json({ error: e.message });
    console.error('Delete employee error:', e);
    res.status(500).json({ error: 'Server error' });
  }
};