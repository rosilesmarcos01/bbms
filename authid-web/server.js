const express = require('express');
const cors = require('cors');
const path = require('path');
const https = require('https');
const http = require('http');
const fs = require('fs');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3002;
const HOST = '0.0.0.0'; // Listen on all network interfaces

// Enable CORS for all origins (for development)
app.use(cors());

// Request logging middleware
app.use((req, res, next) => {
  console.log(`📥 ${req.method} ${req.url}`);
  next();
});

// Serve static files
app.use(express.static(path.join(__dirname, 'public')));

// Serve node_modules for React and AuthID component
app.use('/node_modules', express.static(path.join(__dirname, 'node_modules')));

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    service: 'AuthID Enrollment Interface',
    timestamp: new Date().toISOString() 
  });
});

// Serve enrollment page
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Catch all route
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Try to load SSL certificates for HTTPS
let useHttps = false;
let httpsOptions = {};

try {
  const keyPath = path.join(__dirname, 'localhost-key.pem');
  const certPath = path.join(__dirname, 'localhost-cert.pem');
  
  if (fs.existsSync(keyPath) && fs.existsSync(certPath)) {
    httpsOptions = {
      key: fs.readFileSync(keyPath),
      cert: fs.readFileSync(certPath)
    };
    useHttps = true;
    console.log('✅ SSL certificates found - HTTPS enabled');
  }
} catch (error) {
  console.log('⚠️  No SSL certificates - using HTTP');
}

// Create server (HTTPS if certificates available, HTTP otherwise)
const server = useHttps ? https.createServer(httpsOptions, app) : http.createServer(app);

server.listen(PORT, HOST, () => {
  const hostIp = process.env.HOST_IP || 'YOUR_IP';
  const protocol = useHttps ? 'https' : 'http';
  
  console.log(`
🚀 AuthID Enrollment Interface
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🌐 Local:    ${protocol}://localhost:${PORT}
🌐 Network:  ${protocol}://${hostIp}:${PORT}
${useHttps ? '🔒 HTTPS Enabled (Self-signed certificate)' : '⚠️  HTTP Only (Camera may not work on iOS)'}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💡 Access from iPhone: ${protocol}://${hostIp}:${PORT}
  `);
  
  // Try to detect and display local IP
  const os = require('os');
  const networkInterfaces = os.networkInterfaces();
  const addresses = [];
  
  for (const name of Object.keys(networkInterfaces)) {
    for (const net of networkInterfaces[name]) {
      if (net.family === 'IPv4' && !net.internal) {
        addresses.push(net.address);
      }
    }
  }
  
  if (addresses.length > 0) {
    console.log(`📱 iPhone Access URLs:`);
    addresses.forEach(addr => {
      console.log(`   ${protocol}://${addr}:${PORT}`);
    });
  }
});
