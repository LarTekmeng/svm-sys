// controller/documentController.js
const db = require('../db');
const storage = require('../service/documentFileStorage');

const ALLOWED_EXT = new Set(['.jpg', '.jpeg', '.png', '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.txt']);
const extOf = (n) => {
  const i = (n || '').lastIndexOf('.');
  return i >= 0 ? n.slice(i).toLowerCase() : '';
};

// ---------- helpers ----------
const getMe = (req) => ({
  id:   req.user?.id ?? req.employee?.id ?? null,
  role: req.user?.role ?? req.employee?.role ?? null,
});
const isAdminReq = (req) => getMe(req).role === 'ADMIN';

/** Admin can view all. Employee can view if: uploader OR assignee OR (Read-Only & in flow). */
async function canViewDocument(dbOrTx, docId, userId, isAdmin) {
  if (isAdmin) return true;
  const row = await dbOrTx.oneOrNone(
    `
    SELECT
      d.uploader_id,
      s.action,
      EXISTS (SELECT 1 FROM document_steps ds WHERE ds.document_id = d.id AND ds.employee_id = $2) AS is_assignee,
      EXISTS (
        SELECT 1 FROM document_type_flows f
        WHERE f.document_type_id = d.document_type_id AND f.employee_id = $2
      ) AS in_flow
    FROM documents d
    LEFT JOIN document_type_settings s ON s.document_type_id = d.document_type_id
    WHERE d.id = $1
    `,
    [docId, userId]
  );
  if (!row) return false;
  if (row.uploader_id === userId) return true;
  if (row.is_assignee) return true;
  if (row.action === 'Read-Only' && row.in_flow) return true;
  return false;
}

/** Is the user the current actionable assignee (PENDING), honoring Step-by-Step? */
async function isCurrentActionableAssignee(dbOrTx, docId, userId) {
  const header = await dbOrTx.one(
    `SELECT d.uploader_id, s.action, s.forward_mode
     FROM documents d
     LEFT JOIN document_type_settings s ON s.document_type_id = d.document_type_id
     WHERE d.id = $1`, [docId]
  );

  const steps = await dbOrTx.any(
    `SELECT id, sequence, status, employee_id
     FROM document_steps WHERE document_id = $1 ORDER BY sequence ASC`, [docId]
  );

  if (header.action !== 'Ask for Permission') return false;
  let actionable = null;
  if (header.forward_mode === 'Step by Step') {
    const minPending = steps
      .filter(s => s.status === 'PENDING')
      .reduce((min, s) => (min == null || s.sequence < min ? s.sequence : min), null);
    actionable = steps.find(s => s.status === 'PENDING' && s.sequence === minPending && s.employee_id === userId);
  } else {
    actionable = steps.find(s => s.status === 'PENDING' && s.employee_id === userId);
  }
  return !!actionable && header.uploader_id !== userId;
}

