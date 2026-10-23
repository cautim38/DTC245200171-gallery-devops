const client = require('prom-client');

// Khởi tạo Registry để gom toàn bộ metrics
const register = new client.Registry();

// Bật thu thập metrics mặc định của Node.js (CPU, RAM, Event Loop, GC)
client.collectDefaultMetrics({
  register,
  prefix: 'gallery_node_'
});

// Metric đếm tổng số request HTTP
const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Tổng số request HTTP đã xử lý',
  labelNames: ['method', 'route', 'status_code']
});

// Metric đo thời gian phản hồi (latency) của request
const httpRequestDurationSeconds = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Thời gian phản hồi request HTTP tính bằng giây',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.01, 0.05, 0.1, 0.3, 0.5, 1, 2, 5]
});

// Metric nghiệp vụ: Đếm số ảnh đã upload
const photosUploadedTotal = new client.Counter({
  name: 'gallery_photos_uploaded_total',
  help: 'Tổng số ảnh được người dùng tải lên thành công'
});

// Metric nghiệp vụ: Đếm số album đã tạo
const albumsCreatedTotal = new client.Counter({
  name: 'gallery_albums_created_total',
  help: 'Tổng số album ảnh được tạo'
});

// Đăng ký các metrics tùy chỉnh vào Registry
register.registerMetric(httpRequestsTotal);
register.registerMetric(httpRequestDurationSeconds);
register.registerMetric(photosUploadedTotal);
register.registerMetric(albumsCreatedTotal);

// Middleware tự động đo latency và đếm request cho Express
function metricsMiddleware(req, res, next) {
  // Bỏ qua đo đạc chính endpoint /metrics và /health để tránh nhiễu
  if (req.path === '/metrics' || req.path === '/health') {
    return next();
  }

  const start = process.hrtime();

  res.on('finish', () => {
    const diff = process.hrtime(start);
    const durationInSeconds = diff[0] + diff[1] / 1e9;
    const route = req.route ? req.route.path : req.path;
    const statusCode = res.statusCode.toString();

    httpRequestsTotal.inc({
      method: req.method,
      route: route,
      status_code: statusCode
    });

    httpRequestDurationSeconds.observe(
      {
        method: req.method,
        route: route,
        status_code: statusCode
      },
      durationInSeconds
    );
  });

  next();
}

module.exports = {
  register,
  metricsMiddleware,
  photosUploadedTotal,
  albumsCreatedTotal
};
