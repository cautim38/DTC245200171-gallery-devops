const express = require('express');
const router = express.Router();
const crypto = require('crypto');
const { pool } = require('../db');
const { requireAuth } = require('../middleware/auth');
const { albumsCreatedTotal } = require('../metrics');

router.use(requireAuth);

// 1. Danh sách Albums (kèm lọc theo category)
router.get('/', async (req, res) => {
  try {
    const categoryId = req.query.category ? parseInt(req.query.category, 10) : null;
    let sql = `
      SELECT a.*, c.name AS category_name, COUNT(p.id) AS photo_count,
             (SELECT p2.filename FROM photos p2 WHERE p2.album_id = a.id ORDER BY p2.id DESC LIMIT 1) AS cover_photo
      FROM albums a
      LEFT JOIN categories c ON a.category_id = c.id
      LEFT JOIN photos p ON a.id = p.album_id
      WHERE a.user_id = ?
    `;
    const params = [req.user.id];

    if (categoryId) {
      sql += ' AND a.category_id = ?';
      params.push(categoryId);
    }

    sql += ' GROUP BY a.id ORDER BY a.created_at DESC';

    const [albums] = await pool.query(sql, params);
    const [categories] = await pool.query('SELECT * FROM categories ORDER BY name ASC');

    res.render('albums/index', {
      title: 'Quản lý Album - Gallery DevOps',
      albums,
      categories,
      selectedCategory: categoryId
    });
  } catch (err) {
    console.error('Lỗi lấy danh sách album:', err);
    res.status(500).render('error', { message: 'Lỗi nạp danh sách Album', error: err });
  }
});

// 2. Tạo Album mới
router.post('/', async (req, res) => {
  const { title, description, category_id } = req.body;
  if (!title || !title.trim()) {
    return res.redirect('/albums?error=empty_title');
  }

  try {
    const catId = category_id ? parseInt(category_id, 10) : null;
    await pool.query(
      'INSERT INTO albums (user_id, category_id, title, description) VALUES (?, ?, ?, ?)',
      [req.user.id, catId, title.trim(), description ? description.trim() : null]
    );

    // Tăng Prometheus metric
    albumsCreatedTotal.inc();

    res.redirect('/albums');
  } catch (err) {
    console.error('Lỗi tạo album:', err);
    res.redirect('/albums?error=create_failed');
  }
});

// 3. Chi tiết Album + xem ảnh
router.get('/:id', async (req, res) => {
  const albumId = parseInt(req.params.id, 10);
  try {
    const [albums] = await pool.query(
      `SELECT a.*, c.name AS category_name 
       FROM albums a 
       LEFT JOIN categories c ON a.category_id = c.id 
       WHERE a.id = ? AND a.user_id = ? LIMIT 1`,
      [albumId, req.user.id]
    );

    if (albums.length === 0) {
      return res.status(404).render('error', { message: 'Album không tồn tại hoặc bạn không có quyền xem.' });
    }

    const album = albums[0];
    const [photos] = await pool.query('SELECT * FROM photos WHERE album_id = ? ORDER BY created_at DESC', [albumId]);
    photos.forEach(p => {
      try {
        if (p.original_name && (p.original_name.includes('Ã') || /[\xC2-\xF4][\x80-\xBF]/.test(p.original_name))) {
          p.original_name = Buffer.from(p.original_name, 'latin1').toString('utf8');
        }
      } catch (e) {}
    });
    const [shares] = await pool.query('SELECT * FROM shares WHERE album_id = ? ORDER BY created_at DESC', [albumId]);
    const [categories] = await pool.query('SELECT * FROM categories ORDER BY name ASC');

    res.render('albums/show', {
      title: `${album.title} - Gallery DevOps`,
      album,
      photos,
      shares,
      categories,
      protocol: req.headers['x-forwarded-proto'] || req.protocol,
      host: req.get('host')
    });
  } catch (err) {
    console.error('Lỗi lấy chi tiết album:', err);
    res.status(500).render('error', { message: 'Lỗi nạp chi tiết Album', error: err });
  }
});

// 4. Sửa Album
router.post('/:id/edit', async (req, res) => {
  const albumId = parseInt(req.params.id, 10);
  const { title, description, category_id } = req.body;

  if (!title || !title.trim()) {
    return res.redirect(`/albums/${albumId}?error=empty_title`);
  }

  try {
    const catId = category_id ? parseInt(category_id, 10) : null;
    await pool.query(
      'UPDATE albums SET title = ?, description = ?, category_id = ? WHERE id = ? AND user_id = ?',
      [title.trim(), description ? description.trim() : null, catId, albumId, req.user.id]
    );
    res.redirect(`/albums/${albumId}`);
  } catch (err) {
    console.error('Lỗi cập nhật album:', err);
    res.redirect(`/albums/${albumId}?error=update_failed`);
  }
});

// 5. Xóa Album
router.post('/:id/delete', async (req, res) => {
  const albumId = parseInt(req.params.id, 10);
  try {
    await pool.query('DELETE FROM albums WHERE id = ? AND user_id = ?', [albumId, req.user.id]);
    res.redirect('/albums');
  } catch (err) {
    console.error('Lỗi xóa album:', err);
    res.redirect('/albums?error=delete_failed');
  }
});

// 6. Tạo Link chia sẻ ngẫu nhiên
router.post('/:id/share', async (req, res) => {
  const albumId = parseInt(req.params.id, 10);
  try {
    // Kiểm tra quyền sở hữu
    const [albums] = await pool.query('SELECT id FROM albums WHERE id = ? AND user_id = ? LIMIT 1', [albumId, req.user.id]);
    if (albums.length === 0) {
      return res.status(403).json({ error: 'Không có quyền truy cập album' });
    }

    // Tạo token ngẫu nhiên an toàn bằng crypto
    const token = crypto.randomBytes(24).toString('hex');
    await pool.query('INSERT INTO shares (album_id, token) VALUES (?, ?)', [albumId, token]);

    res.redirect(`/albums/${albumId}?share_created=1`);
  } catch (err) {
    console.error('Lỗi tạo link chia sẻ:', err);
    res.redirect(`/albums/${albumId}?error=share_failed`);
  }
});

// 7. Thu hồi Link chia sẻ
router.post('/:id/revoke-share', async (req, res) => {
  const albumId = parseInt(req.params.id, 10);
  const { share_id } = req.body;
  try {
    await pool.query(
      `DELETE s FROM shares s 
       JOIN albums a ON s.album_id = a.id 
       WHERE s.id = ? AND a.id = ? AND a.user_id = ?`,
      [share_id, albumId, req.user.id]
    );
    res.redirect(`/albums/${albumId}?share_revoked=1`);
  } catch (err) {
    console.error('Lỗi thu hồi link chia sẻ:', err);
    res.redirect(`/albums/${albumId}?error=revoke_failed`);
  }
});

module.exports = router;
