# Certificate Trust Auto-Prompt Solution

## Problem
When users start enrollment, they visit `https://10.10.62.45:3002` (authid-web) and trust that certificate. However, when the JavaScript tries to call the auth service at `https://10.10.62.45:3001`, **Safari blocks it** because the certificate for port 3001 hasn't been trusted yet.

**Result:** Enrollment freezes with certificate errors:
```
[Error] The certificate for this server is invalid.
[Error] Failed to load resource: The certificate for this server is invalid.
```

## Root Cause
- Safari treats each port as a separate server
- Trusting `https://10.10.62.45:3002` doesn't trust `https://10.10.62.45:3001`
- User never sees/visits port 3001, so never gets prompted to trust it
- All API calls fail silently with certificate errors

## Solution: Pre-Flight Certificate Check

The enrollment page now **automatically checks** if the auth service (port 3001) is accessible before starting enrollment.

### How It Works

1. **Page loads** → User sees "🔐 AuthID Enrollment - Plain JS Version"

2. **Certificate Check** → JavaScript calls:
   ```javascript
   await fetch('https://10.10.62.45:3001/api/health')
   ```

3. **Two Outcomes:**

   **✅ Certificate Already Trusted:**
   - Fetch succeeds
   - Enrollment starts normally
   - Everything works!

   **❌ Certificate Not Trusted:**
   - Fetch fails with certificate error
   - User sees friendly prompt:
     ```
     🔐 Certificate Trust Required
     
     To complete enrollment, you need to trust the 
     security certificate for our authentication service.
     
     Please follow these steps:
     1. Click the button below
     2. Accept the certificate warning on the new page
     3. Return here to continue enrollment
     
     [Open Auth Service & Trust Certificate]
     [I've Trusted It - Continue Enrollment]
     ```

4. **User Actions:**
   - Clicks "Open Auth Service & Trust Certificate"
   - Safari opens `https://10.10.62.45:3001` in new tab
   - User sees certificate warning
   - User accepts/trusts the certificate
   - Returns to enrollment page
   - Clicks "I've Trusted It - Continue Enrollment"
   - Page reloads, certificate check passes
   - Enrollment proceeds normally!

### Code Changes

#### 1. authid-web/public/index.html

**Added Certificate Check Function:**
```javascript
async function checkAuthServiceAccess() {
    const authServiceUrl = `${window.location.protocol}//${window.location.hostname}:3001/api/health`;
    console.log('🔍 Checking auth service accessibility at:', authServiceUrl);
    
    try {
        await fetch(authServiceUrl, { 
            method: 'GET',
            cache: 'no-cache'
        });
        console.log('✅ Auth service is accessible');
        return true;
    } catch (error) {
        console.warn('❌ Auth service not accessible:', error.message);
        return false;
    }
}
```

**Added Trust Prompt UI:**
```javascript
function showCertificateTrustPrompt() {
    const authServiceUrl = `${window.location.protocol}//${window.location.hostname}:3001`;
    container.innerHTML = `
        <div class="card">
            <h2>🔐 Certificate Trust Required</h2>
            <p>To complete enrollment, you need to trust...</p>
            <button onclick="window.open('${authServiceUrl}', '_blank')">
                Open Auth Service & Trust Certificate
            </button>
            <button onclick="location.reload()">
                I've Trusted It - Continue Enrollment
            </button>
        </div>
    `;
}
```

**Modified Enrollment Flow:**
```javascript
if (!operationId || !secret) {
    // Show missing params error
} else {
    // Check if auth service is accessible before starting enrollment
    checkAuthServiceAccess().then(accessible => {
        if (!accessible) {
            console.log('⚠️ Auth service not accessible - showing certificate trust prompt');
            showCertificateTrustPrompt();
            return;
        }
        
        console.log('✅ Auth service accessible - proceeding with enrollment');
        startEnrollment();
    });
}
```

#### 2. auth/src/server.js

**Added /api/health Endpoint:**
```javascript
// Health check endpoint under /api path (for certificate trust check)
app.get('/api/health', (req, res) => {
  res.json({
    status: 'OK',
    service: 'BBMS Authentication Service',
    timestamp: new Date().toISOString()
  });
});
```

This endpoint:
- Returns simple JSON response
- Doesn't require authentication
- Used solely to test if HTTPS connection works
- Safari will show certificate warning when first accessed

## User Experience

### First-Time Enrollment
1. Open app → Tap "Enroll"
2. Safari opens `https://10.10.62.45:3002`
3. Accept certificate warning for port 3002 ✓
4. Page shows: "🔐 Certificate Trust Required"
5. Tap "Open Auth Service & Trust Certificate"
6. New tab opens `https://10.10.62.45:3001`
7. Accept certificate warning for port 3001 ✓
8. Close tab, return to enrollment page
9. Tap "I've Trusted It - Continue Enrollment"
10. Page reloads, certificate check passes ✓
11. Enrollment proceeds normally! 🎉

### Subsequent Enrollments
1. Open app → Tap "Enroll"
2. Safari opens `https://10.10.62.45:3002`
3. Certificate check passes (both already trusted)
4. Enrollment starts immediately! 🚀

## Benefits

✅ **User-Friendly** - Clear instructions, no confusion
✅ **Automatic Detection** - No manual configuration needed
✅ **One-Time Setup** - Certificates stay trusted
✅ **Graceful Handling** - No silent failures
✅ **Works on iOS/Mac** - Safari on all platforms
✅ **Dynamic IP Support** - Uses `window.location` automatically

## Testing Steps

1. **Reset Safari certificates** (to simulate first-time user):
   - iOS: Settings → Safari → Advanced → Website Data → Remove All
   - Mac: Delete certificates from Keychain Access

2. **Start enrollment in app**
   
3. **Should see certificate prompt** for port 3002
   - Accept it

4. **Should see trust prompt screen** with instructions

5. **Click "Open Auth Service & Trust Certificate"**
   - New tab opens
   - Accept certificate for port 3001

6. **Return to enrollment, click "I've Trusted It"**
   - Page reloads
   - Enrollment starts automatically

7. **Complete selfie**
   - Should work perfectly now! ✓

## Files Modified

- ✅ `authid-web/public/index.html` - Added certificate check and trust prompt
- ✅ `auth/src/server.js` - Added `/api/health` endpoint

## Status
🎯 **READY TO TEST** - This should completely solve the certificate trust issue!
