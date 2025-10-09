# AuthID Web Enrollment URL - NEEDS RESOLUTION

## Current Status
✅ Backend successfully creates AuthID operations via API
✅ Web component loads correctly  
❌ **BLOCKER**: Don't know the correct web interface URL format

## What We Know

### API Endpoint (Working)
```
POST https://id-uat.authid.ai/IDCompleteBackendEngine/Default/AuthorizationServiceRest/v2/operations
```
Returns: `OperationId` and `OneTimeSecret`

### Web Interface URL (Unknown)
We've tried:
1. ❌ `https://id-uat.authid.ai/?operationId=xxx&secret=yyy` - Shows "not properly initialized" error
2. ❌ `https://id-uat.authid.ai/IDCompleteBackendEngine/.../operations/{id}?secret=xxx` - Returns file download
3. 🔄 `https://id-uat.authid.ai/?OperationId=xxx&OneTimeSecret=yyy` - Currently testing

## What We Need from AuthID

**Question for AuthID Support:**
> After creating an enrollment operation via the Transaction API V2, what is the correct web interface URL format for users to complete biometric enrollment in a browser/iframe?
> 
> We have:
> - OperationId: `{guid}`
> - OneTimeSecret: `{secret}`
> - Environment: UAT (https://id-uat.authid.ai)
>
> What URL should we load in an iframe or browser for the user to capture their biometric?

## Possible Solutions

### Option A: Dedicated Web Portal
AuthID might have a separate web portal URL like:
- `https://enroll-uat.authid.ai/?operation={id}&secret={secret}`
- `https://id-uat.authid.ai/enroll/?operation={id}&secret={secret}`

### Option B: SDK Required
AuthID might require using their native SDK instead of web:
- iOS SDK for face capture
- No web interface available

### Option C: Parameter Format
Different parameter names or format:
- `?OperationId=xxx&OneTimeSecret=yyy` (trying this now)
- `?transactionId=xxx&token=yyy`
- `?session=xxx&auth=yyy`

## Documentation Needed
- AuthID UAT web enrollment URL format
- Required query parameters
- Supported browsers/devices
- Alternative approaches if web enrollment not available

## Files Affected
- `authid-web/public/index.html` - URL construction
- `auth/src/services/authIdService.js` - Enrollment URL generation
- All `.env` files - AUTHID_WEB_URL configuration

## Next Steps
1. Test current format with capital letters (OperationId, OneTimeSecret)
2. Check AuthID documentation portal
3. Contact AuthID support with above question
4. Consider native SDK if web not available
