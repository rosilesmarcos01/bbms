const express = require('express');
const router = express.Router();
const rubidexService = require('../services/rubidexService');

// Get current temperature readings for all devices
router.get('/current', async (req, res) => {
  try {
    console.log('📱 iOS app requesting current temperatures');
    const temperatures = await rubidexService.getLatestTemperatures();
    res.json(temperatures);
  } catch (error) {
    console.error('❌ Error fetching current temperatures:', error.message);
    res.status(500).json({ error: 'Failed to fetch current temperatures' });
  }
});

// Write new temperature reading to blockchain
router.post('/reading', async (req, res) => {
  try {
    const { deviceId, temperature, location, alertLimit, deviceName } = req.body;
    
    console.log(`📊 Receiving temperature reading: ${temperature}°C from device ${deviceId}`);
    
    // Validate input
    if (!deviceId || temperature === undefined) {
      return res.status(400).json({ error: 'deviceId and temperature are required' });
    }
    
    // Write to blockchain
    const result = await rubidexService.writeTemperatureReading({
      deviceId,
      temperature,
      location,
      alertLimit,
      deviceName
    });
    
    // Emit real-time update via WebSocket
    const io = req.app.get('io');
    io.to(`temperature_${deviceId}`).emit('temperature_update', {
      deviceId,
      temperature,
      timestamp: new Date().toISOString()
    });
    
    console.log(`✅ Temperature reading written and broadcasted: ${temperature}°C`);
    res.json({ 
      success: true, 
      message: 'Temperature reading saved to blockchain',
      data: result
    });
    
  } catch (error) {
    console.error('❌ Error writing temperature reading:', error.message);
    res.status(500).json({ error: 'Failed to write temperature reading' });
  }
});

// Process temperature alert
router.post('/alert', async (req, res) => {
  try {
    const { deviceId, temperature, limit, severity, title, message } = req.body;
    
    console.log(`🚨 Processing temperature alert for device ${deviceId}: ${temperature}°C > ${limit}°C`);
    
    // Write alert to blockchain for audit trail
    const alertData = {
      deviceId,
      temperature,
      limit,
      severity,
      title,
      message
    };
    
    await rubidexService.writeAlert(alertData);
    
    // Emit real-time alert via WebSocket
    const io = req.app.get('io');
    io.emit('temperature_alert', alertData);
    
    console.log(`✅ Temperature alert processed and broadcasted`);
    res.json({ 
      success: true, 
      message: 'Alert processed and saved to blockchain' 
    });
    
  } catch (error) {
    console.error('❌ Error processing alert:', error.message);
    res.status(500).json({ error: 'Failed to process alert' });
  }
});

// Test endpoint for iOS app
router.post('/test', async (req, res) => {
  try {
    console.log('🧪 Test endpoint called from iOS app');
    
    // Test connection to Rubidex
    const connectionTest = await rubidexService.testConnection();
    
    res.json({
      status: 'success',
      message: 'Backend test successful',
      rubidexConnection: connectionTest,
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('❌ Test endpoint failed:', error.message);
    res.status(500).json({ 
      status: 'error',
      error: 'Test failed',
      message: error.message 
    });
  }
});

module.exports = router;