// --- REGISTER-STYLE MULTIPART ---
// POST /api/documents/with-files
exports.createWithFiles = async (req, res) => {
  const me = getMe(req);
  if (!me.id) return res.status(401).json({ error: 'Not Authenticated' });

  const { document_type_id, title, description } = req.body;
  if (!document_type_id || !String(title).trim() || !String(description).trim()) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  const files = Array.isArray(req.files) ? req.files : (req.file ? [req.file] : []);
  const uploadedKeys = [];

  try {
    const result = await db.tx(async (t) => {
      const setting = await t.oneOrNone(
        `SELECT action, forward_mode FROM document_type_settings WHERE document_type_id = $1`,
        [document_type_id]
      );

      const flows = await t.any(
        `SELECT sequence, department_id, employee_id, step_action
         FROM document_type_flows
         WHERE document_type_id = $1
         ORDER BY sequence ASC`,
        [document_type_id]
      );

      const initialStatus = (setting?.action === 'Ask for Permission') ? 'PENDING' : null;

      const { id: documentId } = await t.one(
        `INSERT INTO documents (document_type_id, uploader_id, title, description, status)
         VALUES ($1,$2,$3,$4,$5) RETURNING id`,
        [document_type_id, me.id, String(title).trim(), String(description).trim(), initialStatus]
      );

      const stepsToInsert =
        (setting?.action === 'Read-Only')
          ? []
          : (setting?.forward_mode === 'Step by Step'
              ? (flows.length ? [flows[0]] : [])
              : flows);

      for (const f of stepsToInsert) {
        await t.none(
          `INSERT INTO document_steps
             (document_id, sequence, department_id, employee_id, step_action, status)
           VALUES ($1,$2,$3,$4,$5,'PENDING')`,
          [documentId, f.sequence, f.department_id, f.employee_id, f.step_action]
        );
      }

      if (setting?.action === 'Ask for Permission' && flows.length === 0) {
        await t.none(`UPDATE documents SET status = 'COMPLETED', updated_at = now() WHERE id = $1`, [documentId]);
      }

      const savedFiles = [];
      for (const f of files) {
        const ext = extOf(f.originalname);
        if (!ALLOWED_EXT.has(ext)) throw new Error(`File type not allowed: ${ext || '(no extension)'}`);

        const { key, publicUrl } = await storage.uploadBuffer({
          documentId,
          buffer: f.buffer,
          contentType: f.mimetype,
          originalname: f.originalname,
        });
        uploadedKeys.push(key);

        const row = await t.one(
          `INSERT INTO document_files (document_id, file_name, file_type, file_size, file_url, uploaded_by)
           VALUES ($1,$2,$3,$4,$5,$6)
           RETURNING id, document_id, file_name, file_type, file_size, file_url, uploaded_at, uploaded_by`,
          [documentId, f.originalname, f.mimetype, f.size, publicUrl, me.id]
        );
        savedFiles.push(row);
      }

      return {
        document: {
          id: documentId,
          document_type_id,
          title: String(title).trim(),
          description: String(description).trim(),
        },
        files: savedFiles,
      };
    });

    return res.status(201).json({ message: 'Document created with files', ...result });
  } catch (e) {
    if (uploadedKeys.length) {
      const { deleteKey } = storage;
      await Promise.all(uploadedKeys.map((k) => deleteKey(k)));
    }
    console.error('Error creating document with files:', e);
    const hint = (e.code || e.Code) === 'AccessDenied'
      ? 'R2 access denied — check S3 access key scope, bucket name, endpoint, and forcePathStyle'
      : (e.message || String(e));
    return res.status(500).json({ error: 'Error creating document with files', details: hint });
  }
};

// --- LIST FILES ---
exports.listFiles = async (req, res) => {
  const documentId = parseInt(req.params.documentId, 10);
  const me = getMe(req);
  if (!Number.isInteger(documentId)) return res.status(400).json({ error: 'Invalid documentId' });
  if (!me.id) return res.status(401).json({ error: 'Not Authenticated' });

  try {
    const allowed = await canViewDocument(db, documentId, me.id, me.role === 'ADMIN');
    if (!allowed) return res.status(403).json({ error: 'Forbidden' });

    const rows = await db.any(`
      SELECT f.id, f.document_id, f.file_name, f.file_type, f.file_size, f.file_url, f.uploaded_at,
             e.employee_name AS uploader_name, f.uploaded_by
      FROM document_files f
      LEFT JOIN employee e ON e.id = f.uploaded_by
      WHERE f.document_id = $1
      ORDER BY f.uploaded_at DESC
    `, [documentId]);
    return res.json(rows);
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'Failed to fetch files' });
  }
};

