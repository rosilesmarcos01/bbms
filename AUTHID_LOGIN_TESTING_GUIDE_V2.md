# AuthID Biometric Login Testing Guide

## Overview
Complete testing guide for the new AuthID biometric authentication login flow.

## Prerequisites

✅ User must be enrolled in AuthID first (via the enrollment flow)
✅ Auth service must be running on port 3001
✅ AuthID web component must be running on port 3002
✅ Environment variables configured in `auth/.env`

## API Endpoints

### 1. Initiate Biometric Login
**Endpoint:** `POST /api/auth/biometric-login/initiate`

**Purpose:** Start the authentication process and get the AuthID URL

**Request:**
```bash
curl -X POST http://localhost:3001/api/auth/biometric-login/initiate \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com"
  }'
```

**Response:**
```json
{
  "message": "Biometric authentication initiated",
  "operationId": "abc123...",
  "authUrl": "http://localhost:3002?operationId=abc123&secret=xyz&mode=authentication",
  "qrCode": "http://localhost:3002?operationId=abc123&secret=xyz&mode=authentication",
  "expiresAt": "2025-10-09T10:35:00.000Z"
}
```

### 2. Poll for Authentication Status
**Endpoint:** `GET /api/auth/biometric-login/poll/:operationId`

**Purpose:** Check if the user has completed the biometric scan

**Request:**
```bash
curl http://localhost:3001/api/auth/biometric-login/poll/abc123
```

**Response (Pending):**
```json
{
  "status": "pending",
  "message": "Authentication in progress",
  "operationId": "abc123"
}
```

**Response (Completed):**
```json
{
  "status": "completed",
  "message": "Authentication completed - call verify endpoint",
  "operationId": "abc123"
}
```

**Response (Failed):**
```json
{
  "status": "failed",
  "message": "Biometric verification failed",
  "operationId": "abc123"
}
```

### 3. Verify and Issue Token
**Endpoint:** `POST /api/auth/biometric-login/verify`

**Purpose:** Validate the proof and issue JWT token

**Request:**
```bash
curl -X POST http://localhost:3001/api/auth/biometric-login/verify \
  -H "Content-Type: application/json" \
  -d '{
    "operationId": "abc123",
    "accountNumber": "user-id-123"
  }'
```

**Response (Success):**
```json
{
  "message": "Biometric login successful",
  "user": {
    "id": "user-id-123",
    "name": "John Doe",
    "email": "john@example.com",
    "department": "Engineering",
    "role": "admin",
    "accessLevel": "full"
  },
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "biometric": {
    "confidence": 0.95,
    "faceMatchScore": 0.92,
    "operationId": "abc123"
  }
}
```

**Response (Rejected):**
```json
{
  "error": "Authentication proof rejected",
  "code": "PROOF_REJECTED",
  "reasons": [
    "Liveness check failed",
    "Document expired"
  ]
}
```

**Response (Manual Review):**
```json
{
  "message": "Authentication requires manual review",
  "code": "MANUAL_REVIEW_REQUIRED",
  "warnings": [
    "Low face match score: 0.75",
    "PAD requires manual review"
  ]
}
```

### 4. Complete Login (All-in-One)
**Endpoint:** `POST /api/auth/biometric-login/complete`

**Purpose:** Initiate, poll, validate, and issue token in one request

**Request:**
```bash
curl -X POST http://localhost:3001/api/auth/biometric-login/complete \
  -H "Content-Type: application/json" \
  -d '{
    "operationId": "abc123",
    "accountNumber": "user-id-123"
  }'
```

**Note:** This endpoint will wait up to 2 minutes for the user to complete authentication.

## Testing Flows

### Flow 1: Manual Step-by-Step (Recommended for Development)

1. **Initiate Login**
   ```bash
   curl -X POST http://localhost:3001/api/auth/biometric-login/initiate \
     -H "Content-Type: application/json" \
     -d '{"email": "test@example.com"}'
   ```

2. **Open AuthID URL** (from response)
   - Open `authUrl` in mobile browser or desktop
   - Complete face scan and liveness check

