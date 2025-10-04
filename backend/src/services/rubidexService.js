const axios = require('axios');

class RubidexService {
  constructor() {
    this.baseURL = process.env.RUBIDEX_API_URL;
    this.collectionId = process.env.RUBIDEX_COLLECTION_ID;
    this.apiKey = process.env.RUBIDEX_API_KEY;
    
    // Debug log environment variables
    console.log('🔧 RubidexService Configuration:');
    console.log('  Base URL:', this.baseURL);
    console.log('  Collection ID:', this.collectionId);
    console.log('  Temp Alert Collection ID:', process.env.RUBIDEX_TEMP_ALERT_COLLECTION_ID);
    console.log('  API Key set:', !!this.apiKey);
    console.log('  API Key length:', this.apiKey ? this.apiKey.length : 0);
    
    // Create axios instance with default config including clearance header
    this.client = axios.create({
      baseURL: this.baseURL,
      timeout: 30000,
      headers: {
        'Authorization': `Key ${this.apiKey}`,
        'Content-Type': 'application/json',
        'clearance': '1'
      }
    });
  }

  // Test connection to Rubidex
  async testConnection() {
    try {
      const response = await this.client.get(`/all?collection-id=${this.collectionId}`);
      return { success: true, documentsCount: response.data?.length || 0 };
    } catch (error) {
      throw new Error(`Rubidex connection failed: ${error.message}`);
    }
  }

  // Get all documents from blockchain
  async getAllDocuments() {
    try {
      console.log('📖 Fetching all documents from Rubidex blockchain...');
      const response = await this.client.get(`/all?collection-id=${this.collectionId}`);
      
      // Check if response.data is already the array or if it's wrapped
      let documents;
      if (Array.isArray(response.data)) {
        documents = response.data;
      } else if (response.data && Array.isArray(response.data.result)) {
        documents = response.data.result;
      } else {
        documents = [];
      }
      
      console.log(`✅ Retrieved ${documents.length} documents from blockchain`);
      
      return documents;
    } catch (error) {
      console.error('❌ Error fetching documents from Rubidex:', error.message);
      throw error;
    }
  }

  // Write new temperature reading to blockchain
  async writeTemperatureReading(deviceData) {
    try {
      console.log('📝 Writing temperature reading to blockchain:', deviceData);
      
      const document = {
        collectionId: this.collectionId,
        fields: {
          coreid: deviceData.deviceId,
          name: deviceData.deviceName || `Temperature Reading`,
          data: deviceData.temperature.toString(),
          published_at: new Date().toISOString(),
          ttl: deviceData.ttl || 3600, // 1 hour default
          location: deviceData.location,
          device_type: 'temperature_sensor',
          alert_limit: deviceData.alertLimit,
          timestamp: Date.now()
        }
      };

      const response = await this.client.post('/', document);
      console.log('✅ Temperature reading written to blockchain');
      
      return response.data;
    } catch (error) {
      console.error('❌ Error writing to Rubidex:', error.message);
      throw error;
    }
  }

  // Write device configuration to blockchain
  async writeDeviceConfig(deviceConfig) {
    try {
      console.log('📝 Writing device config to blockchain:', deviceConfig);
      
      const document = {
        collectionId: this.collectionId,
        fields: {
          coreid: deviceConfig.deviceId,
          name: `Device Config: ${deviceConfig.name}`,
          data: JSON.stringify(deviceConfig),
          published_at: new Date().toISOString(),
          ttl: 86400, // 24 hours
          device_type: 'device_config',
          timestamp: Date.now()
        }
      };

      const response = await this.client.post('/', document);
      console.log('✅ Device config written to blockchain');
      
      return response.data;
    } catch (error) {
      console.error('❌ Error writing device config to Rubidex:', error.message);
      throw error;
    }
  }

  // Write alert to blockchain for audit trail
  async writeAlert(alertData) {
    try {
      console.log('🚨 Writing alert to blockchain:', alertData);
      
      const document = {
        collectionId: this.collectionId,
        fields: {
          coreid: alertData.deviceId,
          name: `Alert: ${alertData.title}`,
          data: JSON.stringify({
            severity: alertData.severity,
            message: alertData.message,
            temperature: alertData.temperature,
            limit: alertData.limit
          }),
          published_at: new Date().toISOString(),
          ttl: 604800, // 7 days
          device_type: 'alert',
          alert_severity: alertData.severity,
          timestamp: Date.now()
        }
      };

      const response = await this.client.post('/', document);
      console.log('✅ Alert written to blockchain');
      
      return response.data;
    } catch (error) {
      console.error('❌ Error writing alert to Rubidex:', error.message);
      throw error;
    }
  }

