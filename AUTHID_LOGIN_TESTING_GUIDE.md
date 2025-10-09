# AuthID Biometric Login - Testing Guide

## Quick Start Testing

### Prerequisites
1. ✅ User has already enrolled biometric (completed enrollment flow)
2. ✅ Auth server running on https://192.168.100.9:3001
3. ✅ AuthID web server running on https://192.168.100.9:3002
4. ✅ Safari certificate trusted

---

## Test 1: Web-Only Test (No iOS App Required)

### Step 1: Initiate Login via API

```bash
# Test login initiation
curl -X POST https://192.168.100.9:3001/api/biometric/login/initiate \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com"
  }' \
  -k

# Expected response:
{
  "success": true,
  "userId": "user123",
  "operationId": "abc-123-def",
  "verificationUrl": "https://192.168.100.9:3002/verify.html?operationId=abc-123-def&secret=xxx",
  "qrCode": "...",
  "expiresAt": "2025-10-09T12:30:00Z"
}
```

### Step 2: Open Verification URL in Safari

Copy the `verificationUrl` from the response and open in Safari mobile:
```
https://192.168.100.9:3002/verify.html?operationId=abc-123-def&secret=xxx
```

### Step 3: Complete Face Verification

1. AuthID component loads
2. Take selfie
3. Wait for "verifiedPage" message
4. Page should show "Login Successful!"
5. Token displayed in success screen

### Step 4: Verify Token

Check Safari console or backend logs for JWT token. Decode at https://jwt.io to verify contents.

---

## Test 2: Check Login Status

```bash
# Poll login status
curl -X GET https://192.168.100.9:3001/api/biometric/login/status/abc-123-def -k

# Expected responses:

# While pending:
{
  "success": true,
  "status": "pending",
  "state": 0,
  "result": 0,
  "message": "Verification in progress"
}

# After completion:
{
  "success": true,
  "status": "completed",
  "state": 1,
  "result": 1,
  "completedAt": "2025-10-09T12:28:45Z"
}
```

---

## Test 3: Complete Login and Get Token

```bash
# Complete login after verification
curl -X POST https://192.168.100.9:3001/api/biometric/login/complete/abc-123-def -k

# Expected response:
{
  "success": true,
  "status": "verified",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "user123",
    "email": "test@example.com",
    "name": "Test User",
    "role": "user",
    "department": "Engineering",
    "biometricEnabled": true
  }
}
```

---

## Test 4: Verify JWT Token Works

```bash
# Use the token to access protected endpoint
TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

curl -X GET https://192.168.100.9:3001/api/biometric/status \
  -H "Authorization: Bearer $TOKEN" \
  -k

# Should return user's biometric status
```

---

## Test 5: Error Scenarios

### Test: User Not Enrolled
```bash
curl -X POST https://192.168.100.9:3001/api/biometric/login/initiate \
  -H "Content-Type: application/json" \
  -d '{
    "email": "newuser@example.com"
  }' \
  -k

# Expected:
{
  "error": "Biometric not enrolled",
  "code": "NOT_ENROLLED",
  "message": "Please enroll your biometric first"
}
```

### Test: Invalid Email
```bash
curl -X POST https://192.168.100.9:3001/api/biometric/login/initiate \
  -H "Content-Type: application/json" \
  -d '{
    "email": "nonexistent@example.com"
  }' \
  -k

# Expected:
{
  "error": "User not found",
  "code": "USER_NOT_FOUND",
  "message": "No account found with that email"
}
```

### Test: Face Doesn't Match
1. Initiate login for User A
2. User B takes selfie
3. AuthID returns state=2, result=2 (failed)
4. Backend returns 401 Unauthorized

---

## Test 6: iOS App Integration Test

### Step 1: Setup Test User
```swift
// In iOS app or via API
let testEmail = "test@example.com"

// Verify user is enrolled
curl -X GET https://192.168.100.9:3001/api/biometric/status \
  -H "Authorization: Bearer <token>" \
  -k
```

### Step 2: Test Login Flow

1. Open BBMS iOS app
2. Tap "Login with Face ID"
3. Enter email: test@example.com
4. Tap "Continue"
5. **Expected**: WebView opens with AuthID component
6. Take selfie
7. **Expected**: Page shows "Login Successful!" then redirects
8. **Expected**: App receives token via URL scheme
9. **Expected**: App navigates to main screen

### Step 3: Verify Token Stored

```swift
// Check in iOS app
if let token = UserDefaults.standard.string(forKey: "authToken") {
    print("✅ Token stored: \(token.prefix(20))...")
} else {
    print("❌ No token found")
}
```

---

## Test 7: Complete End-to-End Flow

### Scenario: New User Journey

