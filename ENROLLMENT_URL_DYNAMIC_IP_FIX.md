# Enrollment URL Dynamic IP Fix

## Overview
Updated the enrollment URL generation to use the dynamic IP address from `update-ip.sh` script, ensuring that the enrollment URL always points to the correct network address.

## Problem
The enrollment URL was using a hardcoded IP address (`192.168.100.9`) in the auth service's `.env` file, which caused issues when switching networks. When users ran the `update-ip.sh` script, the enrollment URL wasn't being updated because:
1. The script only updated HTTP URLs, not HTTPS URLs
2. The `AUTHID_WEB_URL` had a hardcoded IP address

## Solution

### 1. Updated `update-ip.sh` Script
**File**: `/Users/marcosrosiles/WORK/MR-INTEL/bbms/update-ip.sh`

Added support for updating HTTPS URLs in addition to HTTP URLs:

```bash
# Update all service URLs with the new IP (both HTTP and HTTPS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|http://[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}:|http://$DETECTED_IP:|g" "$ENV_FILE"
    sed -i '' "s|https://[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}:|https://$DETECTED_IP:|g" "$ENV_FILE"
else
    sed -i "s|http://[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}:|http://$DETECTED_IP:|g" "$ENV_FILE"
    sed -i "s|https://[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}:|https://$DETECTED_IP:|g" "$ENV_FILE"
fi
```

### 2. Updated `.env` Files

#### Root `.env`
**File**: `/Users/marcosrosiles/WORK/MR-INTEL/bbms/.env`

Updated service URLs to use HTTPS where appropriate:
```properties
AUTH_SERVICE_URL=https://${HOST_IP}:3001
BACKEND_SERVICE_URL=http://${HOST_IP}:3000
AUTHID_WEB_URL=https://${HOST_IP}:3002
```

#### Auth Service `.env`
**File**: `/Users/marcosrosiles/WORK/MR-INTEL/bbms/auth/.env`

Changed from hardcoded IP to dynamic HOST_IP:
```properties
# Before
AUTHID_WEB_URL=https://192.168.100.9:3002

# After
AUTHID_WEB_URL=https://10.10.62.45:3002
```

Also updated AUTH_SERVICE_URL to use HTTPS:
```properties
AUTH_SERVICE_URL=https://10.10.62.45:3001
```

#### Backend Service `.env`
**File**: `/Users/marcosrosiles/WORK/MR-INTEL/bbms/backend/.env`

Updated AUTH_SERVICE_URL from localhost to use HOST_IP with HTTPS:
```properties
# Before
AUTH_SERVICE_URL=http://localhost:3001

# After
HOST_IP=10.10.62.45
AUTH_SERVICE_URL=https://10.10.62.45:3001
```

## How It Works

### Enrollment URL Flow
1. **iOS App** → Calls `AuthService.initiateBiometricEnrollment()`
2. **Auth Service** → Receives request at `/biometric/enroll`
3. **AuthID Service** → `initiateBiometricEnrollment()` function (line 561)
   ```javascript
   const enrollmentWebUrl = process.env.AUTHID_WEB_URL || 'http://localhost:3002';
   const enrollmentUrl = `${enrollmentWebUrl}?operationId=${operationId}&secret=${oneTimeSecret}&baseUrl=${encodeURIComponent('https://id-uat.authid.ai')}`;
   ```
4. **Response** → Returns enrollment URL to iOS app
5. **iOS App** → Opens enrollment URL in Safari

### Network Update Process
When you run `./update-ip.sh`:
1. Detects current IP address
2. Updates `HOST_IP` in all `.env` files
3. Updates all HTTP URLs with new IP
4. Updates all HTTPS URLs with new IP (NEW)
5. Updates iOS `AppConfig.swift` with new IP
6. Creates backups of all modified files

## Testing

### 1. Test IP Update Script
```bash
./update-ip.sh
```

Verify that all `.env` files are updated with the new IP address.

### 2. Test Enrollment URL
1. Restart auth service:
   ```bash
   cd auth && npm start
   ```

2. Check the auth service logs to see the `AUTHID_WEB_URL` value

3. In iOS app, initiate biometric enrollment

4. Verify the enrollment URL uses the correct IP address

### 3. Verify Dynamic URLs
Check that all these URLs match your current HOST_IP:
- Backend: `http://[HOST_IP]:3000`
- Auth: `https://[HOST_IP]:3001`
- AuthID Web: `https://[HOST_IP]:3002`

## Files Modified

1. **update-ip.sh** - Added HTTPS URL updating
2. **.env** - Updated service URLs to use HTTPS
3. **auth/.env** - Fixed hardcoded IP, added HTTPS
4. **backend/.env** - Changed from localhost to HOST_IP, added HTTPS

## Benefits

✅ **Automatic Updates** - Running `update-ip.sh` now updates enrollment URLs
✅ **Network Switching** - No manual .env file editing required
✅ **Consistency** - All services use the same dynamic IP
✅ **HTTPS Support** - Secure connections for auth and enrollment
✅ **iOS Integration** - AppConfig.swift stays in sync with .env files

## Important: CORS Configuration

The ALLOWED_ORIGINS in `auth/.env` needs to include the dynamic IP for the authid-web service to communicate with the auth service:

```properties
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080,https://10.10.62.45:3002,https://localhost:3002
```

When running `./update-ip.sh`, the script will automatically update the HTTPS URL in this line.

## Preventing "One Moment Please" Freeze

The authid-web interface polls the auth service to check enrollment completion status:

1. **During enrollment**, the web page at `https://[HOST_IP]:3002` calls:
   - `https://[HOST_IP]:3001/api/biometric/operation/{operationId}/status` (every 2 seconds)
   - `https://[HOST_IP]:3001/api/biometric/operation/{operationId}/complete` (when done)

2. **CORS must be configured** to allow these requests:
   - The `ALLOWED_ORIGINS` in `auth/.env` must include the authid-web URL
   - The update-ip.sh script now updates this automatically

3. **The iOS app checks status** after Safari closes:
   - Calls `authService.checkBiometricEnrollmentStatus()`
   - Waits 1 second then checks if `isEnrolled == true`
   - Shows success alert and dismisses the enrollment view

## Troubleshooting "Stuck on One Moment Please"

If users get stuck after taking their selfie:

1. **Check CORS**: Verify `ALLOWED_ORIGINS` in `auth/.env` includes current HOST_IP
2. **Check Network**: Both auth service (3001) and authid-web (3002) must be accessible
3. **Check Logs**: 
   - Auth service logs: `auth/logs/`
   - Browser console: Safari → Develop → [Device] → [Page]
4. **Check Certificates**: HTTPS must have valid certificates (localhost-cert.pem)

## Next Steps

Whenever you switch networks:
1. Run `./update-ip.sh`
2. Verify the CORS configuration in `auth/.env` was updated
3. Restart all services (auth, backend, authid-web)
4. Rebuild iOS app in Xcode (AppConfig.swift updated)
5. Test the enrollment flow completely

The enrollment URL will automatically use the new IP address! 🎉
