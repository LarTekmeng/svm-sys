'use strict';
require('dotenv').config();

const pg = require('pg');
pg.types.setTypeParser(20, (val) => (val === null ? null : parseInt(val, 10)));
pg.types.setTypeParser(1700, (val) => (val === null ? null : parseFloat(val)));

const pgp = require('pg-promise')();
const db = pgp({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT || 5432),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASS,
});

module.exports = db;