  // Get documents for specific device
  async getDeviceDocuments(deviceId) {
    try {
      const allDocuments = await this.getAllDocuments();
      return allDocuments.filter(doc => 
        doc.fields?.coreid === deviceId
      );
    } catch (error) {
      console.error(`❌ Error getting documents for device ${deviceId}:`, error.message);
      throw error;
    }
  }

    // Get latest temperature readings for all devices
  async getLatestTemperatures() {
    try {
      const allDocuments = await this.getAllDocuments();
      
      // Group by device ID and get the most recent reading for each
      const deviceReadings = {};
      allDocuments
        .filter(doc => doc.fields?.device_type === 'temperature_sensor')
        .forEach(doc => {
          const deviceId = doc.fields?.coreid;
          const timestamp = new Date(doc.updateDate || doc.creationDate);
          
          if (!deviceReadings[deviceId] || timestamp > new Date(deviceReadings[deviceId].timestamp)) {
            deviceReadings[deviceId] = {
              deviceId,
              temperature: parseFloat(doc.fields?.data) || 0,
              timestamp: timestamp.toISOString(),
              location: doc.fields?.location,
              name: doc.fields?.name
            };
          }
        });
      
      return Object.values(deviceReadings);
    } catch (error) {
      console.error('❌ Error getting latest temperatures:', error.message);
      throw error;
    }
  }

  // Write temperature alert document to blockchain
  async writeTemperatureAlert(alertData) {
    try {
      console.log('🚨 Writing temperature alert to blockchain:', alertData);
      
      const document = {
        collection_id: process.env.RUBIDEX_TEMP_ALERT_COLLECTION_ID || this.collectionId,
        fields: {
          date: new Date().toISOString(),
          event: `High temperature alert triggered on device ${alertData.deviceName} (${alertData.deviceId}) in ${alertData.location}. Current: ${alertData.currentTemp.toFixed(1)}°C, Limit: ${alertData.limit.toFixed(1)}°C`,
          issuer: alertData.deviceName,
          resolved: false, // Boolean, not string
          severity: alertData.severity
        }
      };

      // Log the complete request details
      console.log('📡 FULL REQUEST DETAILS:');
      console.log('  URL:', this.baseURL);
      console.log('  Method: POST');
      console.log('  Headers:', {
        'Authorization': `Key ${this.apiKey ? '[HIDDEN]' : 'NOT_SET'}`,
        'Content-Type': 'application/json',
        'clearance': '1'
      });
      console.log('  Body:', JSON.stringify(document, null, 2));
      console.log('  Collection ID being used:', process.env.RUBIDEX_TEMP_ALERT_COLLECTION_ID || this.collectionId);
      console.log('  API Key set:', !!this.apiKey);
      console.log('  Base URL:', this.baseURL);

      const response = await this.client.post('/', document);
      console.log('✅ Temperature alert written to blockchain');
      
      return response.data;
    } catch (error) {
      console.error('❌ Error writing temperature alert to Rubidex:', error.message);
      
      // Log detailed error information
      if (error.response) {
        console.error('📋 ERROR RESPONSE DETAILS:');
        console.error('  Status:', error.response.status);
        console.error('  Status Text:', error.response.statusText);
        console.error('  Headers:', error.response.headers);
        console.error('  Data:', error.response.data);
      } else if (error.request) {
        console.error('📋 ERROR REQUEST DETAILS:');
        console.error('  Request was made but no response received');
        console.error('  Request:', error.request);
      } else {
        console.error('📋 ERROR SETUP DETAILS:');
        console.error('  Error in setting up request:', error.message);
      }
      
      throw error;
    }
  }

  // Write temperature alert resolution document to blockchain
  async writeTemperatureAlertResolution(resolutionData) {
    try {
      console.log('✅ Writing temperature alert resolution to blockchain:', resolutionData);
      
      const document = {
        collection_id: process.env.RUBIDEX_TEMP_ALERT_COLLECTION_ID || this.collectionId,
        fields: {
          date: new Date().toISOString(),
          event: `Temperature alert resolved for device ${resolutionData.deviceName} (${resolutionData.deviceId}). Temperature returned to normal levels.`,
          issuer: resolutionData.deviceName,
          resolved: true, // Boolean for resolved
          severity: 'info'
        }
      };

      const response = await this.client.post('/', document);
      console.log('✅ Temperature alert resolution written to blockchain');
      
      return response.data;
    } catch (error) {
      console.error('❌ Error writing temperature alert resolution to Rubidex:', error.message);
      throw error;
    }
  }
}

module.exports = new RubidexService();