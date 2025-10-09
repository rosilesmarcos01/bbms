# AuthID Login Implementation Guide

## Overview
Implementation of biometric login using AuthID.ai proof transactions for authentication.

## Key Concepts from Research

### Authentication Flow
1. **Create Proof Transaction** with `transactionType: "authentication"`
2. **User completes verification** (face scan, liveness check)
3. **Backend polls AuthID** for operation result
4. **Validate proof fields** (IsLive, document checks, expiry, etc.)
5. **Issue JWT token** if proof is acceptable

### Critical Endpoints

#### Create Authentication Transaction
```
POST https://id-uat.authid.ai/IDCompleteBackendEngine/Default/AuthorizationServiceRest/v2/operations
```

#### Get Operation Result
```
GET https://id-uat.authid.ai/IDCompleteBackendEngine/Default/AuthorizationServiceRest/v2/operations/${operationId}/result
```

## Implementation Steps

### 1. Add Authentication Operation to AuthIDService

Add methods to:
- Create authentication proof transaction
- Poll for operation result
- Validate proof contents

### 2. Create Auth Routes for Biometric Login

- **POST /api/auth/biometric-login/initiate** - Start auth transaction
- **GET /api/auth/biometric-login/poll/:operationId** - Poll for result
- **POST /api/auth/biometric-login/verify** - Verify and issue token

### 3. Proof Validation Fields

Must check these fields before accepting login:
- **IsLive** - Liveness check passed
- **DocumentExpiry** - Document not expired  
- **InjectionDetection** - No selfie/document injection
- **PadResult** - Presentation attack detection
- **BarcodeSecurityCheck** - Barcode matches
- **MRZOCRMismatch** - OCR data consistent
- **FaceMatch** - Face matches document

### 4. Security Requirements

✅ **DO:**
- Validate ALL proof fields before issuing token
- Map operationId → user session server-side
- Use signed JWTs with proper expiration
- Store operation metadata (account id, session id)
- Rate limit auth endpoints
- Log all authentication attempts

❌ **DON'T:**
- Accept proof without validation
- Return tokens for arbitrary operations
- Use localStorage for server secrets
- Skip liveness/quality checks

## API Flow Diagram

```
Client                  Backend                   AuthID
  |                       |                          |
  |-- Request Login ----->|                          |
  |                       |-- Create Auth Tx ------->|
  |                       |<-- OperationId + URL ----|
  |<-- Auth URL ----------|                          |
  |                       |                          |
  |========= Opens AuthID UI and completes scan =====|
  |                       |                          |
  |-- Poll Status ------->|                          |
  |                       |-- Get Result ----------->|
  |                       |<-- Proof Data -----------|
  |                       |                          |
  |                       |=== Validates Proof ===   |
  |                       |                          |
  |<-- JWT Token ---------|                          |
```

## Next Steps

1. Update `authIdService.js` with authentication transaction methods
2. Add biometric login routes to `authRoutes.js`
3. Implement proof validation logic
4. Test authentication flow end-to-end
5. Add proper error handling and logging

## Configuration

### Environment Variables Required
```
AUTHID_API_KEY_ID=your_key_id
AUTHID_API_KEY_VALUE=your_key_value
AUTHID_WEB_URL=http://localhost:3002
JWT_SECRET=your_jwt_secret
```

### Transaction Types
- **enrollment** - Register new biometric (EnrollBioCredential)
- **authentication** - Verify existing biometric for login
- **verification** - Step-up authentication for sensitive actions
