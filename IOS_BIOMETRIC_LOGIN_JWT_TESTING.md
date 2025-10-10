# iOS Biometric Login with JWT - Testing Guide

## Overview
iOS app has been updated to support biometric login with JWT token issuance. This guide walks through step-by-step manual testing.

## What Changed

### BiometricAuthService.swift
- **Updated `authenticateWithBiometrics()`** - Now uses new JWT flow:
  1. Gets user email from AuthService or Keychain
  2. Calls `POST /auth/biometric-login/initiate` to get AuthID URL and operation ID
  3. Opens Safari for face scan
  4. Polls `GET /auth/biometric-login/poll/:operationId` every 2 seconds (max 60 attempts = 2 minutes)
  5. Returns JWT tokens when status is "completed"

- **New Methods:**
  - `initiateBiometricLogin(email:)` - Initiates login with backend
  - `openAuthIDUrl(_:)` - Opens Safari with AuthID URL
  - `pollForAuthenticationResult(operationId:)` - Polls until completion
  - `getCurrentUserEmail()` - Gets email from current user or keychain

- **New Data Structures:**
  - `InitiateLoginRequest` - Request body for initiate endpoint
  - `InitiateLoginResponse` - Response with operationId and authIdUrl
  - `PollLoginResponse` - Response with status, user, and tokens

### AuthService.swift
- **Updated `handleAuthSuccess()`** - Now stores user email in keychain with key `"last_user_email"`
  - This allows biometric login to work after logout without needing to login with email/password first

## Prerequisites

### Backend Must Be Running
```bash
cd auth
npm start
```

Server should be running on: `https://192.168.1.131:3001` (or your current IP)

### User Must Be Enrolled in AuthID First!
**IMPORTANT:** Before you can use biometric login, you must:
1. Login with email/password
2. Complete biometric enrollment (face scan)
3. Wait for enrollment to complete (100% progress)
4. Only then can you logout and use biometric login

### How to Check Enrollment Status
After logging in, check the keychain logs:
```
📦 Keychain check:
  - isEnrolled: true    ← Must be true!
  - enrollmentId: [some-uuid]
```

If `isEnrolled: false`, you need to complete enrollment first.

### Test User
- Email: `marcos@bbms.ai`
- Password: (your password)
- Must complete enrollment before testing biometric login

## Test Scenario: Logout → Biometric Login

### Step 0: Complete Biometric Enrollment (If Not Already Enrolled)

**Check if enrolled first:**
1. Login with email/password
2. Watch console logs for:
   ```
   📦 Keychain check:
     - isEnrolled: true
   ```

**If `isEnrolled: false`, you must enroll:**
1. Navigate to Profile/Settings/Biometric Setup
2. Tap "Enroll in Biometric Authentication"
3. **Watch for enrollment URL in console:**
   ```
   🔗 Enrollment URL: https://id-uat.authid.ai/bio/enroll/[enrollment-id]
   ```
4. **Safari Opens** - Complete face scan
5. **Return to app** - Wait for polling to complete
6. **Verify in console:**
   ```
   ✅ Enrollment completed! Status: completed
   ✅ Saved biometric_enrolled = true to keychain
   🔍 Verifying keychain save: true
   ```
7. **Confirm enrollment:**
   ```
   📦 Keychain check:
     - isEnrolled: true    ← Should now be true!
     - enrollmentId: [uuid]
   ```

**Only proceed to Step 1 when enrollment is confirmed!**

---

### Step 1: Build and Run iOS App
```bash
# Open Xcode
open BBMS.xcodeproj

# OR build from command line
xcodebuild -scheme BBMS -configuration Debug
```

### Step 2: Login with Email/Password First
1. Open app on iOS device/simulator
2. Enter credentials:
   - Email: `marcos@bbms.ai`
   - Password: (your password)
3. Tap "Sign In"
4. **Verify:**
   - ✅ Login successful
   - ✅ User email stored in keychain (check debug logs)
   - ✅ You're logged into the app

### Step 3: Logout
1. Navigate to Profile/Settings
2. Tap "Logout"
3. **Verify:**
   - ✅ Logged out
   - ✅ Tokens cleared
   - ✅ Back to login screen
   - ✅ User email STILL in keychain (for biometric login)

### Step 4: Biometric Login
1. On login screen, tap "Login with Biometrics" button
2. **Watch for:**
   - 🔐 Console: "Starting biometric authentication for: marcos@bbms.ai"
   - 📤 Network call to `POST /auth/biometric-login/initiate`
   - ✅ Console: "Received AuthID URL: https://id-uat.authid.ai/..."
   - 📋 Console: "Operation ID: [uuid]"

3. **Safari Opens:**
   - AuthID face scan page should open in Safari
   - Complete face scan
   - Wait for "Authentication successful" message

