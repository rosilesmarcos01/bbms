# Enrollment Auto-Dismiss Fix - UPDATED

## Problem Identified

From the logs, we discovered:
```
Attempt to present <UIAlertController> on ... which is already presenting <PresentationHostingController>
```

**Root Cause**: The polling timer successfully detected enrollment completion, but when it tried to show a success alert, it failed because the Safari sheet was still presented. iOS doesn't allow presenting an alert on top of a presented sheet.

**Additional Issue**: The `.onChange` modifier on `showingEnrollmentSheet` was not being called reliably in the iOS environment.

## Solution Implemented - Version 2

### 1. Direct Lifecycle Management
Instead of using `.onChange` on the binding, we now use `.onAppear` and `.onDisappear` directly on the `SafariView`:

```swift
.sheet(isPresented: $showingEnrollmentSheet) {
    if let url = enrollmentURL {
        SafariView(url: url)
            .onAppear {
                print("🔄 Safari sheet appeared - starting enrollment status polling...")
                startStatusPolling()
            }
            .onDisappear {
                print("🚪 Safari sheet dismissed - stopping polling and refreshing enrollment status")
                stopStatusPolling()
                refreshEnrollmentStatus()
            }
    }
}
```

### 2. Smart Polling with Auto-Dismiss
Modified `startStatusPolling()` in `BiometricEnrollmentView.swift`:

```swift
private func startStatusPolling() {
    statusCheckTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
        print("⏱️ Polling enrollment status...")
        
        // Check if enrollment completed
        if biometricService.isEnrolled {
            print("🎉 Enrollment detected as complete! Closing Safari sheet...")
            // Stop polling immediately
            stopStatusPolling()
            // Dismiss the Safari sheet
            showingEnrollmentSheet = false
            // Show success alert after a small delay to let sheet dismiss
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showEnrollmentSuccessAlert()
            }
        } else {
            // Still in progress, keep checking
            refreshEnrollmentStatus()
        }
    }
}
```

### 3. Proper Alert Presentation
Added `showEnrollmentSuccessAlert()` function:

```swift
private func showEnrollmentSuccessAlert() {
    let alert = UIAlertController(
        title: "🎉 Enrollment Complete!",
        message: "You can now use biometric authentication to log in to BBMS!",
        preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "OK", style: .default))
    
    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let rootViewController = windowScene.windows.first?.rootViewController {
        var presenter = rootViewController
        // Find the topmost presented view controller
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        presenter.present(alert, animated: true)
    }
}
```

## How It Works

1. **When Safari opens**: `.onAppear` is called → starts polling timer
2. **Every 3 seconds**: Timer checks `biometricService.isEnrolled`
3. **When enrollment completes** (backend returns `completed: true`):
   - Timer detects `isEnrolled == true`
   - **Stops polling immediately**
   - **Dismisses Safari sheet** by setting `showingEnrollmentSheet = false`
   - **Waits 0.5 seconds** for sheet animation to complete
   - **Shows success alert** on the now-visible view controller
4. **When Safari closes**: `.onDisappear` is called → stops timer as backup
5. **Keychain is already saved** by `BiometricAuthService.checkEnrollmentProgress()`

## Testing Steps

1. **Rebuild**: Cmd+R (or Cmd+Shift+K first if needed)
2. **Log in** as marcos@bbms.ai
3. **Navigate to Settings → Biometric Setup**
4. **Tap "Set Up Face ID"**
5. **Watch for these NEW logs**:
   ```
   ✅ Valid URL created: https://192.168.100.9:3002?operationId=...
   🔄 Safari sheet appeared - starting enrollment status polling...  ← MUST SEE THIS!
   ⏱️ Polling enrollment status...                                   ← EVERY 3 SECONDS!
   ⏱️ Polling enrollment status...
   ```
6. **Complete the enrollment** in Safari
7. **Watch for completion logs**:
   ```
   🎉 Enrollment detected as complete! Closing Safari sheet...
   ✅ Status polling stopped
   🚪 Safari sheet dismissed - stopping polling and refreshing enrollment status
   ```
8. **Verify**:
   - Safari sheet closes automatically
   - Success alert appears: "🎉 Enrollment Complete!"
   - Biometric Setup view shows "✅ Enrolled"
9. **Logout and test login**:
   - Should see "Sign in with Face ID" button
   - Button should work for authentication

## Critical Success Indicator

**YOU MUST SEE THIS LOG** immediately after Safari opens:
```
🔄 Safari sheet appeared - starting enrollment status polling...
```

If you don't see this log, the `.onAppear` isn't being called, which means there's a deeper issue with the SafariView wrapper.

## Expected Behavior

✅ **Automatic Start**: Polling begins when Safari appears
✅ **Automatic Detection**: Enrollment completion detected within 3 seconds
✅ **Automatic Dismissal**: Safari closes by itself
✅ **Success Alert**: Shows after sheet dismisses
✅ **Keychain Persisted**: `isEnrolled: true` saved automatically
✅ **Login Ready**: Biometric button appears immediately after logout

## Debug Points

If it doesn't work, check for:
1. **"🔄 Safari sheet appeared..."** - MUST appear when Safari opens (if not, SafariView issue)
2. **"⏱️ Polling enrollment status..."** - Should appear every 3 seconds
3. **"🎉 Enrollment detected as complete!"** - Should appear when done
4. **"✅ Saved biometric_enrolled = true"** - From BiometricAuthService
5. **No presentation error** - Alert should show cleanly

## What Changed From Previous Version

**Version 1**: Used `.onChange` modifier → Not being called in iOS environment

**Version 2**: Uses `.onAppear`/`.onDisappear` directly on SafariView → More reliable lifecycle management