```bash
# 1. Create user
POST /api/auth/register
{
  "email": "newuser@test.com",
  "password": "Test123!",
  "name": "New User"
}

# 2. Login with password (get token)
POST /api/auth/login
{
  "email": "newuser@test.com",
  "password": "Test123!"
}

# 3. Initiate biometric enrollment
POST /api/biometric/enroll
Headers: Authorization: Bearer <token>

# 4. Complete enrollment in Safari
# (Take selfie, verifiedPage message)

# 5. Mark enrollment complete
POST /api/biometric/operation/{operationId}/complete

# 6. Logout (clear token)

# 7. Login with biometric
POST /api/biometric/login/initiate
{
  "email": "newuser@test.com"
}

# 8. Complete verification in Safari
# (Take selfie again)

# 9. Get new token
POST /api/biometric/login/complete/{operationId}

# 10. Access protected resources with new token
GET /api/biometric/status
Headers: Authorization: Bearer <new_token>
```

---

## Browser Console Debug Logs

When testing in Safari, open Developer Console (Command + Option + C) and look for these logs:

### Successful Flow:
```javascript
🔐 AuthID Biometric Login - Plain JS Version
Operation ID: abc-123-def
📋 AuthID Verification URL: https://id-uat.authid.ai/...
🎬 AuthID component loaded successfully
🔄 Starting status polling every 2 seconds...
📸 Liveness check finished - waiting for final verification...
📨 Message received: {type: "authid:page", pageName: "verifiedPage", success: true}
✅ AuthID verification completed! Received verifiedPage confirmation
🎯 Trusting web component (AuthID UAT API has sync delays)
⏹️ Stopping status polling
📤 Completing login for operation: abc-123-def
✅ Login successful!
🔑 JWT Token (DO NOT LOG IN PRODUCTION): eyJhbGciOiJIUzI1Ni...
🚀 Redirecting to iOS app...
```

### Failed Verification:
```javascript
📨 Message received: {type: "authid:page", pageName: "errorPage", success: false}
❌ Verification failed
📤 Completing login for operation: abc-123-def
❌ Login failed: Biometric verification failed
```

---

## Backend Logs to Monitor

### auth/logs/combined.log

```
info: 🔐 Initiating biometric login {"email":"test@example.com"}
info: 📤 Creating biometric verification operation {"url":"...","userId":"user123"}
info: ✅ AuthID login operation created {"operationId":"abc-123-def","userId":"user123"}
info: 🔍 Checking login operation status {"operationId":"abc-123-def"}
info: ⚠️ AuthID API returned 404 (UAT sync lag) - trusting web component {"operationId":"abc-123-def"}
info: ✅ Biometric login successful {"userId":"user123","operationId":"abc-123-def","email":"test@example.com"}
```

---

## Performance Metrics

### Expected Timings:

| Step | Expected Time |
|------|--------------|
| Login initiation API call | < 1 second |
| WebView load | 2-3 seconds |
| AuthID component load | 3-5 seconds |
| Liveness check | 5-15 seconds |
| Verification completion | 1-2 seconds |
| Token generation | < 1 second |
| **Total login time** | **15-30 seconds** |

---

## Troubleshooting

### Issue: "User not found"
**Check**:
- User exists in database
- Email is correct (case-sensitive)
- User completed enrollment

### Issue: "Biometric not enrolled"
**Check**:
- User's biometric_status is "completed"
- User has biometric_enrollment_id set
- Check enrollment status: `GET /api/biometric/status`

### Issue: WebView doesn't redirect back
**Check**:
- URL scheme registered in Info.plist (bbms://)
- Backend returning token correctly
- Check Safari console for JavaScript errors

### Issue: Token invalid
**Check**:
- JWT_SECRET matches between auth server and backend
- Token not expired (check JWT_EXPIRES_IN)
- Token format correct (Bearer <token>)

### Issue: Face verification fails every time
**Check**:
- User enrolled correct face (same person)
- Good lighting during login
- Camera working properly
- AuthID account has biometric enrolled

---

## Success Criteria

### ✅ All Tests Pass When:

1. **Enrollment complete** → User can initiate login
2. **Login initiated** → Backend returns operation ID and URL
3. **WebView opens** → AuthID component loads
4. **Selfie taken** → AuthID verifies face matches enrolled template
5. **verifiedPage received** → Page shows success
6. **Token generated** → Valid JWT returned
7. **Token works** → Can access protected endpoints
8. **iOS redirect** → App receives token and navigates to main screen

---

## Production Readiness Checklist

- [ ] All 7 test scenarios pass
- [ ] Error handling covers all failure modes
- [ ] Tokens stored securely (Keychain, not UserDefaults)
- [ ] SSL certificate pinning implemented
- [ ] Rate limiting tested
- [ ] Session timeout tested
- [ ] Refresh token flow tested
- [ ] Multiple device support tested
- [ ] Biometric fallback to password works
- [ ] Logging doesn't expose sensitive data
- [ ] Analytics tracking implemented
- [ ] User feedback messages clear and helpful

