# Biometric Enrollment Keychain Debugging Guide

## Issue
After completing biometric enrollment, logging out shows:
```
📦 Keychain check:
  - isEnrolled: false
  - enrollmentId: nil
```

## Enhanced Logging Added

### 1. BiometricAuthService.swift
**Added to `checkEnrollmentStatus()`:**
- Raw keychain value logging to see exactly what's stored
- Enhanced logging when enrollment status is false

**Added to `checkEnrollmentProgress()`:**
- Explicit logging when saving enrollment ID
- Verification of both enrollment flag AND enrollment ID after save

### 2. KeychainService.swift
**Added to `save()`:**
- Success message showing what value was saved for which key
- Detailed error messages with key name

**Added to `get()`:**
- Success message showing what value was retrieved for which key
- Error messages when retrieval fails with SecItem status code

## Debugging Steps

### Step 1: Check Enrollment Completion
After completing face scan in Safari, watch for these logs:

```
✅ Enrollment completed! Status: completed
🎯 Setting isEnrolled to: true
✅ KeychainService: Successfully saved '1' for key 'biometric_enrolled'
✅ Saved biometric_enrolled = true to keychain
✅ KeychainService: Successfully saved '[enrollment-id]' for key 'biometric_enrollment_id'
✅ Saved enrollmentId = [uuid] to keychain
🔍 Verifying keychain save:
   - isBiometricEnrolled: true
   - enrollmentId: [uuid]
```

**If you DON'T see the KeychainService success messages:**
→ The keychain save is failing (SecItem error)

### Step 2: Check After Logout
After logging out, watch for these logs:

```
🔍 BiometricAuthService: Checking enrollment status...
📦 Keychain check:
  - isEnrolled: true/false
  - enrollmentId: [uuid]/nil
  - raw biometric_enrolled value: '1'/'0'/nil
```

**Scenarios:**

1. **All values are nil:**
   ```
   - isEnrolled: false
   - enrollmentId: nil
   - raw biometric_enrolled value: 'nil'
   ```
   → Keychain was never saved OR keychain was cleared

2. **Values are correct:**
   ```
   - isEnrolled: true
   - enrollmentId: [uuid]
   - raw biometric_enrolled value: '1'
   ```
   → Keychain is working correctly!

3. **Raw value is '0' instead of '1':**
   ```
   - isEnrolled: false
   - enrollmentId: [uuid]
   - raw biometric_enrolled value: '0'
   ```
   → Something is setting enrollment to false

### Step 3: Check Keychain Get Operations
When checking enrollment status, you should see:

```
✅ KeychainService: Successfully retrieved '1' for key 'biometric_enrolled'
✅ KeychainService: Successfully retrieved '[uuid]' for key 'biometric_enrollment_id'
```

**If you see errors:**
```
⚠️ KeychainService: Failed to get value for key 'biometric_enrolled': SecItem status -25300
```

**Common SecItem Status Codes:**
- `-25300` (errSecItemNotFound) - Item doesn't exist in keychain
- `-25308` (errSecInteractionNotAllowed) - Device is locked
- `-34018` - Keychain access issue (common in simulator)

## Potential Root Causes

### 1. Keychain Not Being Saved
**Check if this log appears:**
```
❌ KeychainService: Failed to save '1' for key 'biometric_enrolled': SecItem status [code]
```

**Fix:** SecItem error code will indicate the issue

### 2. Logout Clearing Biometric Data
**Check `AuthService.handleLogout()`:**
```swift
private func handleLogout() async {
    currentUser = nil
    isAuthenticated = false
    keychain.clearAllTokens()  // ← Should NOT clear biometric_enrolled
    
    UserService.shared.clearUser()
}
```

**Verify `clearAllTokens()` only clears:**
- `access_token`
- `refresh_token`

**Should NOT clear:**
- `biometric_enrolled`
- `biometric_enrollment_id`
- `last_user_email`

### 3. Enrollment Not Completing
**Check if polling reached completion:**
```
📊 Enrollment status response:
  - enrollment.completed: true  ← Must be true
```

If `completed: false`, enrollment didn't finish.

### 4. Keychain Service Name Mismatch
**Check KeychainService initialization:**
```swift
private let service = "com.bbms.app"
```

If the service name changes, old keychain items won't be accessible.

### 5. Simulator vs Device Issue
**Simulator:** Keychain may not persist between builds
**Device:** Keychain persists correctly

**Test on physical device first!**

## Testing Commands

### Complete Enrollment and Test
1. **Build app:**
   ```bash
   xcodebuild -scheme BBMS -configuration Debug
   ```

2. **Watch full console output:**
   - Filter for: `Keychain`, `enrolled`, `biometric`

3. **Expected flow:**
   ```
   [Login]
   → ✅ KeychainService: Successfully saved 'marcos@bbms.ai' for key 'last_user_email'
   
   [Start Enrollment]
   → ✅ KeychainService: Successfully saved '[uuid]' for key 'biometric_enrollment_id'
   
   [Complete Enrollment]
   → ✅ KeychainService: Successfully saved '1' for key 'biometric_enrolled'
   → ✅ KeychainService: Successfully saved '[uuid]' for key 'biometric_enrollment_id'
   
   [Logout]
   → (no keychain biometric operations - only token clearing)
   
   [Check Status After Logout]
   → ✅ KeychainService: Successfully retrieved '1' for key 'biometric_enrolled'
   → ✅ KeychainService: Successfully retrieved '[uuid]' for key 'biometric_enrollment_id'
   → ✅ KeychainService: Successfully retrieved 'marcos@bbms.ai' for key 'last_user_email'
   ```

## Next Steps

### If Keychain Save Fails
1. Check SecItem error code in logs
2. Verify app has keychain entitlements
3. Test on physical device instead of simulator
4. Check if device is locked (keychain requires unlock)

### If Keychain Get Fails
1. Check if service name matches
2. Verify keychain group configuration
3. Check app bundle identifier hasn't changed
4. Clear app data and re-enroll

### If Logout Clears Biometric Data
1. Verify `clearAllTokens()` implementation
2. Add explicit logging in `handleLogout()`
3. Check for any other cleanup methods

## Summary of Changes

### Files Modified
1. **BiometricAuthService.swift**
   - Added raw value logging in `checkEnrollmentStatus()`
   - Added enrollment ID save in `checkEnrollmentProgress()`
   - Enhanced verification logging

2. **KeychainService.swift**
   - Added detailed logging to `save()` method
   - Added detailed logging to `get()` method
   - Shows exact values being saved/retrieved
   - Shows SecItem error codes

### How to Use
1. Rebuild the app with new logging
2. Complete enrollment
3. Watch console for KeychainService messages
4. Logout
5. Check console for what values are retrieved
6. Share the detailed logs if issue persists

---

**The enhanced logging will show EXACTLY what's happening with the keychain at each step.**
