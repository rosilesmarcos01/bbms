# Biometric Login JSON Decode Error Fix

## 🔍 Root Cause Analysis

### Symptoms from Xcode Logs
```
📡 Poll response: 200 - 1023 bytes  ← TOKENS RECEIVED!
⚠️ Poll attempt 6 failed: The data couldn't be read because it is missing.  ← DECODE FAILED!

📡 Poll response: 200 - 187 bytes  ← CACHE EXPIRED
📊 Poll attempt 7: status=completed
⚠️ Poll completed but no tokens - session may have expired
```

### The Problem
The iOS app successfully received the JWT tokens (1023 bytes) but **failed to decode the JSON response**. This caused:
1. **JSON decoding error** on attempt 6 (with tokens)
2. **Cache expired** by attempt 7
3. **Infinite retry loop** because tokens were never saved

### Backend Response Structure (Success)
```json
{
  "status": "completed",
  "message": "Authentication completed successfully",
  "operationId": "5c54d083-b34d-b94c-1714-4e1e549637a3",
  "accessToken": "eyJhbGc...",
  "refreshToken": "eyJhbGc...",
  "expiresIn": 86400,
  "tokenType": "Bearer",
  "user": {
    "id": "202d4797-...",
    "email": "marcos@bbms.ai",
    "name": "Marcos Rosiles",
    "role": "admin",
    "accessLevel": "admin",
    "department": "QA"
  }
}
```

### Backend Response Structure (Expired)
```json
{
  "status": "completed",
  "message": "Authentication completed but session expired. Please initiate login again.",
  "operationId": "5c54d083-b34d-b94c-1714-4e1e549637a3",
  "code": "SESSION_EXPIRED"
}
```

### iOS Model (Before Fix)
```swift
struct PollLoginResponse: Codable {
    let status: String
    let user: User?
    let accessToken: String?
    let refreshToken: String?
    // ❌ Missing: message, operationId, expiresIn, tokenType, code
}
```

**Issue**: iOS expected only 4 fields, but backend returned 8-10 fields. Swift's `Codable` is **strict** by default - extra fields can cause decoding to fail depending on the decoder's configuration.

## ✅ Solution Implemented

### 1. Extended iOS Model to Match Backend Response
```swift
struct PollLoginResponse: Codable {
    let status: String
    let user: User?
    let accessToken: String?
    let refreshToken: String?
    let message: String?          // ✅ Added
    let operationId: String?      // ✅ Added
    let expiresIn: Int?           // ✅ Added
    let tokenType: String?        // ✅ Added (e.g., "Bearer")
    let code: String?             // ✅ Added (e.g., "SESSION_EXPIRED")
    
    var tokens: AuthTokens? {
        guard let accessToken = accessToken else { return nil }
        return AuthTokens(accessToken: accessToken, refreshToken: refreshToken)
    }
    
    enum CodingKeys: String, CodingKey {
        case status, user, accessToken, refreshToken
        case message, operationId, expiresIn, tokenType, code
    }
}
```

### 2. Added Debug Logging for JSON Decode Errors
```swift
do {
    let pollResponse = try JSONDecoder().decode(PollLoginResponse.self, from: data)
    return pollResponse
} catch {
    print("❌ JSON Decode Error: \(error)")
    if let jsonString = String(data: data, encoding: .utf8) {
        print("📄 Failed to decode JSON:")
        print(jsonString)
    }
    throw error
}
```

### 3. Added Raw JSON Logging for Large Responses
```swift
// Debug: Print raw JSON for large responses (likely containing tokens)
if data.count > 500 {
    if let jsonString = String(data: data, encoding: .utf8) {
        print("🔍 Raw JSON response (\(data.count) bytes):")
        print(jsonString)
    }
}
```

## 📊 Expected Behavior After Fix

