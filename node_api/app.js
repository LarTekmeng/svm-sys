/* This is where backend start */

require('dotenv').config();
const express = require('express');
const cors    = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

app.use('/api/auth',      require('./route/auth'));
app.use('/api/employees', require('./route/employee'));
app.use('/api/doctypes', require('./route/docType'));
app.use('/api/documents', require('./route/document'));
app.use('/api/departments', require('./route/department'));
app.use('/api/home', require('./route/home'));

// global error fallback (if you `next(err)`)
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
});

const PORT = Number(process.env.APP_PORT) || 3000;
const HOST = process.env.APP_HOST || '0.0.0.0'; // <— NEW

app.listen(PORT, HOST, () => {
  console.log(`🚀 API running on http://${HOST}:${PORT}`);
});
app.get('/health', (req, res) => {
  res.status(200).json({ ok: true, ts: Date.now() });
});