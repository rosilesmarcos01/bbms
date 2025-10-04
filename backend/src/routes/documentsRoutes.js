const express = require('express');
const router = express.Router();
const rubidexService = require('../services/rubidexService');

// Get all documents from Rubidex blockchain
router.get('/all', async (req, res) => {
  try {
    console.log('📱 iOS app requesting all documents');
    const documents = await rubidexService.getAllDocuments();
    
    // Transform data to match iOS app expectations (RubidexAPIResponse structure)
    const response = {
      result: documents,
      latestDocument: documents.length > 0 ? 
        documents.reduce((latest, doc) => {
          const latestDate = new Date(latest.creation_date || latest.update_date);
          const docDate = new Date(doc.creation_date || doc.update_date);
          return docDate > latestDate ? doc : latest;
        }) : null,
      error: null
    };
    
    console.log(`✅ Returning ${documents.length} documents to iOS app`);
    res.json(response);
  } catch (error) {
    console.error('❌ Error fetching all documents:', error.message);
    res.status(500).json({ 
      result: [],
      latestDocument: null,
      error: error.message 
    });
  }
});

// Get documents for specific device
router.get('/device/:deviceId', async (req, res) => {
  try {
    const { deviceId } = req.params;
    console.log(`📱 iOS app requesting documents for device: ${deviceId}`);
    
    const documents = await rubidexService.getDeviceDocuments(deviceId);
    
    res.json({
      deviceId,
      documents,
      count: documents.length
    });
  } catch (error) {
    console.error(`❌ Error fetching documents for device ${req.params.deviceId}:`, error.message);
    res.status(500).json({ 
      error: 'Failed to fetch device documents',
      message: error.message 
    });
  }
});

//Test Rubidex connection
router.get('/test', async (req, res) => {
  try {
    console.log('🧪 Testing Rubidex connection from iOS app');
    const connectionTest = await rubidexService.testConnection();
    
    res.json({
      status: 'success',
      message: 'Rubidex connection test successful',
      connection: connectionTest,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('❌ Rubidex connection test failed:', error.message);
    res.status(500).json({ 
      status: 'error',
      error: 'Connection test failed',
      message: error.message 
    });
  }
});

// Post temperature alert document to Rubidex
router.post('/temperature-alert', async (req, res) => {
  try {
    const { deviceId, deviceName, currentTemp, limit, location, severity } = req.body;
    
    console.log('🚨 iOS app requesting temperature alert documentation');
    console.log('📋 REQUEST BODY RECEIVED:', JSON.stringify(req.body, null, 2));
    console.log(`   Device: ${deviceName} (${deviceId})`);
    console.log(`   Location: ${location}`);
    console.log(`   Temperature: ${currentTemp}°C > ${limit}°C`);
    console.log(`   Severity: ${severity}`);
    
    // Validate required fields
    if (!deviceId || !deviceName || currentTemp === undefined || limit === undefined || !location || !severity) {
      console.error('❌ Missing required fields:', {
        deviceId: !!deviceId,
        deviceName: !!deviceName,
        currentTemp: currentTemp !== undefined,
        limit: limit !== undefined,
        location: !!location,
        severity: !!severity
      });
      return res.status(400).json({
        status: 'error',
        error: 'Missing required fields',
        required: ['deviceId', 'deviceName', 'currentTemp', 'limit', 'location', 'severity']
      });
    }
    
    const alertDocument = await rubidexService.writeTemperatureAlert({
      deviceId,
      deviceName,
      currentTemp,
      limit,
      location,
      severity
    });
    
    console.log('✅ Temperature alert documented successfully');
    res.json({
      status: 'success',
      message: 'Temperature alert documented to blockchain',
      documentId: alertDocument.id || 'unknown',
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('❌ Error documenting temperature alert:', error.message);
    res.status(500).json({
      status: 'error',
      error: 'Failed to document temperature alert',
      message: error.message
    });
  }
});

// Post temperature alert resolution document to Rubidex
router.post('/temperature-alert-resolved', async (req, res) => {
  try {
    const { deviceId, deviceName } = req.body;
    
    console.log('✅ iOS app requesting temperature alert resolution documentation');
    console.log(`   Device: ${deviceName} (${deviceId})`);
    
    // Validate required fields
    if (!deviceId || !deviceName) {
      return res.status(400).json({
        status: 'error',
        error: 'Missing required fields',
        required: ['deviceId', 'deviceName']
      });
    }
    
    const resolutionDocument = await rubidexService.writeTemperatureAlertResolution({
      deviceId,
      deviceName
    });
    
    console.log('✅ Temperature alert resolution documented successfully');
    res.json({
      status: 'success',
      message: 'Temperature alert resolution documented to blockchain',
      documentId: resolutionDocument.id || 'unknown',
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('❌ Error documenting temperature alert resolution:', error.message);
    res.status(500).json({
      status: 'error',
      error: 'Failed to document temperature alert resolution',
      message: error.message
    });
  }
});

// Test endpoint to verify document format without actually sending to Rubidex
router.post('/test-alert-format', async (req, res) => {
  try {
    const { deviceId, deviceName, currentTemp, limit, location, severity } = req.body;
    
    console.log('🧪 Testing alert document format');
    
    const testDocument = {
      collection_id: process.env.RUBIDEX_TEMP_ALERT_COLLECTION_ID,
      fields: {
        date: new Date().toISOString(),
        event: `High temperature alert triggered on device ${deviceName} (${deviceId}) in ${location}. Current: ${currentTemp.toFixed(1)}°C, Limit: ${limit.toFixed(1)}°C`,
        issuer: deviceName,
        resolved: false,
        severity: severity
      }
    };
    
    console.log('📋 Test document that would be sent:', JSON.stringify(testDocument, null, 2));
    console.log('📋 Headers that would be sent:', {
      'Authorization': 'Key [HIDDEN]',
      'Content-Type': 'application/json',
      'clearance': '1'
    });
    
    res.json({
      status: 'success',
      message: 'Document format test completed',
      document: testDocument,
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('❌ Error in format test:', error.message);
    res.status(500).json({
      status: 'error',
      error: 'Format test failed',
      message: error.message
    });
  }
});

module.exports = router;