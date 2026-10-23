const express = require('express');
const router = express.Router();
const { pool } = require('../db');

// Xem Album công khai qua Token chia sẻ (Không cần đăng nhập)
router.get('/:token', async (req, res) => {
  const { token } = req.params;

  try {
    const [shares] = await pool.query(
      `SELECT s.*, a.title AS album_title, a.description AS album_description, 
              u.username AS owner_name, c.name AS category_name
       FROM shares s
       JOIN albums a ON s.album_id = a.id
       JOIN users u ON a.user_id = u.id
       LEFT JOIN categories c ON a.category_id = c.id
       WHERE s.token = ? LIMIT 1`,
      [token]
    );

    if (shares.length === 0) {
      return res.status(404).render('error', {
        message: 'Liên kết chia sẻ không tồn tại hoặc đã bị chủ sở hữu thu hồi.'
      });
    }

    const share = shares[0];

    // Kiểm tra hết hạn nếu có expires_at
    if (share.expires_at && new Date(share.expires_at) < new Date()) {
      return res.status(410).render('error', {
        message: 'Liên kết chia sẻ này đã hết hạn truy cập.'
      });
    }

    // Lấy danh sách ảnh trong album
    const [photos] = await pool.query(
      'SELECT id, filename, original_name, size, created_at FROM photos WHERE album_id = ? ORDER BY created_at DESC',
      [share.album_id]
    );

    res.render('share', {
      title: `Chia sẻ: ${share.album_title} - Gallery`,
      share,
      photos
    });
  } catch (err) {
    console.error('Lỗi khi truy cập link chia sẻ:', err);
    res.status(500).render('error', { message: 'Có lỗi xảy ra khi xem album chia sẻ.' });
  }
});

module.exports = router;
