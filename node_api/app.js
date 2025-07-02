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

// global error fallback (if you `next(err)`)
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
});
const PORT = Number(process.env.APP_PORT) || 3000;
app.listen(PORT, () => console.log(`🚀 API running on http://localhost:${PORT}`));
