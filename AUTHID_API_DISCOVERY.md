# 🔍 AuthID API Discovery - Action Required

## ❌ Current Issue

The AuthID API endpoint is returning **404 Not Found**:

```
POST https://id-uat.authid.ai/api/v1/onboarding/start
Response: 404 Not Found
```

**This means the endpoint doesn't exist or the API structure is different.**

---

## 🎯 What You Need:

### **1. AuthID API Documentation**

You need to access the official AuthID.ai API documentation:

**Possible locations:**
- 📚 https://docs.authid.ai
- 📚 https://developer.authid.ai  
- 📚 https://authid.ai/developers
- 📚 AuthID Dashboard → API Documentation
- 📚 Email from AuthID with API docs link

### **2. Find These Specific Endpoints:**

We need the **correct URLs** for:

#### **A. Enrollment/Onboarding:**
```
❓ POST /???/enroll
❓ POST /???/onboard
❓ POST /???/register
```

#### **B. Authentication/Verification:**
```
❓ POST /???/verify
❓ POST /???/authenticate
❓ POST /???/match
```

#### **C. Status Check:**
```
❓ GET /???/status/{id}
❓ GET /???/enrollment/{id}
```

---

## 🔑 Your Current Credentials:

```bash
AUTHID_API_URL=https://id-uat.authid.ai
AUTHID_API_KEY_ID=e10a04fc-0bbc-4872-8e46-3ed1a800c99b
AUTHID_API_KEY_VALUE=yew0dmPpYOHjIbfUsJbR0ukcVvXCcUql
```

---

## 🧪 Quick Tests You Can Run:

### **Test 1: Find Base Endpoints**
```bash
# Try common base paths
curl -I https://id-uat.authid.ai/
curl -I https://id-uat.authid.ai/api
curl -I https://id-uat.authid.ai/v1
curl -I https://id-uat.authid.ai/api/v1
```

### **Test 2: Try Common Endpoint Names**
```bash
# Test enrollment endpoints
curl -X POST https://id-uat.authid.ai/api/enroll \
  -H "X-API-Key-ID: e10a04fc-0bbc-4872-8e46-3ed1a800c99b" \
  -H "X-API-Key-Value: yew0dmPpYOHjIbfUsJbR0ukcVvXCcUql"

curl -X POST https://id-uat.authid.ai/enroll \
  -H "X-API-Key-ID: e10a04fc-0bbc-4872-8e46-3ed1a800c99b" \
  -H "X-API-Key-Value: yew0dmPpYOHjIbfUsJbR0ukcVvXCcUql"

curl -X POST https://id-uat.authid.ai/onboard \
  -H "X-API-Key-ID: e10a04fc-0bbc-4872-8e46-3ed1a800c99b" \
  -H "X-API-Key-Value: yew0dmPpYOHjIbfUsJbR0ukcVvXCcUql"
```

### **Test 3: Check Auth Header Format**
```bash
# Maybe it uses Authorization header instead?
curl -X POST https://id-uat.authid.ai/api/v1/onboarding/start \
  -H "Authorization: Bearer e10a04fc-0bbc-4872-8e46-3ed1a800c99b:yew0dmPpYOHjIbfUsJbR0ukcVvXCcUql"
```

---

## 📞 **Contact AuthID Support**

You may need to contact AuthID directly:

### **What to Ask:**

1. **"What are the correct API endpoints for:"**
   - User enrollment/onboarding
   - Biometric verification/authentication
   - Status checking

2. **"What is the authentication header format?"**
   - X-API-Key-ID / X-API-Key-Value?
   - Authorization: Bearer?
   - API-Key?

3. **"Is there API documentation or a Postman collection available?"**

4. **"What is the base URL for:"**
   - UAT environment
   - Production environment

---

## 🔄 Alternative Options:

### **Option A: SDK Integration**

Does AuthID provide an SDK?
```bash
# Check if they have npm package
npm search authid

# Or check for official SDKs
# - authid-node
# - @authid/sdk
# - authid-js
```

### **Option B: Check Your Onboarding Email**

When you signed up for AuthID, they likely sent:
- Welcome email with API docs link
- Integration guide
- Sample code
- API reference

### **Option C: Dashboard/Portal**

Log into your AuthID account at:
- https://portal.authid.ai
- https://dashboard.authid.ai
- https://console.authid.ai

Look for:
- API Documentation
- Integration Guide
- Developer Tools
- API Keys & Endpoints

---

## 🎯 **Next Steps:**

1. ✅ **Find the API documentation**
2. ✅ **Get the correct endpoint URLs**
3. ✅ **Verify the authentication header format**
4. ✅ **I'll update the code with correct endpoints**

---

## 📝 **What to Send Me:**

Once you find the documentation, send me:

```
1. Enrollment endpoint: POST /correct/path/here
2. Verification endpoint: POST /correct/path/here
3. Status endpoint: GET /correct/path/here
4. Authentication header format: X-API-Key or Authorization?
5. Example request body format (JSON structure)
```

Then I can update the code immediately! 🚀

---

**Status:** ⏸️ **Waiting for correct API endpoints**  
**Action Required:** Find AuthID API documentation  
**Blocking:** 404 errors on all API calls