// --- DELETE FILE ---
exports.removeFile = async (req, res) => {
  const documentId = parseInt(req.params.documentId, 10);
  const fileId = parseInt(req.params.fileId, 10);
  const me = getMe(req);

  if (!Number.isInteger(documentId) || !Number.isInteger(fileId)) {
    return res.status(400).json({ error: 'Invalid ids' });
  }
  if (!me.id) return res.status(401).json({ error: 'Not Authenticated' });

  try {
    const canView = await canViewDocument(db, documentId, me.id, me.role === 'ADMIN');
    if (!canView) return res.status(403).json({ error: 'Forbidden' });

    const row = await db.oneOrNone(`
      SELECT id, file_url, uploaded_by
      FROM document_files
      WHERE id = $1 AND document_id = $2
    `, [fileId, documentId]);

    if (!row) return res.status(404).json({ error: 'File not found' });

    // Only the original uploader OR current actionable assignee can delete.
    const uploaderCan = row.uploaded_by === me.id;
    const assigneeCan = await isCurrentActionableAssignee(db, documentId, me.id);
    if (!uploaderCan && !assigneeCan) {
      return res.status(403).json({ error: 'Not allowed to delete this file' });
    }

    const base = (process.env.R2_PUBLIC_URL_FILE || '').replace(/\/+$/, '');
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

// --- DOCUMENT DETAIL (read) ---
exports.detail = async (req, res) => {
  const docId = parseInt(req.params.id, 10);
  const user = getMe(req);
  const me = user.id;
  if (!Number.isInteger(docId)) return res.status(400).json({ error: 'Invalid id' });
  if (!me) return res.status(401).json({ error: 'Not Authenticated' });

  try {
    const allowedToView = await canViewDocument(db, docId, me, user.role === 'ADMIN');
    if (!allowedToView) return res.status(403).json({ error: 'Forbidden' });

    const doc = await db.oneOrNone(`
      SELECT d.id, d.title, d.description, d.status, d.created_at, d.updated_at,
             d.document_type_id,
             dt.title AS document_type_title,
             s.action, s.forward_mode,
             u.employee_name AS uploader_name, u.id AS uploader_id,
             dep.name AS uploader_department_name
      FROM documents d
      LEFT JOIN document_types dt         ON dt.id = d.document_type_id
      LEFT JOIN document_type_settings s  ON s.document_type_id = d.document_type_id
      JOIN employee u                     ON u.id = d.uploader_id
      LEFT JOIN department dep            ON dep.id = u.dp_id
      WHERE d.id = $1
    `, [docId]);
    if (!doc) return res.status(404).json({ error: 'Document not found' });

    const steps = await db.any(`
      SELECT ds.id, ds.sequence, ds.department_id, ds.employee_id,
             ds.step_action, ds.status, ds.requested_at, ds.responded_at,
             dp.name AS department_name,
             e.employee_name
      FROM document_steps ds
      LEFT JOIN department dp ON dp.id = ds.department_id
      LEFT JOIN employee   e  ON e.id  = ds.employee_id
      WHERE ds.document_id = $1
      ORDER BY ds.sequence ASC, ds.id ASC
    `, [docId]);

    const flowsCount = await db.one(
      `SELECT COUNT(*)::int AS cnt FROM document_type_flows WHERE document_type_id = $1`,
      [doc.document_type_id]
    );

    // compute my actionable step (same rules as before)
    let myActionable = null;
    if (doc.forward_mode === 'Step by Step') {
      const minPending = steps
        .filter(s => s.status === 'PENDING')
        .reduce((min, s) => (min == null || s.sequence < min ? s.sequence : min), null);
      myActionable = steps.find(s =>
        s.status === 'PENDING' &&
        s.sequence === minPending &&
        s.employee_id === me
      ) || null;
    } else {
      myActionable = steps.find(s => s.status === 'PENDING' && s.employee_id === me) || null;
    }

    const isUploader = doc.uploader_id === me;
    const canAct = !!myActionable && !isUploader && doc.action === 'Ask for Permission';
    const canAttach = canAct;

    return res.json({
      document: doc,
      steps,
      flowsCount: flowsCount.cnt,
      current_actionable_step_id: myActionable?.id ?? null,
      current_actionable_step_action: myActionable?.step_action ?? null, // APPROVAL | SIGNATURE (display)
      canAct,
      canAttach,
    });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'Failed to load document detail' });
  }
};

