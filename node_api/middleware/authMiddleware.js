const jwt = require('jsonwebtoken');

module.exports = function authMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader) {
    return res.status(401).json({ error: 'No token provided' });
  }

  // Expect exactly two parts: ['Bearer', '<token>']
  const parts = authHeader.split(' ');
  if (parts.length !== 2 || parts[0] !== 'Bearer') {
    return res.status(401).json({ error: 'Malformed token' });
  }
  const token = parts[1];

  try {
    // use your env var
    const payload = jwt.verify(token, process.env.JWT_SECRET_ACCESS);
    req.employee = payload;   // now available in controllers
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
};
