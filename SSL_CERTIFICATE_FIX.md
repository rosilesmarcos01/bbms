# SSL Certificate Issue - "One Moment Please" Fix

## Problem

The "One Moment Please" freeze happens because of SSL certificate validation errors:

```
[Error] Failed to load resource: The certificate for this server is invalid.
[Error] The certificate for this server is invalid.
```

### Root Cause

The `localhost-cert.pem` certificates are only valid for:
- ✅ `localhost`
- ✅ `127.0.0.1`

They are **NOT** valid for:
- ❌ `10.10.62.45` (or any network IP address)

When the authid-web page at `https://10.10.62.45:3002` tries to call the auth service at `https://10.10.62.45:3001`, the browser rejects the request because the certificate doesn't match the IP address.

## Solutions

### Option 1: Use HTTP for Auth Service (Simplest)

Change the auth service to use HTTP instead of HTTPS for network access:

**In `auth/.env`:**
```properties
AUTH_SERVICE_URL=http://10.10.62.45:3001
```

**In `authid-web/public/index.html` (lines 244, 359):**
```javascript
// Change HTTPS to HTTP for local network
const apiUrl = `http://${window.location.hostname}:3001/api/biometric/operation/${operationId}/status`;
const completeUrl = `http://${window.location.hostname}:3001/api/biometric/operation/${operationId}/complete`;
```

**Pros:**
- ✅ Quick fix
- ✅ No certificate management needed
- ✅ Works immediately

**Cons:**
- ⚠️ Auth service traffic is unencrypted on the local network
- ⚠️ Mixed content warnings (HTTPS page calling HTTP API)

---

### Option 2: Generate Certificate for Your IP (Recommended)

Generate a self-signed SSL certificate that includes your current IP address.

#### Step 1: Run the Certificate Generator

```bash
./generate-ssl-cert.sh
```

This will:
1. Detect your current IP address
2. Generate a new SSL certificate valid for:
   - `localhost`
   - `127.0.0.1`
   - Your current IP (e.g., `10.10.62.45`)
3. Backup existing certificates
4. Install new certificates to `auth/` and `authid-web/`

#### Step 2: Trust the Certificate on Your iPhone

**Important:** iOS requires you to trust the self-signed certificate.

##### Method A: Trust via Safari (Easier)

1. Open Safari on your iPhone
2. Go to `https://10.10.62.45:3001`
3. Tap "Show Details" on the certificate warning
4. Tap "visit this website" 
5. Accept the certificate
6. Repeat for `https://10.10.62.45:3002`

##### Method B: Install Certificate Profile (More Permanent)

1. Transfer `auth/localhost-cert.pem` to your iPhone (via AirDrop or email)
2. Open the file on iPhone - it will prompt to install a profile
3. Go to **Settings > General > VPN & Device Management**
4. Install the certificate profile
5. Go to **Settings > General > About > Certificate Trust Settings**
6. Enable full trust for the certificate

#### Step 3: Restart Services

```bash
cd auth && npm start
cd authid-web && npm start
```

#### Step 4: Test Enrollment

Try the biometric enrollment flow again from your iOS app.

**Pros:**
- ✅ Secure HTTPS connections
- ✅ No mixed content issues
- ✅ Works for all services

**Cons:**
- ⚠️ Must regenerate certificate when IP changes
- ⚠️ Must trust certificate on each device

---

### Option 3: Use mDNS/Bonjour (Advanced)

Use a `.local` domain name instead of IP addresses:

1. Access services via `macbook.local` instead of `10.10.62.45`
2. Generate certificate for `*.local` domains
3. Update all configs to use `macbook.local:3001`, etc.

**Pros:**
- ✅ Certificate doesn't change when IP changes
- ✅ More user-friendly URLs

**Cons:**
- ⚠️ Requires mDNS/Bonjour support
- ⚠️ May not work on all networks

---

## Recommended Approach

**For Development:**
Use **Option 2** (Generate certificate for IP) and run `./generate-ssl-cert.sh` whenever you switch networks.

**Quick Fix:**
Use **Option 1** (HTTP for auth service) if you need it working immediately.

## Integration with update-ip.sh

You can integrate certificate generation into the network update workflow:

```bash
# After running update-ip.sh, also run:
./generate-ssl-cert.sh
```

This ensures your certificates are always valid for your current IP address.

## Verification

After applying the fix, check the browser console. You should see:

```
✅ [Log] 🔗 Checking status at: https://10.10.62.45:3001/...
✅ [Log] 📊 Status: completed (state: 1, result: 1, completedAt: YES)
✅ [Log] ✅ Operation completed! Stopping polling and showing success.
```

Instead of:

```
❌ [Error] Failed to load resource: The certificate for this server is invalid.
❌ [Error] ❌ Error checking operation status: TypeError: Load failed
```

---

## Files Modified

- `generate-ssl-cert.sh` - New script to generate IP-specific certificates
- `auth/localhost-cert.pem` - Updated certificate (after running script)
- `auth/localhost-key.pem` - Updated private key (after running script)
- `authid-web/localhost-cert.pem` - Updated certificate (after running script)
- `authid-web/localhost-key.pem` - Updated private key (after running script)

## Testing Checklist

- [ ] Certificate generated with current IP
- [ ] Certificate trusted on iPhone
- [ ] Auth service starts with HTTPS
- [ ] AuthID web starts with HTTPS
- [ ] No SSL errors in Safari console
- [ ] Status polling works (no "Load failed" errors)
- [ ] Enrollment completes successfully
- [ ] iOS app receives completion status
