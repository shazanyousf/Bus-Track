const jwt = require('jsonwebtoken');
const User = require('../models/User');

const verifySession = async (token) => {
  const payload = jwt.verify(token, process.env.JWT_SECRET || 'bustrack_secret');
  const user = await User.findById(payload.id).select('_id role name sessionId').lean();
  if (!user || payload.id !== user._id.toString() || !payload.sessionId || payload.sessionId !== user.sessionId) {
    const error = new Error('SESSION_REVOKED');
    error.code = 'SESSION_REVOKED';
    throw error;
  }
  return payload;
};

const auth = async (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return res.status(401).json({ message: 'No token provided' });
  try {
    req.user = await verifySession(token);
    next();
  } catch (error) {
    if (error.code === 'SESSION_REVOKED') {
      return res.status(401).json({ message: 'SESSION_REVOKED', code: 'SESSION_REVOKED' });
    }
    res.status(401).json({ message: 'Invalid token' });
  }
};

auth.verifySession = verifySession;
auth.adminOnly = (req, res, next) => {
  if (req.user?.role !== 'admin')
    return res.status(403).json({ message: 'Admin access required' });
  next();
};

module.exports = auth;
