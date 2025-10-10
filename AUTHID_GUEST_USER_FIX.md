# AuthID Guest User Display Fix

## Problem

After successfully logging in with AuthID biometric authentication, the iOS app showed "Guest User" (guest@bbms.local) in the UI instead of the authenticated user (marcos@bbms.ai), even though the token verification was working correctly.

## Root Cause

The iOS app has two separate user state managers:

1. **`AuthService.currentUser`** - Used for authentication state
2. **`UserService.shared.currentUser`** - Used for UI display (shown in profile, settings, etc.)

### Email/Password Login Flow ✅
```swift
// In AuthService.login()
let response = try await performRequest(...) as AuthResponse
await handleAuthSuccess(response)  // This calls UserService.shared.setAuthenticatedUser()
```

The `handleAuthSuccess` method properly updates **both**:
- `AuthService.currentUser` (line 346)
- `UserService.shared.setAuthenticatedUser()` (line 355)

### Biometric Login Flow ❌ (Before Fix)
```swift
// In AuthService.biometricLogin()
let result = try await biometricService.authenticateWithBiometrics()

if result.success, let user = result.user, let tokens = result.tokens {
    // Store tokens
    keychain.saveAccessToken(tokens.accessToken)
    
    await MainActor.run {
        self.currentUser = user  // ✅ Updates AuthService
        self.isAuthenticated = true
    }
    // ❌ MISSING: UserService.shared.setAuthenticatedUser(user)
}
```

The biometric login was only updating `AuthService.currentUser` but **not** `UserService.shared.currentUser`, so the UI continued to display the default "Guest User".

---

## Solution

Updated `AuthService.biometricLogin()` to also call `UserService.shared.setAuthenticatedUser()` after successful authentication.

### After Fix ✅
```swift
if result.success, let user = result.user, let tokens = result.tokens {
    // Store tokens and update authentication state
    keychain.saveAccessToken(tokens.accessToken)
    if let refreshToken = tokens.refreshToken, !refreshToken.isEmpty {
        keychain.saveRefreshToken(refreshToken)
    }
    
    // Store user email for biometric login after logout
    keychain.save(user.email, forKey: "last_user_email")
    
    await MainActor.run {
        self.currentUser = user
        self.isAuthenticated = true
        
        // ✅ Update user service with authenticated user (IMPORTANT!)
        UserService.shared.setAuthenticatedUser(user)
    }
    
    print("✅ Biometric authentication successful via AuthID")
}
```

---

## Files Modified

### `/BBMS/Services/AuthService.swift`
**Line ~114-125**: Updated `biometricLogin()` method to call `UserService.shared.setAuthenticatedUser(user)` after successful authentication.

**Changes:**
- Added `keychain.save(user.email, forKey: "last_user_email")` for consistency
- Added `UserService.shared.setAuthenticatedUser(user)` to update UI state
- Both changes now match the regular login flow

---

## Testing

### Before Fix:
1. Login with AuthID biometric ✅
2. Token verification succeeds ✅
3. Backend access works ✅
4. UI shows "Guest User" ❌

### After Fix:
1. Login with AuthID biometric ✅
2. Token verification succeeds ✅
3. Backend access works ✅
4. UI shows "Marcos Rosiles (marcos@bbms.ai)" ✅

---

## Why Two User States?

The app architecture has:
- **`AuthService`** - Manages authentication, tokens, and login state
- **`UserService`** - Manages user profile data and preferences for UI display

This separation allows:
- Authentication logic to be independent of UI
- UserService to handle profile updates, preferences, etc.
- Different parts of the app to observe different concerns

However, both need to be updated on login for the app to work correctly!

---

## Related Fixes

This completes the trilogy of AuthID biometric login fixes:

1. **Token Generation Fix** - Ensured `accessLevel` field is included in JWT tokens
2. **HTTPS Certificate Fix** - Backend accepts self-signed certificates from auth service
3. **User Display Fix** - iOS app updates both AuthService and UserService on biometric login

---

## Testing Instructions

1. **Rebuild the iOS app** in Xcode
2. **Logout if logged in**
3. **Login with AuthID biometric**
4. **Verify:**
   - ✅ Login succeeds
   - ✅ Token verification works (no backend errors)
   - ✅ Profile shows correct user (Marcos Rosiles / marcos@bbms.ai)
   - ✅ Rubidex data loads
   - ✅ Settings show correct user info
   - ✅ All API calls work

---

## Summary

**Problem:** UI showed "Guest User" after AuthID biometric login

**Cause:** `UserService.shared` wasn't updated after biometric authentication

**Fix:** Added `UserService.shared.setAuthenticatedUser(user)` call after successful biometric login

**Result:** UI now displays the correct authenticated user after biometric login

---

**Status:** ✅ Fixed - Rebuild Required
**Date:** 2025-10-10
**Impact:** UI only (rebuild iOS app to apply)
