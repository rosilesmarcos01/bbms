# AuthID Login Flow - Visual Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         AUTHID BIOMETRIC LOGIN FLOW                          │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────┐         ┌──────────┐         ┌──────────┐         ┌──────────┐
│  Client  │         │  Backend │         │  AuthID  │         │   User   │
│   App    │         │   API    │         │   UAT    │         │  Device  │
└────┬─────┘         └────┬─────┘         └────┬─────┘         └────┬─────┘
     │                    │                    │                    │
     │                    │                    │                    │
     
┌────┴──────────────────────────────────────────────────────────────────────┐
│ STEP 1: INITIATE AUTHENTICATION                                            │
└────┬──────────────────────────────────────────────────────────────────────┘
     │                    │                    │                    │
     │ POST /biometric-   │                    │                    │
     │ login/initiate     │                    │                    │
     │ { email }          │                    │                    │
     ├───────────────────>│                    │                    │
     │                    │                    │                    │
     │                    │ POST /operations   │                    │
     │                    │ { AccountNumber,   │                    │
     │                    │   Name: "Verify-   │                    │
     │                    │   BioCredential" } │                    │
     │                    ├───────────────────>│                    │
     │                    │                    │                    │
     │                    │ { OperationId,     │                    │
     │                    │   OneTimeSecret }  │                    │
     │                    │<───────────────────┤                    │
     │                    │                    │                    │
     │ { operationId,     │                    │                    │
     │   authUrl,         │                    │                    │
     │   qrCode }         │                    │                    │
     │<───────────────────┤                    │                    │
     │                    │                    │                    │
     
┌────┴──────────────────────────────────────────────────────────────────────┐
│ STEP 2: USER COMPLETES BIOMETRIC SCAN                                      │
└────┬──────────────────────────────────────────────────────────────────────┘
     │                    │                    │                    │
     │ Opens authUrl      │                    │                    │
     ├────────────────────┼────────────────────┼───────────────────>│
     │                    │                    │                    │
     │                    │                    │ User views         │
     │                    │                    │ AuthID web         │
     │                    │                    │ component          │
     │                    │                    │                    │
     │                    │                    │<───────────────────┤
     │                    │                    │ Face scan          │
     │                    │                    │ + liveness         │
     │                    │                    │ check              │
     │                    │                    │                    │
     │                    │                    │ ✓ Scan complete    │
     │                    │                    │<───────────────────┤
     │                    │                    │                    │
     
┌────┴──────────────────────────────────────────────────────────────────────┐
│ STEP 3: POLL FOR COMPLETION                                                │
└────┬──────────────────────────────────────────────────────────────────────┘
     │                    │                    │                    │
     │ GET /poll/:opId    │                    │                    │
     │ (every 2 seconds)  │                    │                    │
     ├───────────────────>│                    │                    │
     │                    │                    │                    │
     │                    │ GET /operations/   │                    │
     │                    │ {opId}/status      │                    │
     │                    ├───────────────────>│                    │
     │                    │                    │                    │
     │                    │ { State: 0 }       │                    │
     │                    │ (Pending)          │                    │
     │                    │<───────────────────┤                    │
     │                    │                    │                    │
     │ { status:          │                    │                    │
     │   "pending" }      │                    │                    │
     │<───────────────────┤                    │                    │
     │                    │                    │                    │
     │        ... wait 2 seconds ...           │                    │
     │                    │                    │                    │
     │ GET /poll/:opId    │                    │                    │
     ├───────────────────>│                    │                    │
     │                    │                    │                    │
     │                    │ GET /operations/   │                    │
     │                    │ {opId}/status      │                    │
     │                    ├───────────────────>│                    │
     │                    │                    │                    │
     │                    │ { State: 1,        │                    │
     │                    │   Result: 1 }      │                    │
     │                    │ (Completed-Success)│                    │
     │                    │<───────────────────┤                    │
     │                    │                    │                    │
     │ { status:          │                    │                    │
     │   "completed" }    │                    │                    │
     │<───────────────────┤                    │                    │
     │                    │                    │                    │
     
┌────┴──────────────────────────────────────────────────────────────────────┐
│ STEP 4: VERIFY PROOF & ISSUE TOKEN                                         │
└────┬──────────────────────────────────────────────────────────────────────┘
     │                    │                    │                    │
     │ POST /biometric-   │                    │                    │
     │ login/verify       │                    │                    │
     │ { operationId,     │                    │                    │
     │   accountNumber }  │                    │                    │
     ├───────────────────>│                    │                    │
     │                    │                    │                    │
     │                    │ GET /operations/   │                    │
     │                    │ {opId}/result      │                    │
     │                    ├───────────────────>│                    │
     │                    │                    │                    │
     │                    │ { IsLive: true,    │                    │
     │                    │   ConfidenceScore, │                    │
     │                    │   FaceMatchScore,  │                    │
     │                    │   ...proof data }  │                    │
     │                    │<───────────────────┤                    │
     │                    │                    │                    │
     │                    │ ┌──────────────┐   │                    │
     │                    │ │  Validate    │   │                    │
     │                    │ │  Proof:      │   │                    │
     │                    │ │  - IsLive    │   │                    │
     │                    │ │  - Injection │   │                    │
     │                    │ │  - Expiry    │   │                    │
     │                    │ │  - PAD       │   │                    │
     │                    │ │  - Confidence│   │                    │
     │                    │ └──────────────┘   │                    │
     │                    │                    │                    │
     │                    │ ┌──────────────┐   │                    │
     │                    │ │  Generate    │   │                    │
     │                    │ │  JWT Token   │   │                    │
     │                    │ └──────────────┘   │                    │
     │                    │                    │                    │
     │ { accessToken,     │                    │                    │
     │   user: {...},     │                    │                    │
     │   biometric: {     │                    │                    │
     │     confidence,    │                    │                    │
     │     faceMatch      │                    │                    │
     │   }                │                    │                    │
     │ }                  │                    │                    │
     │<───────────────────┤                    │                    │
     │                    │                    │                    │
     
┌────┴──────────────────────────────────────────────────────────────────────┐
│ STEP 5: USE TOKEN FOR AUTHENTICATED REQUESTS                               │
└────┬──────────────────────────────────────────────────────────────────────┘
     │                    │                    │                    │
     │ GET /api/auth/me   │                    │                    │
     │ Authorization:     │                    │                    │
     │ Bearer {token}     │                    │                    │
     ├───────────────────>│                    │                    │
     │                    │                    │                    │
     │                    │ ┌──────────────┐   │                    │
     │                    │ │  Verify JWT  │   │                    │
     │                    │ │  Token       │   │                    │
     │                    │ └──────────────┘   │                    │
     │                    │                    │                    │
     │ { user: {...} }    │                    │                    │
     │<───────────────────┤                    │                    │
     │                    │                    │                    │
     │ ✓ Logged in!       │                    │                    │
     │                    │                    │                    │
     
     
═══════════════════════════════════════════════════════════════════════════


PROOF VALIDATION DECISION TREE
═══════════════════════════════════════════════════════════════════════════

                    ┌─────────────────┐
                    │  Get Proof Data │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  Check IsLive   │
                    └────────┬────────┘
                             │
                    ┌────────▼────────────────┐
                    │ IsLive === false?       │
                    │ Injection detected?     │
                    │ Document expired?       │
                    │ PAD = Reject?           │
                    └────┬──────────┬─────────┘
                         │          │
                      YES│          │NO
                         │          │
                 ┌───────▼────┐     │
                 │  ❌ REJECT │     │
                 └────────────┘     │
                                    │
                         ┌──────────▼──────────────┐
                         │ FaceMatch < 0.80?       │
                         │ Confidence < 0.85?      │
                         │ Barcode fail?           │
                         │ PAD = Manual Review?    │
                         └────┬──────────┬─────────┘
                              │          │
                           YES│          │NO
                              │          │
                    ┌─────────▼──────┐   │
                    │ ⚠️ MANUAL      │   │
                    │    REVIEW      │   │
                    └────────────────┘   │
                                         │
                              ┌──────────▼──────┐
                              │  ✅ ACCEPT      │
                              │  Issue Token    │
                              └─────────────────┘


═══════════════════════════════════════════════════════════════════════════


OPERATION STATES
═══════════════════════════════════════════════════════════════════════════

State Codes:
┌───┬──────────┬─────────────────────────────────┐
│ 0 │ Pending  │ User hasn't completed scan yet  │
├───┼──────────┼─────────────────────────────────┤
│ 1 │ Completed│ Scan finished (check Result)    │
├───┼──────────┼─────────────────────────────────┤
│ 2 │ Failed   │ Operation error                 │
├───┼──────────┼─────────────────────────────────┤
│ 3 │ Expired  │ Timeout (5 minutes)             │
└───┴──────────┴─────────────────────────────────┘

Result Codes:
┌───┬─────────┬─────────────────────────────────┐
│ 0 │ None    │ No result yet (still pending)   │
├───┼─────────┼─────────────────────────────────┤
│ 1 │ Success │ Biometric verified successfully │
├───┼─────────┼─────────────────────────────────┤
│ 2 │ Failure │ Biometric verification failed   │
└───┴─────────┴─────────────────────────────────┘


═══════════════════════════════════════════════════════════════════════════


ALTERNATIVE FLOW: ALL-IN-ONE ENDPOINT
═══════════════════════════════════════════════════════════════════════════

┌──────────┐         ┌──────────┐
│  Client  │         │  Backend │
└────┬─────┘         └────┬─────┘
     │                    │
     │ Step 1: Initiate   │
     ├───────────────────>│
     │<───────────────────┤
     │                    │
     │ Step 2: User scans │
     │ (opens URL)        │
     │                    │
     │ Step 3: Complete   │
     │ POST /complete     │
     ├───────────────────>│
     │                    │ ┌──────────────────┐
     │                    │ │ Auto-polls until │
     │                    │ │ completed (60x)  │
     │                    │ │                  │
     │                    │ │ Validates proof  │
     │                    │ │                  │
     │                    │ │ Issues token     │
     │                    │ └──────────────────┘
     │                    │
     │ { accessToken }    │
     │<───────────────────┤
     │                    │
     │ ✓ Done!            │
     │                    │


═══════════════════════════════════════════════════════════════════════════


TIMELINE DIAGRAM
═══════════════════════════════════════════════════════════════════════════

0s    │ Client: POST /initiate
      │ Backend: Create AuthID operation
      │ Response: operationId, authUrl
      │
2s    │ Client: Opens authUrl
      │ User: Sees AuthID UI
      │
5s    │ User: Starts face scan
      │ AuthID: Captures video
      │
10s   │ AuthID: Analyzes liveness
      │ AuthID: Checks face quality
      │
12s   │ Client: Polls status (attempt 1)
      │ Backend: Checks AuthID
      │ Response: "pending"
      │
14s   │ Client: Polls status (attempt 2)
      │ Backend: Checks AuthID
      │ Response: "pending"
      │
15s   │ AuthID: Completes analysis
      │ AuthID: Marks operation complete
      │
16s   │ Client: Polls status (attempt 3)
      │ Backend: Checks AuthID
      │ Response: "completed"
      │
17s   │ Client: POST /verify
      │ Backend: Gets proof result
      │ Backend: Validates proof
      │ Backend: Generates JWT
      │ Response: accessToken
      │
18s   │ Client: Stores token
      │ Client: Redirects to dashboard
      │ ✓ Login complete!


═══════════════════════════════════════════════════════════════════════════
```

## Quick Reference

### Status Progression
```
Initiate → Pending → Completed → Verified → Authenticated ✓
                         ↓
                      Failed → Retry
                         ↓
                      Expired → Restart
```

### HTTP Status Codes
```
200 ✓ Success
202 ⚠ Manual Review Required
400 ✗ Validation Error
401 ✗ Proof Rejected / Auth Failed
404 ✗ User Not Found
429 ✗ Rate Limit Exceeded
500 ✗ Server Error
```

### Timeouts
```
Operation Timeout: 5 minutes (300s)
Polling Timeout: 2 minutes (60 attempts × 2s)
JWT Expiration: 24 hours
Refresh Token: 7 days
```
