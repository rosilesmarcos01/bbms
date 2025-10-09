# Biometric Enrollment Debug & Test Guide 🔍

## Current Status
Added comprehensive logging to track enrollment status and keychain storage.

## Debug Logging Added

### In `checkEnrollmentStatus()`:
```
🔍 BiometricAuthService: Checking enrollment status...
📦 Keychain check:
  - isEnrolled: true/false
  - enrollmentId: <uuid or nil>
✅ Set isEnrolled = true from keychain
ℹ️ No user logged in, using keychain enrollment status only
👤 User ID found: <uuid>
🔄 Checking enrollment progress with backend...
```

### In `checkEnrollmentProgress()`:
```
🔍 Checking enrollment progress for ID: <uuid>
📊 Enrollment status response:
  - status: completed
  - progress: 100
  - completed: true
✅ Saved biometric_enrolled = true to keychain
⏳ Enrollment not yet completed
```

## Complete Test Flow

### Step 1: Fresh Enrollment
1. **Login with email/password**
   ```
   Email: marcos@bbms.ai
   Password: your-password
   ```

2. **Go to Settings → Biometric Authentication**
   - Should show "Enrollment Required"
   - Tap "Start Enrollment"

3. **Choose "Open in Browser"**
   - Safari opens with AuthID web interface
   - Complete selfie capture
   - See "✅ Enrollment Complete!" message
   - Tap "✓ Finish & Close" button
   - Wait for "✅ Done! Close this window"

4. **Close Safari manually**
   - Swipe down or tap Done
   - Return to BBMS app

5. **Check Console Output (Xcode)**
   Look for:
   ```
   🔍 Checking enrollment progress for ID: <uuid>
   📊 Enrollment status response:
     - status: completed
     - progress: 100
     - completed: true
   ✅ Saved biometric_enrolled = true to keychain
   ```

6. **Verify in Settings**
   - Should now show "✅ Enrollment Complete!"
   - Green checkmark
   - "Test Authentication" button appears

### Step 2: Test Logout & Login Screen
1. **Logout**
   - Go to Settings
   - Tap "Logout"
   - Returns to login screen

2. **Check Console Output**
   ```
   🔍 BiometricAuthService: Checking enrollment status...
   📦 Keychain check:
     - isEnrolled: true  ← SHOULD BE TRUE
     - enrollmentId: 5bae5b5a-...
   ✅ Set isEnrolled = true from keychain
   ℹ️ No user logged in, using keychain enrollment status only
   ```

3. **Check Login Screen UI**
   Should see:
   - ✅ Email field
   - ✅ Password field
   - ✅ Login button
   - ✅ Divider line
   - ✅ **Gold "Sign in with Face ID" button**

### Step 3: Test Biometric Login
1. **Tap "Sign in with Face ID"**
   - Face ID prompt appears
   - Authenticate with your face

2. **Check Console Output**
   ```
   🔐 Starting REAL AuthID biometric verification
   📤 Sending verification request...
   ✅ Verification successful
   ```

3. **Verify Login**
   - Should navigate to Dashboard
   - No errors shown
   - Logged in successfully!

## If Biometric Button Doesn't Show

### Check 1: Xcode Console
Look for the enrollment check logs when login screen appears:
```
🔍 BiometricAuthService: Checking enrollment status...
📦 Keychain check:
  - isEnrolled: ???  ← What does this say?
  - enrollmentId: ???
```

### Check 2: Manual Keychain Check
Add this temporarily in `LoginView.onAppear`:
```swift
print("🔬 Manual keychain check:")
print("  enrolled:", KeychainService.shared.isBiometricEnrolled())
print("  ID:", KeychainService.shared.getBiometricEnrollmentId() ?? "nil")
print("  service isEnrolled:", biometricService.isEnrolled)
```

### Check 3: Force Set Keychain (Debug Only)
If keychain shows false, you can manually set it in Xcode console or code:
```swift
KeychainService.shared.setBiometricEnrolled(true)
KeychainService.shared.setBiometricEnrollmentId("5bae5b5a-6bf8-a322-9ea8-72e0603d01fa")
BiometricAuthService.shared.checkEnrollmentStatus()
```

## Common Issues & Solutions

### Issue 1: Keychain shows `isEnrolled: false` after enrollment
**Cause:** The enrollment status check didn't complete before logout

**Solution:**
1. Log back in with email/password
2. Go to Settings → Biometric Authentication
3. Wait for "Enrollment Complete" status to show
4. This triggers `checkEnrollmentProgress()` which saves to keychain
5. Then logout again

### Issue 2: Console shows "Error: 401 Unauthorized" when checking status
**Cause:** The `/biometric/enrollment/status` endpoint requires authentication

**Solution:**
The endpoint needs the auth token. When logged out, we can only use keychain.
This is working as designed - keychain check should work.

### Issue 3: Button shows but tapping causes error
**Cause:** Backend can't identify user from biometric template

**Check:**
1. Auth service logs for biometric-login endpoint
2. User should be identified from the enrollment
3. May need to re-enroll

## Expected Console Output

### When Opening Login Screen (After Enrollment):
```
🔍 BiometricAuthService: Checking enrollment status...
📦 Keychain check:
  - isEnrolled: true
  - enrollmentId: 5bae5b5a-6bf8-a322-9ea8-72e0603d01fa
✅ Set isEnrolled = true from keychain
ℹ️ No user logged in, using keychain enrollment status only
```

### When Tapping Biometric Login Button:
```
🔐 AuthService: Starting biometric login
🔐 Starting REAL AuthID biometric verification
📤 Sending verification request to /api/auth/biometric-login
✅ Biometric verification successful
✅ AuthService: Login successful
```

### Auth Service Logs (Backend):
```
info: 🔍 Biometric login request received
info: 🔍 Found user by biometric template: marcos@bbms.ai
info: ✅ Biometric verification successful (confidence: 98)
info: 🎉 Biometric login successful: marcos@bbms.ai
```

## Troubleshooting Steps

### 1. Check if enrollment was saved:
```bash
# In Xcode console after enrollment completes
# Look for this line:
✅ Saved biometric_enrolled = true to keychain
```

### 2. Check if keychain persists after logout:
```bash
# After logout, when login screen appears
# Should see:
📦 Keychain check:
  - isEnrolled: true  ← MUST BE TRUE
```

### 3. If still false, re-enroll:
```
1. Login with email/password
2. Go to Settings → Biometric Authentication  
3. If shows "Enrolled" - good!
4. If not, tap "Start Enrollment" again
5. Complete enrollment
6. WAIT for green checkmark to appear
7. Then logout
```

## Files Modified

- `BBMS/Services/BiometricAuthService.swift` - Added debug logging
- `BBMS/Views/LoginView.swift` - Calls `checkEnrollmentStatus()` on appear

## Next Steps

1. **Rebuild the app** with new logging
2. **Run and watch Xcode console**
3. **Follow the test flow above**
4. **Share console output** if button still doesn't appear

The logs will tell us exactly what's happening! 🔍