### Successful Flow
```
1. User logs out
2. Taps "Sign in with Face ID"
3. Safari opens for AuthID face scan
4. User completes face scan
5. iOS polls backend (attempts 1-5: "pending", 134 bytes)
6. ✅ iOS receives tokens (attempt 6: "completed", 1023 bytes)
7. ✅ JSON decodes successfully with all fields
8. ✅ Tokens extracted and saved to keychain
9. ✅ User authenticated and logged in
10. ✅ Polling stops (no more attempts)
```

### Log Output (Expected)
```
🔄 Polling with cache disabled: 5c54d083-b34d-b94c-1714-4e1e549637a3
📡 Poll response: 200 - 1023 bytes
🔍 Raw JSON response (1023 bytes):
{"status":"completed","message":"Authentication completed successfully",...}
📊 Poll attempt 6: status=completed
✅ Poll completed with tokens!
   - accessToken: eyJhbGciOiJIUzI1NiIs...
   - refreshToken: eyJhbGciOiJIUzI1NiIs...
   - user: marcos@bbms.ai
✅ Biometric authentication completed successfully
✅ KeychainService: Successfully saved to keychain for key 'access_token'
✅ KeychainService: Successfully saved to keychain for key 'refresh_token'
```

## 🧪 Testing Checklist

### Pre-Test Setup
- [ ] Ensure backend is running on https://10.10.62.45:3001
- [ ] Verify JWT_SECRET is configured in backend .env
- [ ] Rebuild iOS app (Cmd+B in Xcode)

### Test Flow
- [ ] Launch iOS app
- [ ] Login with email/password
- [ ] Verify enrollment shows as complete
- [ ] Logout from app
- [ ] Tap "Sign in with Face ID"
- [ ] Complete face scan in Safari
- [ ] **Watch logs for successful JSON decode**
- [ ] Verify tokens saved to keychain
- [ ] Verify user is logged in
- [ ] Test authenticated API request (e.g., fetch documents)

### Debug Steps (If Still Failing)
- [ ] Check Xcode logs for "🔍 Raw JSON response" output
- [ ] Verify JSON structure matches backend response
- [ ] Check for "❌ JSON Decode Error" and specific error message
- [ ] Verify backend JWT_SECRET is set (not causing token generation errors)
- [ ] Check backend logs for "✅ Issued JWT tokens"

## 🎓 Lessons Learned

### Swift Codable Strictness
- Swift's `Codable` can fail when extra fields exist in JSON
- **Best Practice**: Define all fields returned by backend, mark optional with `?`
- Use `CodingKeys` enum to control field mapping explicitly

### Backend/iOS Contract
- **Problem**: Backend added fields without updating iOS model
- **Solution**: Keep response models in sync between backend and iOS
- **Prevention**: Document API contracts, use TypeScript/OpenAPI, or code generation

### Debug Logging Importance
- Original error: "The data couldn't be read because it is missing" (unhelpful!)
- With debug logging: See exact JSON structure and decode error details
- **Best Practice**: Always log raw responses when debugging API issues

### JSON Decoder Configuration
Swift's JSONDecoder can be configured:
```swift
let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase  // snake_case → camelCase
decoder.dateDecodingStrategy = .iso8601              // Parse ISO dates
// Note: Extra fields still need to be in model or marked optional
```

## 🔗 Related Fixes

1. ✅ **JWT Token Structure**: Backend returns top-level tokens
2. ✅ **Infinite Polling**: Cache control disabled
3. ✅ **Keychain Persistence**: Enrollment saved correctly
4. ✅ **Auth Token Warnings**: requiresAuth parameter added
5. ✅ **JSON Decode Error**: Extended iOS model to match backend (this fix)

## 🚀 Next Steps

1. **Rebuild iOS app** with updated model
2. **Test complete biometric login flow**
3. **Verify tokens are saved and used correctly**
4. If still failing:
   - Check raw JSON output in logs
   - Verify backend JWT_SECRET is set
   - Compare iOS model with actual backend response
5. **Document successful flow** for future reference

---

**Status**: ✅ Fix Applied - Ready for Testing
**Date**: 2025-10-10
**Critical Path**: JSON decode must work to save tokens
**Expected Outcome**: Biometric login completes successfully with JWT tokens
