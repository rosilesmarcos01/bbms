# Temperature Alert Documentation System

This document describes the automatic temperature alert documentation system that writes alert events to the Rubidex blockchain via the backend server.

## Overview

When a temperature alert is triggered by any temperature device in the BBMS system, the alert details are automatically documented to the Rubidex blockchain using a backend API that handles authentication and API key management.

## Architecture

The system now uses a **backend-mediated approach**:

1. **iOS App** → **Backend Server** → **Rubidex API**
2. API keys are stored securely in the backend's `.env` file
3. No user configuration required for API keys
4. All authentication handled by backend

## Alert Documentation Schema

Each temperature alert document contains the following fields:

```json
{
  "collection_id": "1cc28e7bf898051430ed27bd83ffaef825d1b5bcc6a3720ea149191ed9a61c81",
  "fields": {
    "date": <unix_timestamp>,
    "event": "<description>",
    "severity": "<level>",
    "issuer": "<device_name>",
    "resolved": <boolean>
  }
}
```

### Field Descriptions

- **date**: Unix timestamp of when the alert was triggered
- **event**: Human-readable description of the alert event
- **severity**: Alert severity level (low, moderate, high, critical)
- **issuer**: Name of the device that triggered the alert
- **resolved**: Boolean flag indicating if the alert has been resolved (defaults to false)

## Backend API Endpoints

### POST `/api/documents/temperature-alert`
Documents a new temperature alert to the blockchain.

**Request Body:**
```json
{
  "deviceId": "string",
  "deviceName": "string", 
  "currentTemp": number,
  "limit": number,
  "location": "string",
  "severity": "string"
}
```

### POST `/api/documents/temperature-alert-resolved`
Documents the resolution of a temperature alert.

**Request Body:**
```json
{
  "deviceId": "string",
  "deviceName": "string"
}
```

## Backend Configuration

### Environment Variables (.env)
```bash
RUBIDEX_API_URL=https://app.rubidex.ai/api/v1/chaincode/document
RUBIDEX_API_KEY=your_api_key_here
RUBIDEX_TEMP_ALERT_COLLECTION_ID=1cc28e7bf898051430ed27bd83ffaef825d1b5bcc6a3720ea149191ed9a61c81
```

## Severity Levels

The system automatically determines severity based on how much the temperature exceeds the limit:

- **low**: 0-2°C above limit
- **moderate**: 2-5°C above limit  
- **high**: 5-10°C above limit
- **critical**: 10°C+ above limit

## Alert Triggers

Temperature alerts are automatically documented in the following scenarios:

### 1. Real-time Monitoring Alerts
- Triggered by the GlobalTemperatureMonitor during periodic checks
- Occurs when temperature readings exceed configured limits
- Automatic notification + Rubidex documentation

### 2. Manual Alert Creation
- Triggered when users manually simulate temperature readings in DeviceDetailView
- Occurs when simulated temperature exceeds the device's configured limit
- Manual alert creation + Rubidex documentation

### 3. Background Monitoring Alerts
- Triggered by the BackgroundMonitoringService
- Occurs when app detects temperature issues while running in background
- Background notification + Rubidex documentation

## Alert Resolution

When an alert is marked as resolved in the AlertService:

1. The local alert status is updated to `resolved: true`
2. A resolution document is automatically written to Rubidex
3. Resolution document contains:
   - Timestamp of resolution
   - Event description indicating resolution
   - Severity: "info"
   - Resolved: true

## API Configuration

### Setting Up Rubidex API Key

1. Navigate to Settings in the BBMS app
2. Find the "Rubidex API Configuration" section
3. Enter your Rubidex API key
4. Tap "Save API Key"

The API key is stored locally and used for all subsequent API calls to the Rubidex blockchain.

### API Endpoint

- **URL**: `https://app.rubidex.ai/api/v1/chaincode/document`
- **Method**: POST
- **Headers**:
  - `Authorization: Key <api_key>`
  - `clearance: 1`
  - `Content-Type: application/json`

## Testing the System

### Using the Notification Test View

1. Open Settings → Developer Tools → Test Notifications
2. Scroll to "Test Rubidex Documentation" section
3. Ensure API key status shows "🟢 Configured"
4. Tap "📄 Test Alert Documentation"

### Manual Testing Steps

1. Set up a temperature device with a limit (e.g., 40°C)
2. Simulate a temperature reading above the limit
3. Verify that:
   - Local alert is created
   - Push notification is sent
   - Rubidex document is written (check console logs)
4. Mark the alert as resolved
5. Verify that resolution document is written to Rubidex

## Error Handling

The system includes comprehensive error handling:

- **API Key Missing**: Alert documentation is skipped with warning log
- **Network Errors**: Logged but do not prevent local alert creation
- **Authentication Errors**: Logged with specific HTTP status codes
- **Invalid Responses**: Parsed and logged for debugging

## Console Logging

The system provides detailed console logs for monitoring:

```
🚨 Writing temperature alert document to Rubidex...
   Device: Sensor Name (device-id)
   Location: Building Location
   Temperature: 45.5°C
   Limit: 40.0°C
   Severity: high
📊 Rubidex API response status: 200
✅ Temperature alert document successfully written to Rubidex blockchain
```

## Security Considerations

### Production Deployment

For production use, consider implementing:

1. **Keychain Storage**: Store API keys in iOS Keychain instead of UserDefaults
2. **API Key Rotation**: Implement periodic API key rotation
3. **Certificate Pinning**: Add SSL certificate pinning for Rubidex API calls
4. **Request Encryption**: Consider additional encryption for sensitive data

### Development vs Production

Currently, the system stores API keys in UserDefaults for ease of development. The code includes comments indicating where to implement more secure storage mechanisms for production deployment.

## Integration Points

### Services Involved

1. **RubidexService**: Main service handling API calls to Rubidex
2. **NotificationService**: Triggers documentation when sending alerts
3. **AlertService**: Triggers documentation when resolving alerts
4. **GlobalTemperatureMonitor**: Monitors temperature readings and triggers alerts
5. **BackgroundMonitoringService**: Handles background temperature monitoring

### Views Involved

1. **SettingsView**: API key configuration interface
2. **NotificationTestView**: Testing and validation interface
3. **DeviceDetailView**: Manual alert creation interface

## Future Enhancements

Potential improvements to the system:

1. **Bulk Documentation**: Support for documenting multiple alerts in a single API call
2. **Offline Queue**: Queue alerts for documentation when network is unavailable
3. **Document Retrieval**: Query and display documented alerts from Rubidex
4. **Advanced Filtering**: Filter and search documented alerts by various criteria
5. **Analytics Dashboard**: Visualize alert patterns and trends from Rubidex data
6. **Webhook Support**: Configure webhooks for real-time alert notifications