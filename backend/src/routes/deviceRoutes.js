const express = require('express');
const router = express.Router();
const rubidexService = require('../services/rubidexService');

// Get all devices from blockchain
router.get('/', async (req, res) => {
  try {
    console.log('📱 iOS app requesting device list');
    const latestReadings = await rubidexService.getLatestTemperatures();
    
    // Transform blockchain data into device objects (matching iOS Device model)
    const devices = latestReadings.map(reading => ({
      id: reading.deviceId,
      name: reading.name || `Temperature Sensor ${reading.deviceId}`,
      type: 'Temperature',
      location: reading.location || 'Unknown Location',
      status: determineDeviceStatus(reading.temperature),
      value: reading.temperature,
      unit: '°C',
      lastUpdated: reading.timestamp
    }));
    
    console.log(`✅ Returning ${devices.length} devices to iOS app`);
    res.json(devices);
  } catch (error) {
    console.error('❌ Error fetching devices:', error.message);
    res.status(500).json({ error: 'Failed to fetch devices' });
  }
});

// Get specific device details
router.get('/:id', async (req, res) => {
  try {
    const deviceId = req.params.id;
    console.log(`📱 iOS app requesting device details for: ${deviceId}`);
    
    const documents = await rubidexService.getDeviceDocuments(deviceId);
    
    if (documents.length === 0) {
      return res.status(404).json({ error: 'Device not found' });
    }
    
    // Get latest reading
    const latest = documents
      .sort((a, b) => new Date(b.updateDate) - new Date(a.updateDate))[0];
    
    const device = {
      id: deviceId,
      name: latest.fields?.name || `Device ${deviceId}`,
      type: 'Temperature',
      location: latest.fields?.location || 'Unknown',
      status: determineDeviceStatus(parseFloat(latest.fields?.data)),
      value: parseFloat(latest.fields?.data) || 0,
      unit: '°C',
      lastUpdated: latest.updateDate
    };
    
    res.json(device);
  } catch (error) {
    console.error('❌ Error fetching device details:', error.message);
    res.status(500).json({ error: 'Failed to fetch device details' });
  }
});

// Get device historical data
router.get('/:id/history', async (req, res) => {
  try {
    const deviceId = req.params.id;
    const { timeRange = 'hour' } = req.query;
    
    console.log(`📱 iOS app requesting history for device ${deviceId}, range: ${timeRange}`);
    
    const documents = await rubidexService.getDeviceDocuments(deviceId);
    
    // Filter by time range
    const now = new Date();
    let startTime;
    
    switch (timeRange) {
      case 'hour':
        startTime = new Date(now.getTime() - 60 * 60 * 1000);
        break;
      case 'day':
        startTime = new Date(now.getTime() - 24 * 60 * 60 * 1000);
        break;
      case 'week':
        startTime = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
        break;
      case 'month':
        startTime = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
        break;
      default:
        startTime = new Date(now.getTime() - 60 * 60 * 1000);
    }
    
    const historicalData = documents
      .filter(doc => new Date(doc.updateDate) >= startTime)
      .map(doc => ({
        id: doc.id,
        timestamp: doc.updateDate,
        value: parseFloat(doc.fields?.data) || 0
      }))
      .sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));
    
    console.log(`✅ Returning ${historicalData.length} historical data points`);
    res.json(historicalData);
  } catch (error) {
    console.error('❌ Error fetching historical data:', error.message);
    res.status(500).json({ error: 'Failed to fetch historical data' });
  }
});

// Helper function to determine device status based on temperature
function determineDeviceStatus(temperature) {
  if (temperature > 45) return 'Critical';
  if (temperature > 35) return 'Warning';
  if (temperature > 0) return 'Online';
  return 'Offline';
}

module.exports = router;