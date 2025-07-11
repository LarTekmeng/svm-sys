const jwt = require('jsonwebtoken');

module.exports = function authMiddleware(req, res, next) {
    const authHeader = req.headers.authorization;
    if(!headers) return res.status(401).json({error:'No Token'});

    const token = authHeader.split('')[1];
    try{
        const payload = jwt.verify(token, JWT_SECRET_ACCESS);
        req.employee = payload;
        next();
    }
    catch{
        return res.status(401).json({ error: 'Invalid token' });
    }
};