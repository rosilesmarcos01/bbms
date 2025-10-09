const express = require('express');
const http = require('http');
const https = require('https');
const fs = require('fs');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const cookieParser = require('cookie-parser');
const rateLimit = require('express-rate-limit');
const path = require('path');
require('dotenv').config();

const logger = require('./utils/logger');
const authRoutes = require('./routes/authRoutes');
const biometricRoutes = require('./routes/biometricRoutes');
const userRoutes = require('./routes/userRoutes');
const buildingAccessRoutes = require('./routes/buildingAccessRoutes');
const errorHandler = require('./middleware/errorHandler');
const authMiddleware = require('./middleware/authMiddleware');

const app = express();
const PORT = process.env.PORT || 3001;

// Rate limiting
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000, // 15 minutes
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 50000, // limit each IP to 50k requests per windowMs (increased from 10k)
  message: {
    error: 'Too many requests from this IP, please try again later.',
    code: 'RATE_LIMIT_EXCEEDED'
  }
});

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'", "'unsafe-inline'", "https://unpkg.com"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'", "https://id-uat.authid.ai", "https://id.authid.ai"],
      frameSrc: ["'self'"],
    },
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  }
}));

// CORS configuration
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With']
}));

// Basic middleware
app.use(limiter);
app.use(morgan('combined', { stream: { write: message => logger.info(message.trim()) } }));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(cookieParser());

// Serve static files for AuthID enrollment page
app.use('/enroll', express.static(path.join(__dirname, '../public')));

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    service: 'BBMS Authentication Service',
    timestamp: new Date().toISOString(),
    version: '1.0.0',
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development'
  });
});

// Health check endpoint under /api path (for certificate trust check)
app.get('/api/health', (req, res) => {
  res.json({
    status: 'OK',
    service: 'BBMS Authentication Service',
    timestamp: new Date().toISOString()
  });
});

// API Routes
console.log('🔧 Mounting auth routes...');
app.use('/api/auth', authRoutes);
console.log('🔧 Mounting biometric routes...');
app.use('/api/biometric', biometricRoutes);
console.log('🔧 Mounting user routes...');
app.use('/api/users', authMiddleware.verifyToken, userRoutes);
console.log('🔧 Mounting building access routes...');
app.use('/api/building-access', authMiddleware.verifyToken, buildingAccessRoutes);

// AuthID.ai webhook endpoint (no auth required)
app.use('/webhooks/authid', require('./routes/webhookRoutes'));

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Endpoint not found',
    code: 'NOT_FOUND',
    path: req.originalUrl
  });
});

// Global error handler
app.use(errorHandler.errorHandler);

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully');
  process.exit(0);
});

// Try to load SSL certificates for HTTPS
let useHttps = false;
let httpsOptions = {};

try {
  const keyPath = path.join(__dirname, '../localhost-key.pem');
  const certPath = path.join(__dirname, '../localhost-cert.pem');
  
  if (fs.existsSync(keyPath) && fs.existsSync(certPath)) {
    httpsOptions = {
      key: fs.readFileSync(keyPath),
      cert: fs.readFileSync(certPath)
    };
    useHttps = true;
    logger.info('✅ SSL certificates found - HTTPS enabled');
  }
} catch (error) {
  logger.info('⚠️  No SSL certificates - using HTTP');
}

// Start server (HTTPS if certificates available, HTTP otherwise)
const server = useHttps ? https.createServer(httpsOptions, app) : http.createServer(app);

server.listen(PORT, '0.0.0.0', () => {
  const hostIp = process.env.HOST_IP || 'localhost';
  const protocol = useHttps ? 'https' : 'http';
  logger.info(`🔐 BBMS Auth Service running on port ${PORT}`);
  logger.info(`🌐 Local: ${protocol}://localhost:${PORT}`);
  logger.info(`🌐 Network: ${protocol}://${hostIp}:${PORT}`);
  logger.info(`🏢 Building: ${process.env.FACILITY_NAME || 'Main Building Facility'}`);
  logger.info(`🌍 Environment: ${process.env.NODE_ENV || 'development'}`);
  if (useHttps) {
    logger.info('🔒 HTTPS enabled (Self-signed certificate)');
    logger.info('💡 Note: authid-web uses HTTP to avoid SSL certificate issues with IP addresses');
  }
});

module.exports = app;