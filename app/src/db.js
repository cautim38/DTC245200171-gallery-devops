const mysql = require('mysql2/promise');

const pool = mysql.createPool({
  host: process.env.MYSQL_HOST || 'mysql',
  port: parseInt(process.env.MYSQL_PORT || '3306', 10),
  user: process.env.MYSQL_USER || 'gallery_app_user',
  password: process.env.MYSQL_PASSWORD || '123456',
  database: process.env.MYSQL_DATABASE || 'gallery_db',
  charset: 'utf8mb4',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  connectTimeout: 10000
});

// Hàm kiểm tra và retry kết nối khi khởi động container
async function waitForDatabase(retries = 15, delay = 3000) {
  for (let i = 1; i <= retries; i++) {
    try {
      const connection = await pool.getConnection();
      console.log(`[Database] Đã kết nối thành công tới MySQL (Lần thử ${i})`);
      connection.release();
      return pool;
    } catch (err) {
      console.warn(`[Database] MySQL chưa sẵn sàng (Lần thử ${i}/${retries}): ${err.message}. Thử lại sau ${delay / 1000}s...`);
      if (i === retries) {
        console.error('[Database] Không thể kết nối tới MySQL sau nhiều lần thử.');
        throw err;
      }
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
}

module.exports = {
  pool,
  waitForDatabase
};
