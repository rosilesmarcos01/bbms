# Enrollment Polling - Quick Test Checklist

## ✅ Critical Success Criteria

When you tap "Set Up Face ID" and Safari opens, you **MUST** see this log:

```
🔄 Safari sheet appeared - starting enrollment status polling...
```

If you **DO NOT** see this log, **STOP** and report back - the `.onAppear` isn't firing.

## 📋 Step-by-Step Test

### 1. Rebuild
- [ ] Press `Cmd + R` in Xcode
- [ ] Wait for build to complete
- [ ] App launches on simulator/device

### 2. Login
- [ ] Enter email: `marcos@bbms.ai`
- [ ] Enter password
- [ ] Tap "Log In"
- [ ] See main dashboard

### 3. Navigate to Settings
- [ ] Tap Settings tab (bottom navigation)
- [ ] Find "Biometric Setup" section
- [ ] Tap "Set Up Face ID" button

### 4. Watch Console - Safari Opens
**CRITICAL**: Look for this log immediately:
```
🔄 Safari sheet appeared - starting enrollment status polling...
```

- [ ] ✅ Saw the log? **Continue to step 5**
- [ ] ❌ Didn't see the log? **STOP - Report issue**

### 5. Watch Console - Polling Active
Every 3 seconds you should see:
```
⏱️ Polling enrollment status...
```

- [ ] Saw at least 2-3 polling logs
- [ ] Safari is showing AuthID enrollment page

### 6. Complete Enrollment
- [ ] Follow enrollment steps in Safari
- [ ] Complete selfie capture
- [ ] See success screen in Safari

### 7. Watch Console - Auto-Dismiss
Within 3 seconds of completion, look for:
```
🎉 Enrollment detected as complete! Closing Safari sheet...
✅ Status polling stopped
🚪 Safari sheet dismissed - stopping polling and refreshing enrollment status
```

- [ ] Saw completion logs
- [ ] Safari closed automatically
- [ ] Success alert appeared

### 8. Verify Enrollment Status
Back in Biometric Setup screen:
- [ ] Status shows "✅ Enrolled"
- [ ] No more "Set Up Face ID" button
- [ ] See "Re-enroll" button instead

### 9. Test Login with Biometrics
- [ ] Logout from app
- [ ] On login screen, see "Sign in with Face ID" button
- [ ] Tap the button
- [ ] Complete Face ID authentication
- [ ] Successfully logged in

## 🐛 Troubleshooting

### Issue: No "🔄 Safari sheet appeared..." log

**Problem**: `.onAppear` not being called on SafariView

**Solutions**:
1. Check if SafariView is properly wrapped
2. Verify iOS version supports lifecycle modifiers on custom views
3. May need to add manual polling trigger

### Issue: Polling logs appear but no "🎉 Enrollment detected..."

**Problem**: `biometricService.isEnrolled` not updating

**Check**:
1. Look for `"✅ Saved biometric_enrolled = true"` in logs
2. Verify backend returns `completed: true`
3. Check `EnrollmentStatusResponse` parsing

### Issue: Completion detected but Safari doesn't close

**Problem**: `showingEnrollmentSheet = false` not working

**Check**:
1. Verify state binding is correct
2. Ensure code runs on main thread
3. Check for Swift UI state update issues

### Issue: Safari closes but no success alert

**Problem**: Alert presentation failing

**Check**:
1. Look for presentation errors in console
2. Verify 0.5 second delay is sufficient
3. Check window scene availability

## 📊 Expected Log Sequence

Here's the complete sequence you should see:

```
1. ✅ Valid URL created: https://192.168.100.9:3002?operationId=...
2. 🔄 Safari sheet appeared - starting enrollment status polling...
3. ⏱️ Polling enrollment status...
4. ⏱️ Polling enrollment status...
5. ⏱️ Polling enrollment status...
   [Continue enrollment in Safari]
6. ⏱️ Polling enrollment status...
7. 📊 HTTP Status Code: 200
8. 🎯 Setting isEnrolled to: true
9. ✅ Saved biometric_enrolled = true to keychain
10. 🎉 Enrollment detected as complete! Closing Safari sheet...
11. ✅ Status polling stopped
12. 🚪 Safari sheet dismissed - stopping polling and refreshing enrollment status
```

## 🎯 Success Indicators

All of these should be true:

- ✅ Polling starts immediately when Safari opens
- ✅ Polling runs every 3 seconds
- ✅ Completion detected within 3 seconds of finishing
- ✅ Safari closes automatically
- ✅ Success alert shows
- ✅ Enrollment status persists after logout
- ✅ Biometric login button appears on login screen

## 📝 What to Report

If any step fails, report:

1. **Which step failed** (step number from checklist)
2. **Last log you saw** (copy the exact log line)
3. **What didn't happen** (expected vs actual)
4. **Full console output** from step 3 onwards