4. **App Polls for Result:**
   - 📊 Console shows: "Poll attempt 1: status=pending"
   - 📊 Console shows: "Poll attempt 2: status=pending"
   - ... (continues every 2 seconds)
   - ✅ Console shows: "Poll attempt X: status=completed"
   - ✅ Console shows: "Biometric authentication completed successfully"

5. **Tokens Stored:**
   - JWT access token stored in Keychain
   - JWT refresh token stored in Keychain
   - User authenticated
   - Redirected to main app screen

### Step 5: Verify Authentication
1. **Check Current User:**
   - Profile screen should show: marcos@bbms.ai
   - Role: admin
   - Department: QA

2. **Check Network Requests:**
   - Open Network tab in Xcode debugger
   - Make any API request
   - **Verify:** Request includes `Authorization: Bearer [access-token]`

3. **Check Keychain:**
   - Access token should be stored
   - Refresh token should be stored
   - User email should be stored

## Expected Console Output

### On Initiate
```
🔐 Starting biometric authentication for: marcos@bbms.ai
📤 Sending request to: POST /auth/biometric-login/initiate
✅ Received AuthID URL: https://id-uat.authid.ai/bio/login/[operation-id]
📋 Operation ID: [operation-uuid]
🌐 Opening Safari for face scan...
✅ Safari opened successfully
```

### On Polling
```
⏳ Polling for authentication result...
📊 Poll attempt 1: status=pending
📊 Poll attempt 2: status=pending
📊 Poll attempt 3: status=pending
...
📊 Poll attempt 10: status=completed
✅ Biometric authentication completed successfully
```

### On Success
```
✅ Biometric authentication successful via AuthID
✅ Tokens stored in Keychain
✅ User authenticated: marcos@bbms.ai
```

## Error Scenarios

### Error: User Not Found
```
❌ BiometricError.userNotFound
```
**Fix:** Login with email/password first to store user email

### Error: Authentication Failed
```
❌ BiometricError.authenticationFailed
```
**Possible causes:**
- Face scan failed in AuthID
- User cancelled in Safari
- Operation status returned "failed"

### Error: Network Error
```
⚠️ Poll attempt X failed: Network error
```
**Fix:** 
- Check backend is running
- Verify network connectivity
- Check server URL in APIConfig

### Error: Timeout
```
⚠️ Biometric authentication timed out
```
**Fix:**
- Complete face scan faster
- Check AuthID service is responding
- Increase maxAttempts in `pollForAuthenticationResult()`

## Debugging Tips

### Check Backend Logs
```bash
# In auth directory
tail -f logs/combined.log

# Should see:
# POST /auth/biometric-login/initiate - 200
# GET /auth/biometric-login/poll/[operation-id] - 200 (multiple times)
```

### Check Operation Cache
```javascript
// In authRoutes.js, add temporary logging:
console.log('Current operationEmailCache:', operationEmailCache);
```

### Check AuthID Status
```bash
# Get operation status directly from AuthID
curl -X GET "https://id-uat.authid.ai/api/v1/operations/[operation-id]" \
  -H "X-API-Key: [your-authid-api-key]"
```

### Xcode Debugger
1. Set breakpoint in `authenticateWithBiometrics()`
2. Step through each function call
3. Inspect `initiateResponse` and `pollResponse` objects

## Success Criteria

✅ **Phase 2 Complete When:**
1. Can login with email/password
2. Can logout successfully
3. Can login with biometrics WITHOUT server restart
4. JWT tokens are received and stored
5. App is authenticated with bearer token
6. Profile shows correct user information
7. No compilation errors
8. Console shows proper flow execution

## Next Steps After Success
- Test token refresh flow
- Test multiple logout/login cycles
- Test on physical iOS device
- Test with different users
- Add error handling UI
- Add loading indicators
- Add success/failure notifications

## File Changes Summary
- ✅ `BiometricAuthService.swift` - Updated authenticateWithBiometrics() method
- ✅ `AuthService.swift` - Store user email in keychain
- 📝 Added new request/response models
- 📝 Added polling logic with 2-second interval
- 📝 Added Safari integration for face scan

## Testing Checklist
- [ ] Backend server running
- [ ] iOS app builds successfully
- [ ] No compilation errors
- [ ] User enrolled in AuthID
- [ ] Email/password login works
- [ ] Logout works
- [ ] Biometric login initiates
- [ ] Safari opens with AuthID URL
- [ ] Face scan completes
- [ ] Polling works
- [ ] JWT tokens received
- [ ] Tokens stored in keychain
- [ ] User authenticated
- [ ] Profile shows correct data
- [ ] Bearer token in API requests

---

**Ready to Test!** 🚀

Start with Step 1 and work through each step carefully, checking console logs at each stage.
