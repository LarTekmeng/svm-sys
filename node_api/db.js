// PATH: /node_api/db.js
'use strict';
require('dotenv').config();

const pg = require('pg');
pg.types.setTypeParser(20, (v) => (v == null ? null : parseInt(v, 10)));
pg.types.setTypeParser(1700, (v) => (v == null ? null : parseFloat(v)));

const pgp = require('pg-promise')();

const cn =
  //process.env.DATABASE_URL ||
  {
    host: process.env.DB_HOST,           // should be "db"
    port: Number(process.env.DB_PORT || 5432),
    database: process.env.DB_NAME,
    user: process.env.DB_USER,
    password: process.env.DB_PASS,
  };

const db = pgp(cn);
module.exports = db;