// --- APPROVE / REJECT (assignee only; Admin must be assigned) ---
exports.decideStep = async (req, res) => {
  const me = getMe(req).id;
  if (!me) return res.status(401).json({ error: 'Not Authenticated' });

  const docId = parseInt(req.params.id, 10);
  const stepId = parseInt(req.params.stepId, 10);
  const decision = String(req.body?.decision || '').toUpperCase(); // APPROVED | REJECTED

  if (!Number.isInteger(docId) || !Number.isInteger(stepId)) {
    return res.status(400).json({ error: 'Invalid ids' });
  }
  if (!['APPROVED', 'REJECTED'].includes(decision)) {
    return res.status(400).json({ error: 'Invalid decision' });
  }

  try {
    const result = await db.tx(async (t) => {
      const ctx = await t.one(
        `
        SELECT
          d.id AS document_id, d.status AS doc_status, d.uploader_id,
          d.document_type_id,
          s.action, s.forward_mode,
          ds.id AS step_id, ds.status AS step_status, ds.sequence, ds.employee_id
        FROM documents d
        JOIN document_steps ds ON ds.document_id = d.id
        LEFT JOIN document_type_settings s ON s.document_type_id = d.document_type_id
        WHERE d.id = $1 AND ds.id = $2
        FOR UPDATE OF d, ds
      `,
        [docId, stepId]
      );

      if (ctx.employee_id !== me) throw new Error('You are not the assignee of this step');
      if (ctx.uploader_id === me) throw new Error('Uploader cannot approve/reject their own document');
      if (ctx.action !== 'Ask for Permission') throw new Error('This document type is Read-Only');
      if (ctx.step_status !== 'PENDING') throw new Error('This step is not pending');

      await t.none(
        `UPDATE document_steps SET status = $1, responded_at = now() WHERE id = $2`,
        [decision, stepId]
      );

      if (decision === 'REJECTED') {
        await t.none(`UPDATE documents SET status = 'REJECTED', updated_at = now() WHERE id = $1`, [docId]);
        return { document_status: 'REJECTED' };
      }

      if (ctx.forward_mode === 'Step by Step') {
        await t.oneOrNone(
          `
          WITH nxt AS (
            SELECT sequence, department_id, employee_id, step_action
            FROM document_type_flows
            WHERE document_type_id = $1 AND sequence > $2
            ORDER BY sequence ASC LIMIT 1
          )
          INSERT INTO document_steps (document_id, sequence, department_id, employee_id, step_action, status)
          SELECT $3, n.sequence, n.department_id, n.employee_id, n.step_action, 'PENDING'
          FROM nxt n
          RETURNING id
          `,
          [ctx.document_type_id, ctx.sequence, docId]
        );
      }

      const agg = await t.one(
        `
        SELECT
          COUNT(*) FILTER (WHERE status = 'PENDING')  AS pending_cnt,
          COUNT(*) FILTER (WHERE status = 'REJECTED') AS rejected_cnt
        FROM document_steps WHERE document_id = $1
      `,
        [docId]
      );

      let newStatus;
      if (Number(agg.rejected_cnt) > 0) newStatus = 'REJECTED';
      else if (Number(agg.pending_cnt) === 0) newStatus = 'COMPLETED';
      else newStatus = 'PENDING';

      await t.none(`UPDATE documents SET status = $1, updated_at = now() WHERE id = $2`, [newStatus, docId]);
      return { document_status: newStatus };
    });

    return res.json({ message: 'Decision recorded', ...result });
  } catch (e) {
    console.error(e);
    return res.status(400).json({ error: e.message || 'Decision failed' });
  }
};

