# Biometric Login Guide 🔐

## Overview
Now that your biometric enrollment is complete, you can use Face ID or Touch ID to log into the BBMS app without entering your email and password!

## How Biometric Login Works

### The Flow:
```
1. Open BBMS App (Login Screen)
   ↓
2. See "Sign in with Face ID/Touch ID" button (gold/yellow color)
   ↓
3. Tap the button
   ↓
4. Device prompts for Face ID/Touch ID
   ↓
5. Authenticate with your face/fingerprint
   ↓
6. App verifies with AuthID backend
   ↓
7. ✅ Logged in successfully!
```

### Technical Details:

#### Step 1: Local Biometric Authentication
- iOS uses LocalAuthentication framework
- Face ID or Touch ID prompt appears
- User authenticates on device

#### Step 2: Generate Biometric Template
- App creates secure biometric verification data
- Includes: device ID, timestamp, biometric type
- Encrypted using SHA256 hash

#### Step 3: Send to Backend
- POST request to: `/api/auth/biometric-login`
- Includes verification data and device info

#### Step 4: Backend Verification
- Identifies user from biometric template
- Verifies with AuthID.ai (if integrated)
- Generates JWT access & refresh tokens
- Logs the biometric login event

#### Step 5: Login Complete
- App receives tokens and user data
- Updates UI to show authenticated state
- User is logged in!

## Testing Biometric Login

### Prerequisites:
✅ Biometric enrollment completed (green checkmark in Settings)
✅ Face ID or Touch ID enabled on your device
✅ Auth service running (`cd auth && npm start`)
✅ Backend service running (`cd backend && npm start`)

### Test Steps:

1. **Logout (if logged in):**
   - Go to Settings → Logout
   - You'll be returned to login screen

2. **Check for Biometric Button:**
   - Look for a gold/yellow button
   - Should say "Sign in with Face ID" or "Sign in with Touch ID"
   - Located below the email/password fields

3. **Tap the Biometric Button:**
   - Tap "Sign in with Face ID/Touch ID"
   - Face ID prompt should appear immediately

4. **Authenticate:**
   - Look at your device (Face ID) or touch sensor (Touch ID)
   - System will verify your biometric

5. **Verify Login:**
   - Should see brief loading indicator
   - Then automatically navigate to Dashboard
   - Check that your name appears in the UI

### Expected Behavior:

✅ **Success Case:**
- Face ID/Touch ID prompt appears
- Authentication succeeds
- Brief loading (< 2 seconds)
- Automatic navigation to Dashboard
- No errors shown

❌ **Possible Errors:**

| Error Message | Cause | Solution |
|--------------|-------|----------|
| "Biometric authentication not available" | Device doesn't support Face/Touch ID | Use email/password login |
| "No biometric data enrolled on device" | Face/Touch ID not set up on device | Enable in iOS Settings |
| "Biometric authentication cancelled" | User cancelled the prompt | Try again |
| "Biometric authentication failed" | Face/Touch ID didn't match | Try again or use password |
| "Please complete biometric enrollment first" | Not enrolled in BBMS | Complete enrollment in Settings |
| "User not found or not enrolled" | Backend can't identify user | Re-enroll or contact support |

## Backend Logs to Check

### Successful Login:
```
info: 🔍 Biometric login successful: marcos@bbms.ai (confidence: 98)
info: 👤 User access logged: biometric_login
info: POST /api/auth/biometric-login HTTP/1.1" 200
```

### Failed Login:
```
warn: ⚠️ Could not identify user from biometric template
warn: ⚠️ Biometric verification failed
error: ❌ Biometric login failed: User not identified
```

## Security Features

### What Makes It Secure:

1. **Local Authentication First**
   - Device-level Face ID/Touch ID required
   - Biometric data never leaves device

2. **Encrypted Templates**
   - Biometric templates are hashed with SHA256
   - Includes device ID and timestamp for uniqueness

3. **Backend Verification**
   - Server verifies the biometric template
   - Integrates with AuthID.ai for additional security

4. **JWT Tokens**
   - Short-lived access tokens (1 hour)
   - Secure HTTP-only refresh tokens (7 days)

5. **Activity Logging**
   - Every biometric login is logged
   - Includes confidence score and verification ID

## Troubleshooting

### Issue: Button doesn't appear
**Check:**
- Is enrollment completed? (Green checkmark in Settings → Biometric Authentication)
- Is Face ID/Touch ID enabled on device?
- Try restarting the app

**Fix:**
```swift
// Check in BiometricAuthService
biometricService.isEnrolled // Should be true
```

### Issue: "User not identified" error
**Cause:** Backend can't match your biometric template

**Fix:**
1. Check auth service logs for the template hash
2. Verify user is in database with biometric enrollment
3. May need to re-enroll

**Debug:**
```bash
# Check auth service logs
cd auth
tail -f logs/combined.log | grep biometric
```

### Issue: Authentication succeeds but login fails
**Cause:** Backend verification or token generation failed

**Check:**
- Auth service logs for errors
- Network connection between app and server
- AuthID.ai integration status

## API Endpoints

### Biometric Login
```http
POST /api/auth/biometric-login
Content-Type: application/json

{
  "verificationData": {
    "biometric_template": "hash...",
    "verification_method": "FaceID",
    "device_info": {
      "device_id": "uuid",
      "platform": "iOS",
      "app_version": "1.0"
    },
    "timestamp": "2025-10-08T22:00:00Z",
    "location_context": {
      "access_point": "mobile_app",
      "building_id": "bbms-main-building"
    }
  },
  "accessPoint": "mobile_app"
}
```

**Response (Success):**
```json
{
  "success": true,
  "user": {
    "id": "uuid",
    "email": "user@bbms.ai",
    "name": "User Name",
    "role": "user",
    "accessLevel": "standard"
  },
  "tokens": {
    "accessToken": "jwt...",
    "refreshToken": "jwt..."
  },
  "verification": {
    "verificationId": "uuid",
    "confidence": 98,
    "timestamp": "2025-10-08T22:00:00Z"
  }
}
```

## Advanced Features

### Future Enhancements:
- [ ] Automatic biometric login on app launch (if opted in)
- [ ] Biometric re-authentication for sensitive actions
- [ ] Multi-factor authentication (biometric + PIN)
- [ ] Building access control via biometrics
- [ ] Attendance tracking with biometric verification

### Configuration Options:
Users can configure biometric preferences in Settings:
- Enable/disable biometric login
- Require biometric for sensitive actions
- Enable biometric for building access

## Related Files

### iOS App:
- `BBMS/Views/LoginView.swift` - Login UI with biometric button
- `BBMS/Services/AuthService.swift` - `biometricLogin()` method
- `BBMS/Services/BiometricAuthService.swift` - Biometric verification logic
- `BBMS/Services/KeychainService.swift` - Secure storage

### Backend:
- `auth/src/routes/authRoutes.js` - `/biometric-login` endpoint
- `auth/src/services/authIdService.js` - AuthID integration
- `auth/src/services/userService.js` - User identification

## Status
✅ **READY TO USE** - Your biometric authentication is enrolled and ready for login!

Try it now:
1. Logout from the app
2. Look for the gold "Sign in with Face ID" button
3. Tap it and authenticate
4. Enjoy quick, secure access! 🎉
