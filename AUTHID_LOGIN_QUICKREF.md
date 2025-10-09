# 🚀 AuthID Login - Quick Reference

## 📌 TL;DR
Biometric login is now implemented using AuthID proof transactions. Users scan their face, we validate the proof, and issue a JWT token.

---

## 🔑 Three Ways to Login

### 1️⃣ Step-by-Step (Manual Polling)
```bash
# Step 1: Initiate
POST /api/auth/biometric-login/initiate
{ "email": "user@example.com" }
→ Returns: operationId, authUrl

# Step 2: User opens authUrl and scans face

# Step 3: Poll (repeat until "completed")
GET /api/auth/biometric-login/poll/:operationId
→ Returns: { status: "pending|completed|failed" }

# Step 4: Verify & get token
POST /api/auth/biometric-login/verify
{ "operationId": "...", "accountNumber": "..." }
→ Returns: accessToken, user, biometric
```

### 2️⃣ All-in-One (Auto Polling)
```bash
# Step 1: Initiate (same as above)

# Step 2: User scans face

# Step 3: Complete (waits automatically)
POST /api/auth/biometric-login/complete
{ "operationId": "...", "accountNumber": "..." }
→ Returns: accessToken, user, biometric
```

### 3️⃣ Traditional (Fallback)
```bash
POST /api/auth/login
{ "email": "...", "password": "..." }
→ Returns: accessToken, user
```

---

## 📋 Proof Validation Rules

### ❌ REJECT if:
- Liveness check failed
- Injection detected (selfie or document)
- Document expired
- Presentation attack detected

### ⚠️ MANUAL REVIEW if:
- Face match score < 80%
- Confidence score < 85%
- Barcode mismatch
- MRZ/OCR inconsistency

### ✅ ACCEPT if:
- All checks passed
- High confidence (>85%)
- Good face match (>80%)

---

## 🎯 Response Codes

| Status | Code | Meaning |
|--------|------|---------|
| 200 | `success` | Login successful |
| 202 | `MANUAL_REVIEW_REQUIRED` | Needs human review |
| 400 | `VALIDATION_ERROR` | Bad request |
| 401 | `PROOF_REJECTED` | Security check failed |
| 404 | `USER_NOT_FOUND` | User doesn't exist |
| 429 | `AUTH_RATE_LIMIT_EXCEEDED` | Too many attempts |
| 500 | `LOGIN_ERROR` | Server error |

---

## 🔐 Security Features

- ✅ Comprehensive proof validation
- ✅ Rate limiting (100 req/15min)
- ✅ JWT with expiration
- ✅ HTTP-only refresh tokens
- ✅ Operation → session mapping
- ✅ Complete audit logging

---

## 🧪 Quick Test

```bash
./test-authid-login.sh
```

Or manually:

```bash
# Test initiate
curl -X POST http://localhost:3001/api/auth/biometric-login/initiate \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com"}'

# Open the authUrl from response

# Test poll
curl http://localhost:3001/api/auth/biometric-login/poll/OPERATION_ID

# Test verify
curl -X POST http://localhost:3001/api/auth/biometric-login/verify \
  -H "Content-Type: application/json" \
  -d '{"operationId": "...", "accountNumber": "..."}'

# Test token
curl http://localhost:3001/api/auth/me \
  -H "Authorization: Bearer ACCESS_TOKEN"
```

---

## 📱 Frontend Example

```javascript
// 1. Initiate
const { operationId, authUrl } = await fetch('/api/auth/biometric-login/initiate', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ email })
}).then(r => r.json());

// 2. Open AuthID
window.open(authUrl, '_blank');

// 3. Poll
const poll = setInterval(async () => {
  const { status } = await fetch(`/api/auth/biometric-login/poll/${operationId}`)
    .then(r => r.json());
  
  if (status === 'completed') {
    clearInterval(poll);
    
    // 4. Verify
    const { accessToken } = await fetch('/api/auth/biometric-login/verify', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ operationId, accountNumber: userId })
    }).then(r => r.json());
    
    // 5. Save token
    localStorage.setItem('token', accessToken);
    window.location.href = '/dashboard';
  }
}, 2000);
```

---

## ⚙️ Environment Setup

```bash
# Required
AUTHID_API_KEY_ID=your_key
AUTHID_API_KEY_VALUE=your_secret
AUTHID_WEB_URL=http://localhost:3002
JWT_SECRET=your_jwt_secret

# Optional
JWT_EXPIRES_IN=24h              # Default: 24h
JWT_REFRESH_EXPIRES_IN=7d       # Default: 7d
BCRYPT_ROUNDS=12                # Default: 12
```

---

## 🆘 Common Errors

| Error | Solution |
|-------|----------|
| User not found | Register first via `/api/auth/register` |
| Operation expired | Timeout (5 min). Initiate new login |
| Proof rejected | Liveness failed. Try with real person |
| Manual review | Low confidence. Better lighting/camera |
| Rate limit | Wait 15 minutes or contact support |

---

## 📁 Key Files

- `auth/src/services/authIdService.js` - Core logic
- `auth/src/routes/authRoutes.js` - API endpoints
- `AUTHID_LOGIN_TESTING_GUIDE_V2.md` - Full testing guide
- `test-authid-login.sh` - Automated test script

---

## 🎓 Learn More

- [Full Implementation Guide](./AUTHID_LOGIN_IMPLEMENTATION.md)
- [Testing Guide](./AUTHID_LOGIN_TESTING_GUIDE_V2.md)
- [Complete Summary](./AUTHID_LOGIN_COMPLETE.md)

---

## ✨ What's New?

**Before:** Enrollment only, no login capability
**Now:** Full authentication with proof validation ✅

**Key Changes:**
1. New `VerifyBioCredential` operation (was `EnrollBioCredential`)
2. Comprehensive proof validation (was basic)
3. Three-step login flow (was single step)
4. Production-ready security (rate limiting, validation, logging)

---

## 💡 Pro Tips

1. **Always validate proofs** - Never skip validation
2. **Use the all-in-one endpoint** - Simpler for most use cases
3. **Implement fallback** - Offer password login too
4. **Monitor rejection reasons** - Tune thresholds accordingly
5. **Test with real devices** - Emulators may not work well

---

**Ready to test?** Run `./test-authid-login.sh` or check the testing guide! 🚀
