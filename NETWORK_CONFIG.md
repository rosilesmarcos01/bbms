# BBMS Network Configuration

## Quick Setup

When you switch WiFi networks, simply run:

```bash
./update-ip.sh
```

This will:
1. Auto-detect your current IP address
2. Update all `.env` files in the project
3. Display the new service URLs

## Manual Configuration

If you prefer to update manually, edit the `HOST_IP` variable in these files:

- `.env` (root)
- `auth/.env`
- `backend/.env`
- `authid-web/.env`

### Find Your IP Address

**macOS:**
```bash
ipconfig getifaddr en0
```

**Linux:**
```bash
hostname -I | awk '{print $1}'
```

**Windows:**
```bash
ipconfig
# Look for "IPv4 Address" under your active network adapter
```

## Service URLs

After updating the IP, your services will be accessible at:

| Service | Port | URL |
|---------|------|-----|
| Backend | 3000 | `http://YOUR_IP:3000` |
| Auth | 3001 | `http://YOUR_IP:3001` |
| AuthID Web | 3002 | `http://YOUR_IP:3002` |

## iOS App Configuration

Update the base URL in your iOS app to match your current IP:

```swift
// In your API configuration or AuthService
let baseURL = "http://YOUR_IP:3001"
```

Or use environment-based configuration:

```swift
#if DEBUG
let baseURL = "http://192.168.1.100:3001" // Your current IP
#else
let baseURL = "https://api.yourdomain.com" // Production
#endif
```

## Testing Network Access

### From Your Mac

```bash
# Test auth service
curl http://localhost:3001/health

# Test AuthID web
curl http://localhost:3002/health
```

### From Your iPhone

1. Make sure iPhone and Mac are on the **same WiFi network**
2. Open Safari on iPhone
3. Navigate to: `http://YOUR_IP:3002`
4. You should see the AuthID enrollment page

## Troubleshooting

### Services not accessible from iPhone

**Check firewall:**
```bash
# macOS - Allow incoming connections
# System Preferences > Security & Privacy > Firewall > Firewall Options
# Ensure Node.js is allowed
```

**Verify same network:**
- iPhone and Mac must be on the same WiFi
- Corporate networks may block device-to-device communication

**Test connectivity:**
```bash
# On your Mac
ping YOUR_IPHONE_IP

# On iPhone (using a terminal app)
ping YOUR_MAC_IP
```

### Wrong IP detected

If the script detects the wrong interface:

```bash
# List all network interfaces
ifconfig

# Manually specify IP
./update-ip.sh
# Then enter your IP when prompted
```

### Environment variables not expanding

Some shells don't expand `${HOST_IP}` in `.env` files. If you see literal `${HOST_IP}` in logs:

**Option 1:** Use explicit IPs in .env
```env
HOST_IP=192.168.1.100
AUTH_SERVICE_URL=http://192.168.1.100:3001
```

**Option 2:** Use dotenv-expand package
```bash
npm install dotenv-expand
```

```javascript
require('dotenv-expand')(require('dotenv').config());
```

## Production Deployment

For production, use domain names instead of IPs:

```env
HOST_IP=yourdomain.com
AUTH_SERVICE_URL=https://auth.yourdomain.com
BACKEND_SERVICE_URL=https://api.yourdomain.com
AUTHID_WEB_URL=https://enroll.yourdomain.com
```

## Network Configurations

### Home Network
```env
HOST_IP=192.168.1.100
```

### Office Network
```env
HOST_IP=10.0.0.50
```

### Coffee Shop / Public WiFi
```env
HOST_IP=172.20.10.5
```

### Using Phone Hotspot
```env
HOST_IP=172.20.10.2
```

## Automated Updates

Add to your startup script:

```bash
#!/bin/bash
cd /path/to/bbms
./update-ip.sh
npm start
```

Or use a launch daemon / systemd service that detects network changes.
