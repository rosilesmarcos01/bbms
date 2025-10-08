const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const http = require('http');
const socketIo = require('socket.io');
require('dotenv').config();

const rubidexService = require('./services/rubidexService');
const deviceRoutes = require('./routes/deviceRoutes');
const temperatureRoutes = require('./routes/temperatureRoutes');
const documentsRoutes = require('./routes/documentsRoutes');
const authMiddleware = require('./middleware/authMiddleware');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: process.env.ALLOWED_ORIGINS?.split(',') || "*",
    methods: ["GET", "POST"]
  }
});

// Middleware
app.use(helmet());
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || "*",
  credentials: true
}));
app.use(express.json());

// Add user context to all requests (optional auth)
app.use('/api', authMiddleware.optionalAuth);

// Public routes (no authentication required)
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    version: '1.0.0',
    authService: process.env.AUTH_SERVICE_URL || 'http://localhost:3001',
    authenticated: !!req.user
  });
});

// Protected routes (authentication required)
app.use('/api/devices', authMiddleware.verifyToken, deviceRoutes);
app.use('/api/temperature', authMiddleware.verifyToken, temperatureRoutes);
app.use('/api/documents', authMiddleware.verifyToken, authMiddleware.requireAccessLevel(['standard', 'elevated', 'admin']), documentsRoutes);

// WebSocket connection handling with authentication
io.use(async (socket, next) => {
  try {
    const token = socket.handshake.auth?.token || socket.handshake.headers?.authorization?.replace('Bearer ', '');
    
    if (!token) {
      return next(new Error('Authentication required'));
    }

    // Verify token with auth service
    const axios = require('axios');
    const response = await axios.get(`${process.env.AUTH_SERVICE_URL || 'http://localhost:3001'}/api/auth/me`, {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });

    socket.user = response.data.user;
    socket.token = token;
    next();
  } catch (error) {
    console.warn('❌ WebSocket authentication failed:', error.response?.data || error.message);
    next(new Error('Authentication failed'));
  }
});

io.on('connection', (socket) => {
  console.log(`📱 iOS client connected: ${socket.id} (User: ${socket.user?.name || 'Unknown'})`);
  
  socket.on('subscribe_temperature', (deviceId) => {
    // Check if user has access to this device
    if (socket.user) {
      socket.join(`temperature_${deviceId}`);
      console.log(`📊 User ${socket.user.name} subscribed to temperature updates for device: ${deviceId}`);
      
      // Log the building access
      authMiddleware.logBuildingAccess(
        socket.user.id,
        `device_${deviceId}`,
        'monitoring_access',
        'websocket',
        deviceId
      ).catch(err => console.warn('Failed to log device access:', err.message));
    }
  });
  
  socket.on('disconnect', () => {
    console.log(`📱 iOS client disconnected: ${socket.id} (User: ${socket.user?.name || 'Unknown'})`);
  });
});

// Make io available to other modules
app.set('io', io);

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('❌ Error:', err);
  res.status(500).json({ 
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong'
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

const PORT = process.env.PORT || 3000;

server.listen(PORT, () => {
  console.log(`🚀 BBMS Backend running on port ${PORT}`);
  console.log(`📡 Environment: ${process.env.NODE_ENV}`);
  console.log(`🔗 Rubidex URL: ${process.env.RUBIDEX_API_URL}`);
  
  // Test Rubidex connection on startup
  rubidexService.testConnection()
    .then(() => console.log('✅ Rubidex connection successful'))
    .catch(err => console.error('❌ Rubidex connection failed:', err.message));
});