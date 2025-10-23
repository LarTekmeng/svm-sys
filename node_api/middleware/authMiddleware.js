// PATH: /node_api/middleware/authMiddleware.js
const jwt = require('jsonwebtoken');

function getTokenFromReq(req) {
  const h = req.headers.authorization || '';
  if (h.startsWith('Bearer ')) return h.slice(7);
  if (req.headers['x-access-token']) return req.headers['x-access-token'];
  if (req.cookies?.accessToken) return req.cookies.accessToken;
  return null;
}

/** Require a valid access token and normalize req.user */
function requireAuth(req, res, next) {
  const token = getTokenFromReq(req);
  if (!token) return res.status(401).json({ error: 'No token provided' });
  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET_ACCESS);
    req.user = {
      id: payload.id,
      em_id: payload.em_id,
      role: payload.role, // 'ADMIN' | 'EMPLOYEE'
    };
    // Backward compatibility for old controllers
    req.employee = req.user;
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

/** Admin-only gate */
function requireAdmin(req, res, next) {
  if (!req.user || req.user.role !== 'ADMIN') {
    return res.status(403).json({ error: 'Admin only' });
  }
  next();
}

/** Convenience helper */
function isAdmin(req) {
  return !!req.user && req.user.role === 'ADMIN';
}

module.exports = { requireAuth, requireAdmin, isAdmin };
