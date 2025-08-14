const db = require('../db');
const storage = require('../service/documentFileStorage');

const ALLOWED_EXT = new Set(['.jpg', '.jpeg', '.png', '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.txt']);
const extOf = (n) => {
  const i = (n || '').lastIndexOf('.');
  return i >= 0 ? n.slice(i).toLowerCase() : '';
};

// --- LIST (kept; added ORDER BY for consistency)
exports.list = async (req, res) => {
  const sql = `
    SELECT
      d.id,
      d.title,
      d.description,
      d.status,
      d.created_at,
      d.updated_at,
      dt.title AS document_type,
      e.employee_name AS uploader
    FROM documents d
    JOIN document_types dt ON d.document_type_id = dt.id
    JOIN employee e       ON d.uploader_id       = e.id
    ORDER BY d.created_at DESC
  `;
  try {
    const rows = await db.any(sql);
    return res.json(rows);
  } catch (e) {
    console.error('Error fetching documents:', e);
    return res.status(500).json({ error: 'Error fetching documents' });
  }
};

// --- CREATE (JSON only) (kept as-is if you still want it)
exports.create = async (req, res) => {
  const { document_type_id, title, description } = req.body;

  if (
    !document_type_id ||
    typeof title       !== 'string' || !title.trim() ||
    typeof description !== 'string' || !description.trim()
  ) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  const sql = `
    INSERT INTO documents (document_type_id, uploader_id, title, description)
    VALUES ($1, $2, $3, $4)
    RETURNING id;
  `;

  try {
    const { id } = await db.one(sql, [
      document_type_id,
      req.employee?.id,
      title.trim(),
      description.trim()
    ]);

    return res.status(201).json({
      message: 'Document created',
      document: { id, document_type_id, title: title.trim(), description: description.trim() }
    });
  } catch (err) {
    console.error('Error creating document:', err);
    return res.status(500).json({ error: 'Error creating document' });
  }
};

// --- NEW: REGISTER-STYLE MULTIPART ---
// POST /api/documents/with-files (multipart/form-data)
// fields: document_type_id, title, description
// files:  "files"[] (one or many)
// controllers/documentController.js
exports.createWithFiles = async (req, res) => {
  const employeeId = req.employee?.id;
  if (!employeeId) return res.status(401).json({ error: 'Not Authenticated' });

  const { document_type_id, title, description } = req.body;
  if (!document_type_id || !String(title).trim() || !String(description).trim()) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  // Multer (from router) places files here:
  const files = Array.isArray(req.files) ? req.files : (req.file ? [req.file] : []);
  const uploadedKeys = [];

  try {
    const result = await db.tx(async (t) => {
      // (1) insert document
      const { id: documentId } = await t.one(
        `INSERT INTO documents (document_type_id, uploader_id, title, description)
         VALUES ($1,$2,$3,$4) RETURNING id`,
        [document_type_id, employeeId, String(title).trim(), String(description).trim()]
      );

      // (2) create steps (direct vs step-by-step)
      const setting = await t.oneOrNone(
        `SELECT forward_mode FROM document_type_settings WHERE document_type_id=$1`,
        [document_type_id]
      );
      const flows = await t.any(
        `SELECT sequence, department_id, employee_id, step_action
           FROM document_type_flows
          WHERE document_type_id=$1
          ORDER BY sequence ASC`,
        [document_type_id]
      );
      const stepsToInsert = (setting?.forward_mode === 'Step by Step')
        ? (flows.length ? [flows[0]] : [])
        : flows;
      for (const f of stepsToInsert) {
        await t.none(
          `INSERT INTO document_steps
             (document_id, sequence, department_id, employee_id, step_action, status)
           VALUES ($1,$2,$3,$4,$5,'PENDING')`,
          [documentId, f.sequence, f.department_id, f.employee_id, f.step_action]
        );
      }

      // (3) upload files to R2 + insert file rows
      const savedFiles = [];
      for (const f of files) {
        const ext = extOf(f.originalname);
        if (!ALLOWED_EXT.has(ext)) {
          throw new Error(`File type not allowed: ${ext || '(no extension)'}`);
        }

        const { key, publicUrl } = await storage.uploadBuffer({
          documentId,
          buffer: f.buffer,
          contentType: f.mimetype,
          originalname: f.originalname,
        });
        uploadedKeys.push(key);

        const row = await t.one(
          `INSERT INTO document_files (document_id, file_name, file_type, file_size, file_url)
           VALUES ($1,$2,$3,$4,$5)
           RETURNING id, document_id, file_name, file_type, file_size, file_url, uploaded_at`,
          [documentId, f.originalname, f.mimetype, f.size, publicUrl]
        );
        savedFiles.push(row);
      }

      return {
        document: { id: documentId, document_type_id, title: String(title).trim(), description: String(description).trim() },
        files: savedFiles,
      };
    });

    return res.status(201).json({ message: 'Document created with files', ...result });
  } catch (e) {
    // best-effort cleanup of uploaded objects if TX failed
    if (uploadedKeys.length) {
      const { deleteKey } = storage;
      await Promise.all(uploadedKeys.map(k => deleteKey(k)));
    }
    console.error('Error creating document with files:', e);
    const hint = (e.Code === 'AccessDenied')
      ? 'R2 access denied — check S3 access key scope, bucket name, endpoint, and forcePathStyle'
      : e.message;
    return res.status(500).json({ error: 'Error creating document with files', details: hint });
  }
};


// --- LIST FILES ---
exports.listFiles = async (req, res) => {
  const documentId = parseInt(req.params.documentId, 10);
  if (!Number.isInteger(documentId)) return res.status(400).json({ error: 'Invalid documentId' });

  try {
    const rows = await db.any(`
      SELECT id, document_id, file_name, file_type, file_size, file_url, uploaded_at
      FROM document_files
      WHERE document_id = $1
      ORDER BY uploaded_at DESC
    `, [documentId]);
    return res.json(rows);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'Failed to fetch files' });
  }
};

// --- DELETE FILE (optional) ---
exports.removeFile = async (req, res) => {
  const documentId = parseInt(req.params.documentId, 10);
  const fileId = parseInt(req.params.fileId, 10);
  if (!Number.isInteger(documentId) || !Number.isInteger(fileId)) {
    return res.status(400).json({ error: 'Invalid ids' });
  }

  try {
    const row = await db.oneOrNone(`
      SELECT id, file_url
      FROM document_files
      WHERE id = $1 AND document_id = $2
    `, [fileId, documentId]);

    if (!row) return res.status(404).json({ error: 'File not found' });

    // If you want to also delete from R2, you must convert public URL back to key:
    // public URL = `${R2_PUBLIC_URL_FILE}/${key}`
    const base = (process.env.R2_PUBLIC_URL_FILE || '').replace(/\/+$/,'');
    const key = row.file_url.startsWith(base) ? row.file_url.substring(base.length + 1) : null;

    if (key) {
      try { await storage.deleteKey(key); } catch (e) { console.warn('R2 delete failed, continuing...', e); }
    }

    await db.none(`DELETE FROM document_files WHERE id = $1`, [fileId]);
    return res.json({ message: 'Deleted', id: fileId });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'Delete failed' });
  }
};
