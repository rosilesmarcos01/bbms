#!/usr/bin/env node

// Test script to verify Rubidex document format
const axios = require('axios');

async function testDocumentFormat() {
  const document = {
    collection_id: "1cc28e7bf898051430ed27bd83ffaef825d1b5bcc6a3720ea149191ed9a61c81",
    fields: {
      date: new Date().toISOString(),
      event: "Test temperature alert triggered on device Test Sensor (test-123) in Test Lab. Current: 45.5°C, Limit: 40.0°C",
      issuer: "Test Sensor",
      resolved: false,
      severity: "high"
    }
  };

  console.log('🧪 Testing document format:');
  console.log(JSON.stringify(document, null, 2));

  try {
    const response = await axios.post('https://app.rubidex.ai/api/v1/chaincode/document', document, {
      headers: {
        'Authorization': 'Key 22d9eef8-9d41-4251-bcf0-3f09b4023085',
        'Content-Type': 'application/json',
        'clearance': '1'
      },
      timeout: 30000
    });

    console.log('✅ Success! Response:', response.data);
  } catch (error) {
    console.error('❌ Error:', error.response?.data || error.message);
  }
}

testDocumentFormat();