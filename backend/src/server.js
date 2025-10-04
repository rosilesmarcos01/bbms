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
  origin: process.env.ALLOWED_ORIGINS?.split(',') || "*"
}));
app.use(express.json());

// Routes
app.use('/api/devices', deviceRoutes);
app.use('/api/temperature', temperatureRoutes);
app.use('/api/documents', documentsRoutes);

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  });
});

// WebSocket connection handling
io.on('connection', (socket) => {
  console.log('📱 iOS client connected:', socket.id);
  
  socket.on('subscribe_temperature', (deviceId) => {
    socket.join(`temperature_${deviceId}`);
    console.log(`📊 Client subscribed to temperature updates for device: ${deviceId}`);
  });
  
  socket.on('disconnect', () => {
    console.log('📱 iOS client disconnected:', socket.id);
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