# Quick Setup Guide: Temperature Alert Documentation

## 1. Backend Configuration

The system now automatically handles API keys through the backend server. No user configuration required!

### Backend Setup:
1. Ensure the backend server is running on `http://192.168.100.4:3000`
2. API key is automatically loaded from `.env` file in the backend
3. Collection ID for temperature alerts: `1cc28e7bf898051430ed27bd83ffaef825d1b5bcc6a3720ea149191ed9a61c81`

## 2. Test the System

### Option A: Using Test Interface
1. In Settings, go to **Developer Tools** → **Test Notifications**
2. Scroll to **"Test Rubidex Documentation"** section
3. Verify backend status shows **"🟢 Connected via Backend"**
4. Tap **"📄 Test Alert Documentation"**
5. Check console logs for success confirmation

### Option B: Using Real Device
1. Go to **Dashboard** → Select a temperature device
2. Tap **"Device Details"**
3. Set temperature limit (e.g., 40°C)
4. In the **"Simulate Reading"** section, enter a value above the limit
5. Tap **"Update Reading"**
6. Verify alert is created and documented

## 3. Verify Documentation

Check console logs for these messages:
```
🚨 Writing temperature alert document via backend...
📊 Backend API response status: 200
✅ Temperature alert document successfully written via backend to Rubidex blockchain
```

## 4. Test Alert Resolution

1. Go to **Alerts** tab
2. Find a temperature alert
3. Tap the alert → **"Mark as Resolved"**
4. Check console logs for resolution documentation

## Alert Schema

Each documented alert contains:
- **date**: Unix timestamp
- **event**: Alert description
- **severity**: low/moderate/high/critical
- **issuer**: Device name
- **resolved**: true/false

## Backend Endpoints

- **POST** `/api/documents/temperature-alert` - Document new alert
- **POST** `/api/documents/temperature-alert-resolved` - Document alert resolution

## Troubleshooting

**Backend Connection Issues:**
- Ensure backend server is running on port 3000
- Check that `.env` file contains the API key
- Verify network connectivity to backend

**No console logs:**
- Ensure you're running in debug mode
- Check that temperature exceeds the configured limit
- Verify backend endpoints are responding