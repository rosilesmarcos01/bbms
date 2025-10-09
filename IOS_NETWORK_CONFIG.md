# iOS App Network Configuration

## How It Works

The iOS app now uses a centralized configuration file: **`BBMS/Config/AppConfig.swift`**

This file contains a single `hostIP` variable that controls all service URLs:

```swift
struct AppConfig {
    static let hostIP = "192.168.100.9"
    static let authBaseURL = "http://\(hostIP):3001/api"
    static let backendBaseURL = "http://\(hostIP):3000/api"
    static let authIDWebURL = "http://\(hostIP):3002"
}
```

## When You Switch Networks

### 1. Run the update script
```bash
./update-ip.sh
```

This automatically updates:
- All `.env` files (backend services)
- `AppConfig.swift` (iOS app)

### 2. Rebuild the iOS app
In Xcode:
- Press `⌘ + B` (Build)
- Or run the app again

That's it! The app will now use the new IP address.

## Services Using AppConfig

- ✅ `AuthService.swift` - Login, authentication
- ✅ `BiometricAuthService.swift` - Biometric enrollment
- ✅ Other services can import and use `AppConfig.authBaseURL`

## Manual Update (if needed)

If you need to manually update the IP:

1. Open `BBMS/Config/AppConfig.swift`
2. Change this line:
   ```swift
   static let hostIP = "YOUR_NEW_IP"
   ```
3. Rebuild the app in Xcode

## Checking Current Configuration

The app prints the configuration on launch. Look for:

```
╔═══════════════════════════════════════╗
║     BBMS Configuration                ║
╠═══════════════════════════════════════╣
║ Host IP: 192.168.100.9                ║
║ Auth URL: http://192.168.100.9:3001/api
║ Backend URL: http://192.168.100.9:3000/api
║ AuthID Web: http://192.168.100.9:3002
║ Environment: DEBUG                    ║
╚═══════════════════════════════════════╝
```

To enable this, add to your app initialization:
```swift
// In BBMSApp.swift init()
AppConfig.printConfiguration()
```

## Why This Approach?

✅ **Single source of truth** - One place to update
✅ **Automatic updates** - Script updates everything
✅ **Type-safe** - Swift compiler catches errors
✅ **Easy debugging** - Print current config anytime
✅ **No hardcoded IPs** - All URLs derived from one variable

## Troubleshooting

### App still using old IP after update

**Cause:** Xcode is using cached build

**Solution:**
1. Clean build folder: `⌘ + Shift + K`
2. Rebuild: `⌘ + B`
3. Run again

### Services not reachable

**Check:**
1. iPhone and Mac on same WiFi
2. IP address is correct: `ipconfig getifaddr en0`
3. Services are running
4. Firewall allows connections

### Want to use different URLs per environment

Update `AppConfig.swift`:

```swift
struct AppConfig {
    static let hostIP: String = {
        #if DEBUG
        return "192.168.100.9" // Development
        #else
        return "api.production.com" // Production
        #endif
    }()
}
```

## Production Deployment

For production, use domain names:

```swift
static let hostIP = "api.yourdomain.com"
static let authBaseURL = "https://\(hostIP)/auth/api"
```

## Adding New Services

When adding new backend services, add them to `AppConfig.swift`:

```swift
struct AppConfig {
    static let hostIP = "192.168.100.9"
    static let authBaseURL = "http://\(hostIP):3001/api"
    static let backendBaseURL = "http://\(hostIP):3000/api"
    static let authIDWebURL = "http://\(hostIP):3002"
    
    // Add new service:
    static let rubidexBaseURL = "http://\(hostIP):8080/api"
}
```

Then use in your services:
```swift
private let baseURL = AppConfig.rubidexBaseURL
```
