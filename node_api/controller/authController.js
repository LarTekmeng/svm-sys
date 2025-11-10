'use strict';

const bcrypt = require('bcrypt');
const jwt    = require('jsonwebtoken');
const db     = require('../db');
const multer = require('multer');
const upload = multer({ storage: multer.memoryStorage() });
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');

/* -------------------- S3 / R2 client -------------------- */
const s3 = new S3Client({
  region: 'auto',
  endpoint: process.env.R2_S3_ENDPOINT,
  credentials: {
    accessKeyId: process.env.R2_ACCESS_KEY,
    secretAccessKey: process.env.R2_SECRET_KEY,
  },
});

async function uploadToR2(key, body, contentType) {
  await s3.send(new PutObjectCommand({
    Bucket:      process.env.R2_BUCKET_EMPLOYEE_PROFILE,
    Key:         key,
    Body:        body,
    ContentType: contentType,
  }));
}

/* -------------------- Token helpers -------------------- */
const ACCESS_TTL_SHORT    = process.env.JWT_ACCESS_TTL_SHORT    || '15m';
const ACCESS_TTL_REMEMBER = process.env.JWT_ACCESS_TTL_REMEMBER || '1h';
const REFRESH_TTL_SHORT   = process.env.JWT_REFRESH_TTL_SHORT   || '30m';
const REFRESH_TTL_REMEMBER= process.env.JWT_REFRESH_TTL_REMEMBER|| '30d';

function normalizeRememberMe(v) {
  // Accept true/false, "true"/"false", 1/0, "1"/"0"
  if (typeof v === 'string') return v === 'true' || v === '1';
  return !!v;
}

function signAccessToken(payload, rememberMe) {
  const ttl = rememberMe ? ACCESS_TTL_REMEMBER : ACCESS_TTL_SHORT;
  return jwt.sign(payload, process.env.JWT_SECRET_ACCESS, { expiresIn: ttl });
}
function signRefreshToken(payload, rememberMe) {
  const ttl = rememberMe ? REFRESH_TTL_REMEMBER : REFRESH_TTL_SHORT;
  return jwt.sign(payload, process.env.JWT_SECRET_REFRESH, { expiresIn: ttl });
}

function buildEmployeeDto(row, role) {
  return {
    id:            row.id,
    employee_name: row.employee_name,
    email:         row.email,
    dp_id:         row.dp_id,
    em_id:         row.em_id,
    role,
  };
}

/* =======================================================
   REGISTER
   - Creates employee as EMPLOYEE by default (role_id)
   - Accepts optional profile image (R2)
   ======================================================= */
exports.register = [
  upload.single('profile_image'),
  async (req, res) => {
    const { employee_name, email, password, dp_id, em_id, role_id } = req.body || {};
    if (!employee_name || !email || !password || !dp_id || !em_id) {
      return res.status(400).json({ error: 'Missing fields' });
    }

    try {
      await db.tx(async (t) => {
        // 1) Duplicate checks
        const dup = await t.oneOrNone(
          `SELECT 'em_id' AS field FROM employee WHERE em_id = $1
           UNION ALL
           SELECT 'email' FROM employee WHERE email = $2
           LIMIT 1`,
          [em_id, email]
        );
        if (dup) {
          const msg = dup.field === 'em_id' ? 'Employee ID already in use' : 'Email already in use';
          throw Object.assign(new Error(msg), { http: 409 });
        }

        // 2) Hash
        const hash = await bcrypt.hash(password, 10);

        // 3) Normalize role_id from the form:
        //    - treat "", null, undefined, "   " as null
        //    - accept only digits
        const roleIdFromForm = (typeof role_id === 'string' && /^\d+$/.test(role_id))
          ? parseInt(role_id, 10)
          : (Number.isInteger(role_id) ? role_id : null);

        // 4) Resolve fallback EMPLOYEE id if needed
        let finalRoleId = roleIdFromForm;
        if (finalRoleId == null) {
          const fallback = await t.oneOrNone(`SELECT id FROM role WHERE code = 'EMPLOYEE'`);
          if (!fallback) {
            throw Object.assign(new Error('Default EMPLOYEE role not found'), { http: 500 });
          }
          finalRoleId = fallback.id;
        } else {
          // Optional: validate provided role exists
          const exists = await t.oneOrNone('SELECT 1 FROM role WHERE id = $1', [finalRoleId]);
          if (!exists) {
            return res.status(400).json({ error: 'Invalid role_id' });
          }
        }

        // 5) Insert (no casting errors now)
        const inserted = await t.one(
          `INSERT INTO employee (employee_name, email, password, dp_id, em_id, role_id)
           VALUES ($1, $2, $3, $4, $5, $6)
           RETURNING id`,
          [employee_name, email, hash, parseInt(dp_id,10), em_id, finalRoleId]
        );
        const employeeId = inserted.id;

        // 6) Optional image upload
        if (req.file) {
          const f = req.file, ts = Date.now();
          const key = `employees/${employeeId}/${ts}-${f.originalname}`;
          await uploadToR2(key, f.buffer, f.mimetype);
          const fileUrl = `${(process.env.R2_PUBLIC_URL_PROFILE || '').replace(/\/+$/, '')}/${key}`;
          await t.none(
            `INSERT INTO employee_images (employee_id, file_name, file_type, file_size_bytes, file_url)
             VALUES ($1, $2, $3, $4, $5)`,
            [employeeId, f.originalname, f.mimetype, f.size, fileUrl]
          );
        }

        res.status(201).json({
          message: 'Registered successfully',
          employee: { id: employeeId, employee_name, email, dp_id, em_id, role_id: finalRoleId },
        });
      });
    } catch (e) {
      if (e.http) return res.status(e.http).json({ error: e.message });
      if (e.code === '23505') return res.status(409).json({ error: 'Duplicate key (email or em_id)' });
      console.error('Register error:', e);
      res.status(500).json({ error: 'Server error' });
    }
  },
];



