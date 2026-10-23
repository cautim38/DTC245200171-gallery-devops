require('dotenv').config();
const express = require('express');
const path = require('path');
const cookieParser = require('cookie-parser');
const cors = require('cors');
const helmet = require('helmet');

const { pool, waitForDatabase } = require('./db');
const { register, metricsMiddleware } = require('./metrics');
const { authenticateSession } = require('./middleware/auth');
const { uploadDir } = require('./middleware/upload');

// Routers
const authRouter = require('./routes/auth');
const albumsRouter = require('./routes/albums');
const photosRouter = require('./routes/photos');
const sharesRouter = require('./routes/shares');

const app = express();
const PORT = parseInt(process.env.APP_PORT || '3000', 10);

// ==============================================================================
// 1. CẤU HÌNH BẢO MẬT VÀ MIDDLEWARE CƠ BẢN
// ==============================================================================
// Tin tưởng proxy Nginx phía trước (lấy IP thật từ X-Forwarded-For)
app.set('trust proxy', 1);

// Cấu hình View Engine (EJS)
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

// Helmet security headers (cho phép inline styles phục vụ giao diện hiện đại)
app.use(
  helmet({
    contentSecurityPolicy: false, // CSP đầy đủ sẽ được quản trị chặt chẽ tại Nginx Reverse Proxy
    crossOriginEmbedderPolicy: false
  })
);

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(cookieParser());

// Thu thập Metrics cho Prometheus
app.use(metricsMiddleware);

// Middleware xác thực phiên
app.use(authenticateSession);

// Phục vụ file tĩnh (CSS/JS giao diện)
app.use('/public', express.static(path.join(__dirname, 'public')));

// Phục vụ file ảnh upload (Hardening: Chặn thực thi script trong thư mục upload)
app.use(
  '/uploads',
  (req, res, next) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Content-Security-Policy', "default-src 'none'; style-src 'unsafe-inline'; sandbox");
    next();
  },
  express.static(uploadDir)
);

// ==============================================================================
// 2. ENDPOINT GIÁM SÁT & KIỂM TRA SỨC KHỎE
// ==============================================================================

// Endpoint kiểm tra sức khỏe hệ thống (Healthcheck)
app.get('/health', async (req, res) => {
  let dbStatus = 'DOWN';
  try {
    const [result] = await pool.query('SELECT 1 AS ok');
    if (result && result[0].ok === 1) {
      dbStatus = 'UP';
    }
  } catch (err) {
    dbStatus = 'ERROR: ' + err.message;
  }

  const isHealthy = dbStatus === 'UP';
  res.status(isHealthy ? 200 : 503).json({
    status: isHealthy ? 'UP' : 'DEGRADED',
    timestamp: new Date().toISOString(),
    uptimeSeconds: Math.floor(process.uptime()),
    service: 'gallery-app',
    database: dbStatus,
    student: {
      mssv: 'DTC245200171',
      name: 'Nguyễn Thành Long',
      topic: '31 - Gallery System'
    }
  });
});

// Endpoint xuất Metrics Prometheus (Prom-client)
app.get('/metrics', async (req, res) => {
  try {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  } catch (err) {
    res.status(500).end(err.message);
  }
});

// ==============================================================================
// 3. ĐIỀU HƯỚNG TRANG & ROUTERS
// ==============================================================================
app.use('/auth', authRouter);
app.use('/albums', albumsRouter);
app.use('/', photosRouter);
app.use('/share', sharesRouter);

// Trang chủ chuyển hướng về danh sách albums
app.get('/', (req, res) => {
  if (req.user) {
    return res.redirect('/albums');
  }
  return res.redirect('/auth/login');
});

// Xử lý 404
app.use((req, res) => {
  res.status(404).render('error', {
    title: '404 - Không tìm thấy trang',
    message: 'Trang bạn yêu cầu không tồn tại trên hệ thống Gallery DevOps.'
  });
});

// Xử lý Lỗi Toàn cục (500)
app.use((err, req, res, next) => {
  console.error('[Error Handler]:', err);
  if (err.code === 'INVALID_FILE_TYPE' || err.code === 'LIMIT_FILE_SIZE') {
    return res.status(400).render('error', {
      title: 'Lỗi tải ảnh',
      message: err.message || 'File tải lên không hợp lệ hoặc vượt quá dung lượng cho phép.'
    });
  }
  res.status(500).render('error', {
    title: 'Lỗi máy chủ',
    message: 'Hệ thống gặp sự cố trong quá trình xử lý yêu cầu.'
  });
});

// ==============================================================================
// 4. KHỞI ĐỘNG MÁY CHỦ SAU KHI DB SẴN SÀNG
// ==============================================================================
async function startServer() {
  try {
    // Đợi DB kết nối thành công trước khi lắng nghe HTTP request
    await waitForDatabase();

    const server = app.listen(PORT, '0.0.0.0', () => {
      console.log(`=======================================================`);
      console.log(` Gallery App đang chạy tại port ${PORT}`);
      console.log(` Môi trường: ${process.env.NODE_ENV || 'development'}`);
      console.log(` Healthcheck: http://localhost:${PORT}/health`);
      console.log(` Metrics:     http://localhost:${PORT}/metrics`);
      console.log(` Sinh viên:   Nguyễn Thành Long - DTC245200171`);
      console.log(`=======================================================`);
    });

    // Graceful Shutdown khi nhận tín hiệu từ Docker (SIGTERM/SIGINT)
    const shutdown = async (signal) => {
      console.log(`\n[Shutdown] Nhận tín hiệu ${signal}. Đang đóng các kết nối...`);
      server.close(() => {
        console.log('[Shutdown] Đã đóng HTTP Server.');
        pool.end().then(() => {
          console.log('[Shutdown] Đã đóng kết nối MySQL.');
          process.exit(0);
        });
      });
    };

    process.on('SIGTERM', () => shutdown('SIGTERM'));
    process.on('SIGINT', () => shutdown('SIGINT'));
  } catch (err) {
    console.error('Không thể khởi động Gallery App:', err);
    process.exit(1);
  }
}

startServer();
