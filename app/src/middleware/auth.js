const crypto = require('crypto');
const { pool } = require('../db');

const SESSION_SECRET = process.env.SESSION_SECRET || 'gallery_secret_default_key_2026';

// Tạo chữ ký đơn giản cho session cookie
function signSession(data) {
  const jsonStr = JSON.stringify(data);
  const base64Data = Buffer.from(jsonStr).toString('base64');
  const signature = crypto.createHmac('sha256', SESSION_SECRET).update(base64Data).digest('hex');
  return `${base64Data}.${signature}`;
}

// Xác thực chữ ký session cookie
function verifySession(cookieValue) {
  if (!cookieValue || !cookieValue.includes('.')) return null;
  const [base64Data, signature] = cookieValue.split('.');
  const expectedSignature = crypto.createHmac('sha256', SESSION_SECRET).update(base64Data).digest('hex');
  if (signature !== expectedSignature) return null;
  try {
    const jsonStr = Buffer.from(base64Data, 'base64').toString('utf8');
    return JSON.parse(jsonStr);
  } catch (err) {
    return null;
  }
}

// Middleware gắn thông tin user vào req.user nếu có cookie
function authenticateSession(req, res, next) {
  const cookie = req.cookies?.gallery_session;
  if (cookie) {
    const sessionData = verifySession(cookie);
    if (sessionData && sessionData.id) {
      req.user = sessionData;
      res.locals.currentUser = sessionData;
    }
  }
  next();
}

// Middleware bắt buộc đăng nhập
function requireAuth(req, res, next) {
  if (!req.user) {
    if (req.xhr || req.headers.accept?.includes('application/json')) {
      return res.status(401).json({ error: 'Yêu cầu đăng nhập để thực hiện chức năng này.' });
    }
    return res.redirect('/auth/login?redirect=' + encodeURIComponent(req.originalUrl));
  }
  next();
}

module.exports = {
  signSession,
  verifySession,
  authenticateSession,
  requireAuth
};