/* =======================================================
   LOGIN
   - LEFT JOIN role (fallback to EMPLOYEE if null)
   - Consistent TTLs with rememberMe
   ======================================================= */
exports.login = async (req, res) => {
  const { em_id, password } = req.body || {};
  const rememberMe = normalizeRememberMe(req.body?.rememberMe);

  if (!em_id || !password) {
    return res.status(400).json({ error: 'Missing fields' });
  }

  try {
    const employee = await db.oneOrNone(
      `SELECT id, em_id, employee_name, email, password, dp_id, role_id
       FROM employee
       WHERE em_id = $1`,
      [em_id]
    );
    if (!employee) {
      return res.status(401).json({ error: 'Invalid ID or Password' });
    }

    const match = await bcrypt.compare(password, employee.password);
    if (!match) {
      return res.status(401).json({ error: 'Invalid ID or Password' });
    }

    // Safer role lookup
    const roleRow = await db.oneOrNone(
      `SELECT r.code AS role_code
       FROM employee e
       LEFT JOIN role r ON r.id = e.role_id
       WHERE e.id = $1`,
      [employee.id]
    );
    const role = roleRow?.role_code || 'EMPLOYEE';

    const payload = { id: employee.id, em_id: employee.em_id, role };
    const refreshPayload = { id: employee.id, em_id: employee.em_id, role, rememberMe };

    const accessToken  = signAccessToken(payload, rememberMe);
    const refreshToken = signRefreshToken(refreshPayload, rememberMe);

    return res.json({
      message: 'Login successful',
      accessToken,
      refreshToken,
      employee: buildEmployeeDto(employee, role),
    });
  } catch (e) {
    console.error('Login error:', e);
    res.status(500).json({ error: 'Server error' });
  }
};

/* =======================================================
   REFRESH
   - Accepts refreshToken in body
   - Re-issues access (and rotates refresh) honoring rememberMe
   - (Optional) verify user still exists
   ======================================================= */
exports.refresh = async (req, res) => {
  const { refreshToken } = req.body || {};
  if (!refreshToken) {
    return res.status(400).json({ error: 'Missing refresh token' });
  }

  try {
    let payload;
    try {
      payload = jwt.verify(refreshToken, process.env.JWT_SECRET_REFRESH);
    } catch {
      return res.status(401).json({ error: 'Invalid refresh token' });
    }

    // Optional: ensure user still exists (and maybe fetch current role)
    const row = await db.oneOrNone(
      `SELECT e.id, e.em_id, r.code AS role_code
       FROM employee e
       LEFT JOIN role r ON r.id = e.role_id
       WHERE e.id = $1 AND e.em_id = $2`,
      [payload.id, payload.em_id]
    );
    if (!row) return res.status(401).json({ error: 'User not found' });

    const role = row.role_code || payload.role || 'EMPLOYEE';
    const rememberMe = normalizeRememberMe(payload.rememberMe);

    const newAccess  = signAccessToken({ id: row.id, em_id: row.em_id, role }, rememberMe);
    const newRefresh = signRefreshToken({ id: row.id, em_id: row.em_id, role, rememberMe }, rememberMe);

    return res.json({ accessToken: newAccess, refreshToken: newRefresh });
  } catch (err) {
    console.error('Refresh error:', err);
    return res.status(500).json({ error: 'Server error' });
  }
};
