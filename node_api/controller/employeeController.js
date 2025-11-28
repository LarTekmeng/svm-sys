/* PATH: /node_api/controller/employeeController.js */
'use strict';
const db = require('../db');
const multer = require('multer');
const bcrypt = require('bcrypt');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const path = require('path');

// Configure S3 client for R2
const s3 = new S3Client({
  region: 'auto',
  endpoint: process.env.R2_S3_ENDPOINT,
  credentials: {
    accessKeyId: process.env.R2_ACCESS_KEY,
    secretAccessKey: process.env.R2_SECRET_KEY,
  },
});

const ALLOWED_IMAGE_EXT = new Set([
  '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.svg'
]);

const extOf = (filename) => {
  return path.extname(filename || '').toLowerCase();
};

// New multer config – ONLY check extension, NOT mimetype
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 5 * 1024 * 1024, // 5MB
  },
  fileFilter: (req, file, cb) => {
    const ext = extOf(file.originalname);
    if (ALLOWED_IMAGE_EXT.has(ext)) {
      cb(null, true);
    } else {
      cb(new Error(`File type not allowed: ${ext || '(no extension)'}`), false);
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
 *  Accepts either:
 *   - em_id (string) → e.g. "E010", "admin123"
 *   - numeric id (as string in URL) → e.g. "7"
 */
exports.getByEmployeeId = async (req, res) => {
  const { employeeId } = req.params; // always string from URL

  try {
    let row;

    // Case 1: Pure number → treat as primary key (id)
    if (/^\d+$/.test(employeeId)) {
      const numericId = parseInt(employeeId, 10);
      row = await db.oneOrNone(
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
        ) i ON TRUE
        WHERE e.id = $1
        LIMIT 1
        `,
        [numericId]
      );
    }
    // Case 2: Not a pure number → treat as em_id (string)
    else {
      row = await db.oneOrNone(
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
        ) i ON TRUE
        WHERE e.em_id = $1
        LIMIT 1
        `,
        [employeeId]
      );
    }

    if (!row) {
      return res.status(404).json({ error: 'Employee not found' });
    }

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
    res.status(500).json({ error: 'Server error' });
  }
};

/* =======================================================
   UPDATE EMPLOYEE
   - Allows updating name, email, password (optional), dept, em_id, role (optional)
   - Also supports uploading new profile image (replaces latest)
   ======================================================= */
exports.update = [
  upload.single('profile_image'), // single file named 'profile_image'
  async (req, res) => {
    const { id } = req.params;
    const {
      employee_name,
      email,
      password,
      dp_id,
      em_id,
      role_id,
    } = req.body;

    try {
      await db.tx(async (t) => {
        // 1) Check if employee exists
        const existing = await t.oneOrNone(
          'SELECT id FROM employee WHERE id = $1',
          [id]
        );
        if (!existing) {
          throw Object.assign(new Error('Employee not found'), { http: 404 });
        }

        // 2) Validate required fields
        if (
          !employee_name?.trim() ||
          !email?.trim() ||
          !dp_id ||
          !em_id?.trim()
        ) {
          throw Object.assign(new Error('Missing required fields'), {
            http: 400,
          });
        }

        // 3) Check for unique email/em_id (exclude self)
        const dup = await t.oneOrNone(
          `SELECT id FROM employee
           WHERE (email = $1 OR em_id = $2) AND id <> $3`,
          [email.trim(), em_id.trim(), id]
        );
        if (dup) {
          throw Object.assign(new Error('Email or Employee ID already in use'), {
            http: 409,
          });
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
          const ext = extOf(f.originalname);
          if (!ALLOWED_IMAGE_EXT.has(ext)) {
            throw new Error(`Invalid image extension: ${ext || '(no extension)'}`);
          }

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
    let deletedName = 'Unknown';

    await db.tx(async (t) => {
      const existing = await t.oneOrNone(
        'SELECT id, employee_name FROM employee WHERE id = $1',
        [id]
      );
      if (!existing) {
        throw Object.assign(new Error('Employee not found'), { http: 404 });
      }
      deletedName = existing.employee_name;

      await t.none('DELETE FROM employee_images WHERE employee_id = $1', [id]);
      await t.none('DELETE FROM employee WHERE id = $1', [id]);
      // Do NOT send response here!
    });

    // ← Only send response AFTER transaction successfully committed
    return res.status(200).json({
      message: `Employee ${deletedName} deleted successfully`,
    });

    console.log(`Employee ${deletedName} (id=${id}) deleted successfully`);
  } catch (e) {
    if (e.http) return res.status(e.http).json({ error: e.message });
    console.error('Delete employee error:', e);
    return res.status(500).json({ error: 'Failed to delete employee' });
  }
};