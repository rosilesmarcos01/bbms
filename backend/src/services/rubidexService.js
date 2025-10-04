const axios = require('axios');

class RubidexService {
  constructor() {
    this.baseURL = process.env.RUBIDEX_API_URL;
    this.collectionId = process.env.RUBIDEX_COLLECTION_ID;
    this.apiKey = process.env.RUBIDEX_API_KEY;
    
    // Create axios instance with default config
    this.client = axios.create({
      baseURL: this.baseURL,
      timeout: 30000,
      headers: {
        'Authorization': `Key ${this.apiKey}`,
        'Content-Type': 'application/json'
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
      
      const documents = response.data || [];
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
      
      // Group by device and get latest reading
      const deviceReadings = {};
      
      allDocuments
        .filter(doc => doc.fields?.device_type === 'temperature_sensor' || !doc.fields?.device_type)
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
}

module.exports = new RubidexService();