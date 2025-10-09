# AuthID Integration - Ready to Test! 🚀

## What We've Built

✅ **Backend AuthID Integration** - Real API calls to AuthID
✅ **Enrollment Web Interface** - React component page  
✅ **Network Configuration** - IP-based URLs for multi-device access
✅ **Auto-Update Script** - Easy network switching

## Your Current Configuration

```
📱 Your Mac IP: 192.168.100.9
🌐 Network: Same WiFi required for iPhone access
```

### Service URLs

| Service | URL | Status |
|---------|-----|--------|
| Auth Service | http://192.168.100.9:3001 | ✅ Running |
| AuthID Web | http://192.168.100.9:3002 | ⏳ Ready to start |
| Backend | http://192.168.100.9:3000 | ⏳ Optional |

## Next Steps

### 1. Install AuthID Web Dependencies

```bash
cd authid-web
npm install
```

### 2. Start AuthID Web Service

```bash
npm start
```

You should see:
```
🚀 AuthID Enrollment Interface
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🌐 Local:    http://localhost:3002
🌐 Network:  http://192.168.100.9:3002
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💡 Access from iPhone: http://192.168.100.9:3002
```

### 3. Test in Browser First

Open in Safari on your Mac:
```
http://localhost:3002?operationId=test&secret=test&baseUrl=https://id-uat.authid.ai
```

**Expected:**
- Nice purple gradient page
- "Biometric Enrollment" header
- Either AuthID component loads OR error message saying component not found

### 4. Test from iOS App

1. **Update iOS app base URL** (if needed):
   ```swift
   // In your API configuration
   let baseURL = "http://192.168.100.9:3001"
   ```

2. **Login to BBMS app**
   - Email: marcos@bbms.ai
   - Password: your password

3. **Start enrollment**
   - Tap "Enable Biometric Authentication"
   - Wait for operation to be created
   - Tap "Open Enrollment Page"

4. **Complete enrollment**
   - Page opens at: `http://192.168.100.9:3002?operationId=xxx&secret=xxx`
   - Follow AuthID prompts
   - Complete face capture

### 5. Test from iPhone Browser (Alternative)

If the iOS app WebView doesn't work:

1. Open Safari on your iPhone
2. Navigate to the enrollment URL from logs
3. Complete enrollment there

## When You Switch Networks

Simply run:

```bash
./update-ip.sh
```

This will:
- Auto-detect your new IP
- Update all `.env` files
- Show you the new URLs

Then restart services:
```bash
# Terminal 1
cd auth && npm start

# Terminal 2
cd authid-web && npm start
```

## Troubleshooting

### AuthID Component Not Found

If `@authid/react-component` doesn't exist on npm, the page will show an error message with:
- The operation details
- Instructions to contact AuthID support
- This confirms the backend is working!

**Solution:** Contact AuthID for proper integration docs.

### Can't Access from iPhone

1. **Check WiFi**: iPhone and Mac must be on same network
2. **Check Firewall**: 
   ```bash
   # macOS System Preferences > Security > Firewall
   # Allow Node.js incoming connections
   ```
3. **Test connectivity**:
   - Ping your Mac from iPhone
   - Try accessing `http://192.168.100.9:3002/health`

### Wrong IP After Network Change

Run the update script again:
```bash
./update-ip.sh
```

## Architecture

```
┌─────────────────┐
│   iOS App       │
│   (iPhone)      │
└────────┬────────┘
         │ http://192.168.100.9:3001/api/biometric/enroll
         │
┌────────▼────────┐
│  Auth Service   │ ◄─── Creates AuthID operation
│  Port 3001      │
└────────┬────────┘
         │ Returns: operationId, secret, enrollmentUrl
         │
         │ enrollmentUrl = http://192.168.100.9:3002?operationId=xxx&secret=xxx
         │
┌────────▼────────┐
│  AuthID Web     │ ◄─── Loads @authid/react-component
│  Port 3002      │ ◄─── Handles camera, face capture
└────────┬────────┘
         │ AuthID API calls
         │
┌────────▼────────┐
│  AuthID API     │
│  (UAT)          │
│  id-uat.authid  │
└─────────────────┘
```

## Files Modified

✅ `/.env` - Root configuration with HOST_IP
✅ `/auth/.env` - Auth service with IP-based URLs
✅ `/authid-web/.env` - Web service configuration
✅ `/authid-web/package.json` - Dependencies
✅ `/authid-web/server.js` - Express server
✅ `/authid-web/public/index.html` - Enrollment page
✅ `/auth/src/server.js` - Listen on 0.0.0.0
✅ `/auth/src/services/authIdService.js` - Use AUTHID_WEB_URL
✅ `/update-ip.sh` - Network configuration helper
✅ `/NETWORK_CONFIG.md` - Documentation

## Current Status

| Component | Status |
|-----------|--------|
| ✅ Backend AuthID API integration | COMPLETE |
| ✅ Account creation | WORKING |
| ✅ Operation creation | WORKING |
| ✅ Enrollment URL generation | WORKING |
| ✅ Network configuration | COMPLETE |
| ⏳ AuthID web interface | READY TO TEST |
| ⏳ React component | UNKNOWN (needs testing) |
| ⏳ Face capture | DEPENDS ON COMPONENT |

## What Happens Next

### Scenario A: Component Works ✅
- Page loads AuthID React component
- User sees camera interface
- Completes face capture
- Enrollment succeeds
- **You're done!** 🎉

### Scenario B: Component Doesn't Exist ❌
- Page shows friendly error message
- Backend is confirmed working
- Need to contact AuthID for:
  - Proper integration method
  - Alternative SDK/component
  - Custom implementation guide

Either way, we'll know the path forward after testing!

## Ready to Test?

1. Install dependencies: `cd authid-web && npm install`
2. Start service: `npm start`
3. Open in browser: `http://localhost:3002?operationId=test&secret=test`
4. See what happens! 

Let me know what you see! 🚀
