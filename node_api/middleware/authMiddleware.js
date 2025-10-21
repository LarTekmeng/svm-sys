// PATH: /node_api/middleware/authMiddleware.js
const jwt = require('jsonwebtoken');

module.exports = async function authMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader) {
    return res.status(401).json({ error: 'No token provided' });
  }

  const parts = authHeader.split(' ');
  if (parts.length !== 2 || parts[0] !== 'Bearer') {
    return res.status(401).json({ error: 'Malformed token' });
  }
  const token = parts[1];

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET_ACCESS);
    req.employee = payload;
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Invalid or expired token...' });
  }
};




function getTokenFromReq(req) {
  // Prefer Authorization: Bearer <token>
  const authHeader = req.headers.authorization || '';
  if (authHeader.startsWith('Bearer ')) return authHeader.slice(7);

  // Optional: also accept x-access-token or cookie if you set it there
  if (req.headers['x-access-token']) return req.headers['x-access-token'];
  if (req.cookies && req.cookies.accessToken) return req.cookies.accessToken;

  return null;
}

/**
 * Verifies the access token and attaches a normalized user object.
 * Expects your JWT payload to include: { id, em_id, role }
 */
function requireAuth(req, res, next) {
  const token = getTokenFromReq(req);
  if (!token) return res.status(401).json({ error: 'No token provided' });

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET_ACCESS);
    // Normalize and attach to req.user
    req.user = {
      id: payload.id,
      em_id: payload.em_id,
      role: payload.role, // 'ADMIN' or 'USER'
    };
    return next();
  } catch (err) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

/** Simple role gate: admin only */
function requireAdmin(req, res, next) {
  if (!req.user || req.user.role !== 'ADMIN') {
    return res.status(403).json({ error: 'Admin only' });
  }
  return next();
}

/**
 * Optional: Bootstrap guard for /auth/register
 * - If there are 0 employees, allow (first user becomes ADMIN in controller).
 * - Otherwise, require admin.
 * Usage: router.post('/auth/register', requireAuth, makeBootstrapGuard(db), controller.register)
 */
//function makeBootstrapGuard(db) {
//  return async (req, res, next) => {
//    try {
//      const { count } = await db.one('SELECT COUNT(*)::int AS count FROM employee');
//      if (count === 0) return next(); // first-ever account can be created
//      // otherwise admin only
//      return requireAdmin(req, res, next);
//    } catch (e) {
//      return res.status(500).json({ error: 'Server error (bootstrap check)' });
//    }
//  };
//}

/** Convenience helper for controllers that need quick checks */
function isAdmin(req) {
  return !!req.user && req.user.role === 'ADMIN';
}

module.exports = {
  requireAuth,
  requireAdmin,
  makeBootstrapGuard,
  isAdmin,
};