// --- ADD FILES to existing doc (assignee only; Admin must be assigned) ---
exports.addFilesToExisting = async (req, res) => {
  const me = getMe(req).id;
  const docId = parseInt(req.params.id, 10);
  if (!me) return res.status(401).json({ error: 'Not Authenticated' });
  if (!Number.isInteger(docId)) return res.status(400).json({ error: 'Invalid id' });

  const files = Array.isArray(req.files) ? req.files : (req.file ? [req.file] : []);
  if (!files.length) return res.status(400).json({ error: 'No files' });

  const uploadedKeys = [];

  try {
    const saved = await db.tx(async (t) => {
      const header = await t.one(`
        SELECT d.uploader_id, s.action, s.forward_mode
        FROM documents d
        LEFT JOIN document_type_settings s ON s.document_type_id = d.document_type_id
        WHERE d.id = $1
      `, [docId]);

      const steps = await t.any(`
        SELECT id, sequence, status, employee_id
        FROM document_steps WHERE document_id = $1
        ORDER BY sequence ASC FOR UPDATE
      `, [docId]);

      let actionable = null;
      if (header.forward_mode === 'Step by Step') {
        const minPending = steps
          .filter(s => s.status === 'PENDING')
          .reduce((min, s) => (min == null || s.sequence < min ? s.sequence : min), null);
        actionable = steps.find(s => s.status === 'PENDING' && s.sequence === minPending && s.employee_id === me);
      } else {
        actionable = steps.find(s => s.status === 'PENDING' && s.employee_id === me);
      }

      if (!actionable) throw new Error('You cannot upload now (not your turn)');
      if (header.uploader_id === me) throw new Error('Uploader cannot attach at this step');
      if (header.action !== 'Ask for Permission') throw new Error('Attachments not allowed for Read-Only type');

      const resultRows = [];
      for (const f of files) {
        const ext = extOf(f.originalname);
        if (!ALLOWED_EXT.has(ext)) throw new Error(`File type not allowed: ${ext || '(no extension)'}`);

        const { key, publicUrl } = await storage.uploadBuffer({
          documentId: docId, buffer: f.buffer, contentType: f.mimetype, originalname: f.originalname,
        });
        uploadedKeys.push(key);

        const row = await t.one(
          `WITH ins AS (
             INSERT INTO document_files (document_id, file_name, file_type, file_size, file_url, uploaded_by)
             VALUES ($1,$2,$3,$4,$5,$6)
             RETURNING id, document_id, file_name, file_type, file_size, file_url, uploaded_at, uploaded_by
           )
           SELECT ins.*, e.employee_name AS uploader_name
           FROM ins LEFT JOIN employee e ON e.id = ins.uploaded_by`,
          [docId, f.originalname, f.mimetype, f.size, publicUrl, me]
        );
        resultRows.push(row);
      }
      return resultRows;
    });

    return res.status(201).json({ message: 'Files uploaded', files: saved });
  } catch (e) {
    if (uploadedKeys.length) {
      const { deleteKey } = storage;
      await Promise.all(uploadedKeys.map((k) => deleteKey(k)));
    }
    console.error(e);
    return res.status(400).json({ error: e.message || 'Upload failed' });
  }
};

// --- READ-ONLY docs shared to me (unchanged behavior) ---
exports.listShared = async (req, res) => {
  const me = getMe(req).id;
  if (!me) return res.status(401).json({ error: 'Not authenticated' });

  try {
    const rows = await db.any(
      `
      SELECT d.id, d.document_type_id, dt.title AS document_type_title,
             d.title, d.description, d.status, d.created_at, d.updated_at,
             u.employee_name AS uploader_name
      FROM documents d
      JOIN document_type_settings s ON s.document_type_id = d.document_type_id
      JOIN document_types dt ON dt.id = d.document_type_id
      LEFT JOIN employee u ON u.id = d.uploader_id
      WHERE s.action = 'Read-Only'
        AND EXISTS (
          SELECT 1 FROM document_type_flows f
          WHERE f.document_type_id = d.document_type_id AND f.employee_id = $1
        )
      ORDER BY d.created_at DESC
      `,
      [me]
    );

    return res.json({ items: rows });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: 'Failed to list shared documents' });
  }
};
