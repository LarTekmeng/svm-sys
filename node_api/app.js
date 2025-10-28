// PATH: /node_api/app.js
/* This is where backend start */

require('dotenv').config();
const express = require('express');
const cors    = require('cors');
const { Client } = require('pg');
const db = require('./db')
const meRoutes = require('./route/me');
const { requireAuth } = require('./middleware/authMiddleware');
const { requireAdmin, makeBootstrapGuard } = require('./middleware/authMiddleware');

const app = express();
app.use(cors({
    origin : true,
    credentials : true,
    maxAge : 86400,
}));
app.use(express.json());

// --- SSE: new document notifications ---
// --- SSE: new document notifications ---
const SSE_CLIENTS = new Set();

/**
 * Each client is stored as { res } in SSE_CLIENTS.
 * We remove the exact same object on close/aborted.
 */
app.get('/api/home/stream', requireAuth, (req, res) => {
  // TODO: attach auth middleware if you want JWT on this route
  // e.g. app.get('/api/home/stream', auth, (req, res) => { ... })

  res.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    Connection: 'keep-alive',
    'X-Accel-Buffering': 'no', // helpful behind Nginx/Cloudflare
  });
  // Immediately flush headers (no-op on older Node)
  if (typeof res.flushHeaders === 'function') res.flushHeaders();

  // Let clients auto-retry in 10s if the socket dies
  res.write('retry: 10000\n\n');

  const keepAlive = setInterval(() => {
    try {
      res.write(': keepalive\n\n');
    } catch {
      // socket already gone; interval cleared in close handler
    }
  }, 20000);

  const client = { res };
  SSE_CLIENTS.add(client);

  const drop = () => {
    clearInterval(keepAlive);
    SSE_CLIENTS.delete(client);
  };

  req.on('close', drop);
  req.on('aborted', drop);
  res.on('close', drop);
});


(async () => {
  try {
    const notifyClient = new Client({
      host: process.env.DB_HOST,
      port: Number(process.env.DB_PORT || 5432),
      database: process.env.DB_NAME,
      user: process.env.DB_USER,
      password: process.env.DB_PASS,
    });
    await notifyClient.connect();
    await notifyClient.query('LISTEN documents_channel');
    console.log('LISTEN documents_channel');

    notifyClient.on('notification', (msg) => {
      const frame = `data: ${msg.payload}\n\n`;
      // Iterate the actual client objects so we can delete the right one
      for (const client of Array.from(SSE_CLIENTS)) {
        try {
          client.res.write(frame);
        } catch {
          SSE_CLIENTS.delete(client);
        }
      }
    });
    notifyClient.on('error', (e) => console.error('notifyClient error', e));
  } catch (e) {
    console.error('Failed to LISTEN documents_channel', e);
  }
})();

app.use('/api/auth', require('./route/auth'));

const securedBases = [
  '/api/employees',
  '/api/doctypes',
  '/api/documents',
  '/api/home',
  '/api/me' // for your "me" routes
];
for (const base of securedBases) app.use(base, requireAuth);

app.use('/api/employees', require('./route/employee'));
app.use('/api/doctypes', require('./route/docType'));
app.use('/api/documents', require('./route/document'));
app.use('/api/departments', require('./route/department'));
app.use('/api/home', require('./route/home'));
app.use('/api/me', meRoutes);

// global error fallback (if you `next(err)`)
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
});

const PORT = Number(process.env.APP_PORT) || 3000;
const HOST = process.env.APP_HOST || '0.0.0.0'; // <— NEW

app.get('/health', (req, res) => res.json({ ok: true, ts: new Date().toISOString() }));
app.get('/db-ping', async (req, res) => {
  try {
    const r = await db.one('select now() as now');
    res.json(r);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});


app.listen(PORT, HOST, () => {
  console.log(`🚀 API running on http://${HOST}:${PORT}`);
});