3. **Poll for Status** (every 2 seconds)
   ```bash
   curl http://localhost:3001/api/auth/biometric-login/poll/OPERATION_ID
   ```
   - Repeat until status is `completed`

4. **Verify and Get Token**
   ```bash
   curl -X POST http://localhost:3001/api/auth/biometric-login/verify \
     -H "Content-Type: application/json" \
     -d '{
       "operationId": "OPERATION_ID",
       "accountNumber": "USER_ID"
     }'
   ```

5. **Use Access Token**
   ```bash
   curl http://localhost:3001/api/auth/me \
     -H "Authorization: Bearer ACCESS_TOKEN"
   ```

### Flow 2: Automated (All-in-One)

1. **Initiate Login** (same as Flow 1 step 1)

2. **Open AuthID URL and Complete Scan** (manually)

3. **Complete Login** (waits for completion automatically)
   ```bash
   curl -X POST http://localhost:3001/api/auth/biometric-login/complete \
     -H "Content-Type: application/json" \
     -d '{
       "operationId": "OPERATION_ID",
       "accountNumber": "USER_ID"
     }'
   ```

## Testing Checklist

### Happy Path
- [ ] Initiate login with valid email
- [ ] Receive operation ID and auth URL
- [ ] Open auth URL in browser
- [ ] Complete face scan successfully
- [ ] Poll returns "completed" status
- [ ] Verify returns valid JWT token
- [ ] Token works for authenticated endpoints

### Edge Cases
- [ ] Initiate login with non-existent email → 404
- [ ] Initiate login with inactive user → 401
- [ ] Poll before scan complete → "pending"
- [ ] Poll after scan fails → "failed"
- [ ] Poll with invalid operation ID → error
- [ ] Verify before scan complete → error
- [ ] Verify with failed scan → proof rejected
- [ ] Verify with low confidence → manual review
- [ ] Token expires after timeout

### Security Tests
- [ ] Liveness check failure → rejected
- [ ] Injection detection → rejected
- [ ] Expired document → rejected
- [ ] Low face match score → manual review
- [ ] Low confidence score → manual review
- [ ] Rate limiting works (100 requests/15 min)
- [ ] Refresh token in HTTP-only cookie
- [ ] Access token in response body

### Error Handling
- [ ] Invalid email format → validation error
- [ ] Missing required fields → validation error
- [ ] Network timeout during AuthID call → error
- [ ] AuthID service unavailable → error
- [ ] Database unavailable → error

## Common Issues

### Issue: "User not found"
**Solution:** User must be registered first via `/api/auth/register`

### Issue: "Operation not found"
**Solution:** Operation ID might be expired or invalid. Initiate new login.

### Issue: "Authentication requires manual review"
**Solution:** Lighting, camera quality, or face match score is low. Try again with better conditions.

### Issue: "Liveness check failed"
**Solution:** User might be using a photo instead of live video. Must be live person.

### Issue: Polling timeout
**Solution:** User didn't complete scan within 5 minutes. Initiate new login.

## Production Considerations

### Before Going Live

1. **Proof Validation Rules**
   - Review and adjust thresholds in `validateProof()`
   - Consider your risk tolerance
   - Configure manual review workflow

2. **Rate Limiting**
   - Adjust limits based on expected traffic
   - Consider per-user limits in addition to IP limits

3. **Monitoring**
   - Log all authentication attempts
   - Track success/failure rates
   - Monitor proof rejection reasons
   - Alert on unusual patterns

4. **User Experience**
   - Add timeout warnings
   - Provide fallback to password login
   - Clear error messages
   - Support ticket system for manual review

5. **Security**
   - Enable HTTPS in production
   - Use secure cookies
   - Rotate JWT secrets regularly
   - Implement token blacklisting
   - Add device fingerprinting

## Next Steps

1. Test enrollment flow first (users must enroll before login)
2. Test all endpoints with Postman or curl
3. Integrate with mobile app
4. Add UI for login flow
5. Implement fallback mechanisms
6. Set up monitoring and alerting
