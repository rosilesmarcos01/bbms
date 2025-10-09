# ✅ iOS App Configuration Complete!

## What Changed

### ✅ Created Centralized Configuration
**File:** `BBMS/Config/AppConfig.swift`

This single file now controls all service URLs:
- Auth Service: `http://192.168.100.9:3001/api`
- Backend Service: `http://192.168.100.9:3000/api`
- AuthID Web: `http://192.168.100.9:3002`

### ✅ Updated Service Files
- **AuthService.swift** → Now uses `AppConfig.authBaseURL`
- **BiometricAuthService.swift** → Now uses `AppConfig.authBaseURL`

### ✅ Updated Automation Script
**`update-ip.sh`** now updates:
1. All backend `.env` files
2. iOS `AppConfig.swift` file
3. Shows you need to rebuild the iOS app

## Current Configuration

```
Host IP: 192.168.100.9

Service URLs:
- Auth:       http://192.168.100.9:3001/api
- Backend:    http://192.168.100.9:3000/api  
- AuthID Web: http://192.168.100.9:3002
```

## What You Need To Do

### 1. Add AppConfig.swift to Xcode (if not already)

In Xcode:
1. Right-click on the `BBMS` folder
2. Select "Add Files to BBMS..."
3. Navigate to: `BBMS/Config/AppConfig.swift`
4. Make sure "Copy items if needed" is **unchecked**
5. Click "Add"

### 2. Build the App

Press `⌘ + B` or click the Play button to build and run.

### 3. Test

Login to the app - it should now connect to `http://192.168.100.9:3001`

## When You Switch Networks

Just run one command:

```bash
./update-ip.sh
```

Then rebuild the iOS app in Xcode. Done! ✅

## Verification

To see the current configuration, the app should print on launch:

```
╔═══════════════════════════════════════╗
║     BBMS Configuration                ║
╠═══════════════════════════════════════╣
║ Host IP: 192.168.100.9                ║
║ Auth URL: http://192.168.100.9:3001/api
╚═══════════════════════════════════════╝
```

Check the Xcode console output when the app launches.

## Files Modified

- ✅ Created: `BBMS/Config/AppConfig.swift`
- ✅ Updated: `BBMS/Services/AuthService.swift`
- ✅ Updated: `BBMS/Services/BiometricAuthService.swift`  
- ✅ Updated: `update-ip.sh`
- ✅ Created: `IOS_NETWORK_CONFIG.md` (documentation)

## Ready to Test AuthID Enrollment!

Once the iOS app is rebuilt:

1. **Start services:**
   ```bash
   # Terminal 1
   cd auth && npm start
   
   # Terminal 2
   cd authid-web && npm install && npm start
   ```

2. **Login to iOS app**
   - Email: marcos@bbms.ai
   - Password: your password

3. **Start enrollment:**
   - Tap "Enable Biometric Authentication"
   - Tap "Open Enrollment Page"
   - Complete AuthID enrollment

The enrollment page will open at: `http://192.168.100.9:3002?operationId=xxx&secret=xxx`

🎉 Everything is now configured with environment variables!
