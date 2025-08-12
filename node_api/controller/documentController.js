const db = require('../db');
const storage = require('../service/documentFileStorage');

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
exports.createWithFiles = async (req, res) => {
  const employeeId = req.employee?.id;
  if (!employeeId) return res.status(401).json({ error: 'Not Authenticated' });

  const { document_type_id, title, description } = req.body;

  if (
    !document_type_id ||
    typeof title       !== 'string' || !title.trim() ||
    typeof description !== 'string' || !description.trim()
  ) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  const files = Array.isArray(req.files) ? req.files : (req.file ? [req.file] : []);

  // allowlist (case-insensitive by extension)
  const allowedExt = new Set(['.jpg', '.jpeg', '.png', '.pdf', '.docx', '.xlsx']);
  function extOf(name) {
    const i = name.lastIndexOf('.');
    return i >= 0 ? name.slice(i).toLowerCase() : '';
  }

  try {
    // 1) Insert document first
    const { id: documentId } = await db.one(
      `INSERT INTO documents (document_type_id, uploader_id, title, description)
       VALUES ($1, $2, $3, $4)
       RETURNING id`,
      [document_type_id, employeeId, title.trim(), description.trim()]
    );

    const savedFiles = [];

    // 2) Upload each file (if any) and insert rows
    for (const f of files) {
      const ext = extOf(f.originalname);
      if (!allowedExt.has(ext)) {
        return res.status(415).json({ error: `File type not allowed: ${ext || '(no extension)'}` });
      }

      const { key, publicUrl } = await storage.uploadBuffer({
        documentId,
        buffer: f.buffer,
        contentType: f.mimetype,
        originalname: f.originalname,
      });

      const row = await db.one(`
        INSERT INTO document_files (document_id, file_name, file_type, file_size, file_url)
        VALUES ($1, $2, $3, $4, $5)
        RETURNING id, document_id, file_name, file_type, file_size, file_url, uploaded_at
      `, [documentId, f.originalname, f.mimetype, f.size, publicUrl]);

      savedFiles.push(row);
    }

    // 3) Return the created document + files
    return res.status(201).json({
      message: 'Document created with files',
      document: {
        id: documentId,
        document_type_id,
        title: title.trim(),
        description: description.trim()
      },
      files: savedFiles
    });
  } catch (e) {
    console.error('Error creating document with files:', e);
    return res.status(500).json({ error: 'Error creating document with files' });
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
