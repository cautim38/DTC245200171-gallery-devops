const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const { pool } = require('../db');
const { signSession } = require('../middleware/auth');

// Trang Đăng nhập
router.get('/login', (req, res) => {
  if (req.user) return res.redirect('/albums');
  res.render('login', { title: 'Đăng nhập - Gallery DevOps', error: null });
});

// Xử lý Đăng nhập
router.post('/login', async (req, res) => {
  const { username, password } = req.body;
  if (!username || !password) {
    return res.render('login', { title: 'Đăng nhập - Gallery DevOps', error: 'Vui lòng nhập đầy đủ tên đăng nhập và mật khẩu!' });
  }

  try {
    const [users] = await pool.query('SELECT * FROM users WHERE username = ? LIMIT 1', [username.trim()]);
    if (users.length === 0) {
      return res.render('login', { title: 'Đăng nhập - Gallery DevOps', error: 'Tên đăng nhập hoặc mật khẩu không chính xác.' });
    }

    const user = users[0];
    const isMatch = await bcrypt.compare(password, user.password_hash);
    if (!isMatch) {
      return res.render('login', { title: 'Đăng nhập - Gallery DevOps', error: 'Tên đăng nhập hoặc mật khẩu không chính xác.' });
    }

    // Tạo cookie session an toàn
    const token = signSession({ id: user.id, username: user.username, email: user.email, role: user.role });
    res.cookie('gallery_session', token, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      maxAge: 24 * 60 * 60 * 1000 // 1 ngày
    });

    const redirectUrl = req.query.redirect || '/albums';
    return res.redirect(redirectUrl);
  } catch (err) {
    console.error('Lỗi đăng nhập:', err);
    return res.render('login', { title: 'Đăng nhập - Gallery DevOps', error: 'Có lỗi xảy ra trên máy chủ, vui lòng thử lại sau.' });
  }
});

// Trang Đăng ký
router.get('/register', (req, res) => {
  if (req.user) return res.redirect('/albums');
  res.render('register', { title: 'Đăng ký - Gallery DevOps', error: null });
});

// Xử lý Đăng ký
router.post('/register', async (req, res) => {
  const { username, email, password, confirmPassword } = req.body;

  if (!username || !email || !password || !confirmPassword) {
    return res.render('register', { title: 'Đăng ký - Gallery DevOps', error: 'Vui lòng điền đầy đủ các trường thông tin!' });
  }

  if (password !== confirmPassword) {
    return res.render('register', { title: 'Đăng ký - Gallery DevOps', error: 'Mật khẩu xác nhận không khớp!' });
  }

  if (password.length < 6) {
    return res.render('register', { title: 'Đăng ký - Gallery DevOps', error: 'Mật khẩu phải có tối thiểu 6 ký tự!' });
  }

  try {
    // Kiểm tra trùng username hoặc email
    const [existing] = await pool.query('SELECT id FROM users WHERE username = ? OR email = ? LIMIT 1', [username.trim(), email.trim()]);
    if (existing.length > 0) {
      return res.render('register', { title: 'Đăng ký - Gallery DevOps', error: 'Tên đăng nhập hoặc Email đã tồn tại trong hệ thống!' });
    }

    // Băm mật khẩu bằng bcrypt (Salt rounds = 10)
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(password, salt);

    await pool.query(
      'INSERT INTO users (username, email, password_hash, role) VALUES (?, ?, ?, ?)',
      [username.trim(), email.trim(), passwordHash, 'user']
    );

    return res.redirect('/auth/login?registered=1');
  } catch (err) {
    console.error('Lỗi đăng ký:', err);
    return res.render('register', { title: 'Đăng ký - Gallery DevOps', error: 'Không thể đăng ký tài khoản lúc này.' });
  }
});

// Đăng xuất
router.get('/logout', (req, res) => {
  res.clearCookie('gallery_session');
  res.redirect('/auth/login');
});

module.exports = router;
