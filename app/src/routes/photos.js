const express = require('express');
const router = express.Router();
const path = require('path');
const fs = require('fs');
const { pool } = require('../db');
const { upload, uploadDir } = require('../middleware/upload');
const { requireAuth } = require('../middleware/auth');
const { photosUploadedTotal } = require('../metrics');

// Upload ảnh vào Album
router.post('/albums/:albumId/photos', requireAuth, upload.array('photos', 10), async (req, res) => {
  const albumId = parseInt(req.params.albumId, 10);

  if (!req.files || req.files.length === 0) {
    return res.redirect(`/albums/${albumId}?error=no_file`);
  }

  try {
    // Kiểm tra quyền sở hữu Album
    const [albums] = await pool.query('SELECT id FROM albums WHERE id = ? AND user_id = ? LIMIT 1', [albumId, req.user.id]);
    if (albums.length === 0) {
      // Xóa file tạm nếu không có quyền
      req.files.forEach(f => fs.existsSync(f.path) && fs.unlinkSync(f.path));
      return res.status(403).render('error', { message: 'Bạn không có quyền upload ảnh vào album này.' });
    }

    // Lưu từng ảnh vào cơ sở dữ liệu (Giải mã UTF-8 chuẩn cho tên file tiếng Việt)
    for (const file of req.files) {
      let originalName = file.originalname;
      try {
        originalName = Buffer.from(file.originalname, 'latin1').toString('utf8');
      } catch (e) {
        originalName = file.originalname;
      }

      await pool.query(
        'INSERT INTO photos (album_id, filename, original_name, mime_type, size) VALUES (?, ?, ?, ?, ?)',
        [albumId, file.filename, originalName, file.mimetype, file.size]
      );
      // Tăng metrics Prometheus cho số ảnh upload
      photosUploadedTotal.inc();
    }

    res.redirect(`/albums/${albumId}?uploaded=${req.files.length}`);
  } catch (err) {
    console.error('Lỗi khi lưu ảnh:', err);
    // Dọn dẹp file rác
    req.files.forEach(f => fs.existsSync(f.path) && fs.unlinkSync(f.path));
    res.redirect(`/albums/${albumId}?error=upload_failed`);
  }
});

// Xóa ảnh
router.post('/photos/:id/delete', requireAuth, async (req, res) => {
  const photoId = parseInt(req.params.id, 10);

  try {
    // Kiểm tra quyền sở hữu qua quan hệ photo -> album -> user
    const [photos] = await pool.query(
      `SELECT p.*, a.user_id 
       FROM photos p 
       JOIN albums a ON p.album_id = a.id 
       WHERE p.id = ? AND a.user_id = ? LIMIT 1`,
      [photoId, req.user.id]
    );

    if (photos.length === 0) {
      return res.status(403).json({ error: 'Không tìm thấy ảnh hoặc bạn không có quyền xóa.' });
    }

    const photo = photos[0];
    const filePath = path.join(uploadDir, photo.filename);

    // Xóa file trên disk
    if (fs.existsSync(filePath)) {
      try {
        fs.unlinkSync(filePath);
      } catch (e) {
        console.warn('Cảnh báo không thể xóa file vật lý:', e.message);
      }
    }

    // Xóa trong DB
    await pool.query('DELETE FROM photos WHERE id = ?', [photoId]);

    res.redirect(`/albums/${photo.album_id}?deleted=1`);
  } catch (err) {
    console.error('Lỗi xóa ảnh:', err);
    res.status(500).render('error', { message: 'Lỗi khi xóa ảnh.', error: err });
  }
});

module.exports = router;
