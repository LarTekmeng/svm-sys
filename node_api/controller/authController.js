const bcrypt = require('bcrypt');
const jwt    = require('jsonwebtoken');
const db     = require('../db');
const multer = require('multer');
const upload = multer({ storage: multer.memoryStorage()});
const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
    const s3 = new S3Client({
        region: "auto", // Or specify a region if needed
        endpoint: process.env.R2_S3_ENDPOINT,
        credentials: {
            accessKeyId: process.env.R2_ACCESS_KEY,
            secretAccessKey: process.env.R2_SECRET_KEY,
        },
    });

async function uploadToR2(key, body, contentType) {
  await s3.send(new PutObjectCommand({
    Bucket:      process.env.R2_BUCKET,
    Key:         key,
    Body:        body,
    ContentType: contentType,
    // you can also set ACL, metadata, etc here
  }));
}

exports.register = [
  upload.single('profile_image'),
  async (req, res) => {
    const { employee_name, email, password, dp_id, em_id } = req.body;
    if (!employee_name || !email || !password || !dp_id || !em_id) {
      return res.status(400).json({ error: 'Missing fields' });
    }
    // ——————————————
    // 2a) Check for duplicate em_id
    const existing = await db.oneOrNone(
      `SELECT id FROM employee WHERE em_id = $1`,
      [em_id]
    );
    if (existing) {
      return res.status(409).json({ error: 'Employee ID already in use' });
    }
    // ——————————————
    try {
      // 3) hash password
      const hash = await bcrypt.hash(password, 10);
      // 4) insert employee
      const { id: employeeId } = await db.one(
        `INSERT INTO employee (employee_name, email, password, dp_id, em_id)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING id`,
        [employee_name, email, hash, dp_id, em_id]
      );
      // 5) if there's an uploaded file, push to R2 & record its metadata
      if (req.file) {
        const file      = req.file;
        const timestamp = Date.now();
        const key       = `employees/${employeeId}/${timestamp}-${file.originalname}`;
        await uploadToR2(key, file.buffer, file.mimetype);
        const fileUrl = `${process.env.R2_PUBLIC_URL}/${key}`
;

        await db.none(
          `INSERT INTO file_upload
             (employee_id, file_name, file_type, file_size_bytes, file_url)
           VALUES ($1, $2, $3, $4, $5)`,
          [
            employeeId,
            file.originalname,
            file.mimetype,
            file.size,
            fileUrl
          ]
        );
      }

      // 6) respond
      res.status(201).json({
        message: 'Registered successfully',
        employee: { id: employeeId, employee_name, email, dp_id, em_id }
      });
    }
    catch (e) {
      if (e.code === '23505') {
        return res.status(409).json({ error: 'Email already in use' });
      }
      console.error(e);
      res.status(500).json({ error: 'Server error' });
    }
  }
];


exports.login = async (req, res) => {
  const { em_id, password, rememberMe } = req.body;

  if (!em_id || !password) {
    return res.status(400).json({ error: 'Missing fields' });
  }
  try {
    const employee = await db.oneOrNone(
      `SELECT * FROM employee WHERE em_id = $1`,
      [em_id]
    );
    if (!employee) {
      return res.status(401).json({ error: 'Invalid ID or Password' });
    }

    const match = await bcrypt.compare(password, employee.password);
    if (!match) {
      return res.status(401).json({ error: 'Invalid Password' });
    }

    const payload = { id: employee.id, em_id: employee.em_id };
    const refreshPayload = { id: employee.id, em_id: employee.em_id, rememberMe };

    const accessTtl = rememberMe ? '1h' : '15m';
    const refreshTtl = rememberMe ? '30d' : '30m';

    const accessToken = jwt.sign(payload, process.env.JWT_SECRET_ACCESS, {expiresIn: accessTtl});
    const refreshToken = jwt.sign(refreshPayload, process.env.JWT_SECRET_REFRESH, {expiresIn: refreshTtl});

    res.json(
        {
            message: 'Login successful',
            accessToken,
            refreshToken,
            employee: {
                        id:            employee.id,
                        employee_name: employee.employee_name,
                        email:         employee.email,
                        dp_id:         employee.dp_id,
                        em_id:         employee.em_id,
                  }
        }
    )
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Server error' });
  }
};

// In authController.js
exports.refresh = async (req, res) => {
  const { refreshToken } = req.body;
  if (!refreshToken) {
    return res.status(400).json({ error: 'Missing refresh token' });
  }
  try {
    const payload = jwt.verify(refreshToken, process.env.JWT_SECRET_REFRESH);
    // Issue a fresh short‐lived access token
    const newAccess  = jwt.sign({ id: payload.id, em_id: payload.em_id },
                                process.env.JWT_SECRET_ACCESS,
                                { expiresIn: '15m' });
    // (Optionally) rotate your refresh token:
    const newfreshTtl = payload.rememberMe ? '30d' : '30m';
    const newRefresh = jwt.sign({ id: payload.id, em_id: payload.em_id, rememberMe: payload.rememberMe },
                                process.env.JWT_SECRET_REFRESH,
                                { expiresIn: newfreshTtl });
    return res.json({ accessToken: newAccess, refreshToken: newRefresh });
  } catch (err) {
    return res.status(401).json({ error: 'Invalid refresh token' });
  }
};
