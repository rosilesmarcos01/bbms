# Camera Permission Fix - HTTPS Setup

## Problem
iOS Safari requires HTTPS for camera access. With HTTP, camera is blocked.

## Solution
Self-signed SSL certificate for local HTTPS.

## Steps Completed
1. ✅ Created SSL certificate (`localhost-key.pem`, `localhost-cert.pem`)
2. ✅ Updated server.js to support HTTPS
3. ✅ Changed URL from `http://` to `https://` in `.env` files

## Testing

### On Your iPhone:
1. Restart authid-web service: `npm start`
2. Restart auth service: `npm start`  
3. Open BBMS app
4. Tap "Enable Biometric Authentication"
5. **You'll see a certificate warning** - This is expected!
6. Tap "Advanced" → "Proceed anyway"
7. Camera should now work! 📷

## URLs Now:
- Auth Service: `http://192.168.100.9:3001` (HTTP is fine)
- AuthID Web: `https://192.168.100.9:3002` (HTTPS for camera)

## Certificate Warning
The warning appears because the certificate is self-signed (not from a trusted authority). This is normal for development. For production, you'd use a proper certificate from Let's Encrypt or similar.

## Alternative: Option 2 (If HTTPS doesn't work)
Use WKWebView in the iOS app instead of Safari, with camera permissions configured in Info.plist.
