# 🔐 BBMS AuthID Integration Usage Guide

## Overview
Your BBMS system now has full AuthID.ai biometric authentication integrated. Here's how to use all the features:

## 🚀 Quick Start

### 1. **Register a New User with Biometric Enrollment**

```bash
# Step 1: Register a new user
curl -X POST http://localhost:3001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Doe",
    "email": "john.doe@company.com",
    "password": "securepassword123",
    "department": "Engineering",
    "role": "user",
    "accessLevel": "standard"
  }'
```

**Response:**
```json
{
  "success": true,
  "message": "User registered successfully",
  "user": {
    "id": "user-uuid",
    "email": "john.doe@company.com",
    "name": "John Doe"
  },
  "biometricEnrollment": {
    "enrollmentId": "enrollment-uuid",
    "enrollmentUrl": "https://authid.ai/enroll/xxx",
    "qrCode": "data:image/png;base64,xxx",
    "expiresAt": "2025-10-09T18:00:00.000Z"
  }
}
```

### 2. **Initiate Biometric Enrollment (Existing Users)**

```bash
curl -X POST http://localhost:3001/api/biometric/enroll \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user-uuid",
    "userData": {
      "name": "John Doe",
      "email": "john.doe@company.com",
      "department": "Engineering",
      "role": "user",
      "accessLevel": "standard"
    }
  }'
```

### 3. **Check Enrollment Status**

```bash
curl -X GET "http://localhost:3001/api/biometric/enrollment/status?enrollmentId=enrollment-uuid"
```

**Response:**
```json
{
  "status": "completed",
  "progress": 100,
  "completed": true,
  "enrollmentData": {
    "verification_methods": ["face", "voice"],
    "quality_score": 95
  }
}
```

### 4. **Biometric Login**

```bash
curl -X POST http://localhost:3001/api/auth/biometric-login \
  -H "Content-Type: application/json" \
  -d '{
    "verificationData": {
      "biometric_template": "base64-encoded-biometric-data",
      "verification_method": "face",
      "device_info": {
        "device_id": "mobile-device-123",
        "platform": "iOS"
      }
    },
    "accessPoint": "main_entrance"
  }'
```

**Response (Success):**
```json
{
  "success": true,
  "message": "Biometric authentication successful",
  "user": {
    "id": "user-uuid",
    "email": "john.doe@company.com",
    "name": "John Doe",
    "accessLevel": "standard"
  },
  "verification": {
    "confidence": 98.5,
    "verificationId": "verification-uuid"
  },
  "tokens": {
    "accessToken": "jwt-token",
    "refreshToken": "refresh-token"
  }
}
```

## 📱 iOS App Integration

### In your iOS BBMS app, you can now use these services:

```swift
// Example: AuthService integration
class AuthService {
    func enrollBiometric(for user: User) async throws -> EnrollmentResult {
        let url = URL(string: "\(baseURL)/api/biometric/enroll")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let enrollmentData = BiometricEnrollmentRequest(
            userId: user.id,
            userData: UserData(
                name: user.name,
                email: user.email,
                department: user.department,
                role: user.role,
                accessLevel: user.accessLevel
            )
        )
        
        request.httpBody = try JSONEncoder().encode(enrollmentData)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(EnrollmentResult.self, from: data)
    }
}
```

## 🛠️ Administrative Functions

### 5. **Update User Access Level**

```bash
curl -X PUT http://localhost:3001/api/users/user-uuid/access-level \
  -H "Authorization: Bearer your-jwt-token" \
  -H "Content-Type: application/json" \
  -d '{
    "accessLevel": "admin"
  }'
```

### 6. **Revoke Biometric Data**

```bash
curl -X DELETE http://localhost:3001/api/biometric/data \
  -H "Authorization: Bearer your-jwt-token" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user-uuid"
  }'
```

### 7. **Re-enroll User (if needed)**

```bash
curl -X POST http://localhost:3001/api/biometric/re-enroll \
  -H "Authorization: Bearer your-jwt-token" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user-uuid",
    "reason": "Quality improvement"
  }'
```

## 🧪 Testing & Development

### Test Biometric Verification (Development Only)

```bash
curl -X POST http://localhost:3001/api/biometric/test-verify \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user-uuid",
    "mockVerificationResult": true,
    "confidence": 95.5
  }'
```

## 📊 Monitoring & Webhooks

### AuthID.ai Webhook Endpoint
- **URL**: `http://your-domain.com/webhooks/authid`
- **Method**: POST
- **Purpose**: Receives real-time events from AuthID.ai

Events handled:
- `enrollment.completed`
- `enrollment.failed`
- `verification.completed`
- `verification.failed`
- `user.updated`

## 🔧 Configuration

### Environment Variables (already configured):
```bash
AUTHID_API_URL=https://api.authid.ai
AUTHID_API_KEY_ID=e10a04fc-0bbc-4872-8e46-3ed1a800c99b
AUTHID_API_KEY_VALUE=yew0dmPpYOHjIbfUsJbR0ukcVvXCcUql
```

## 📱 Mobile App Flow

### Recommended User Experience:

1. **User Registration**:
   - User fills out registration form in iOS app
   - App calls `/api/auth/register`
   - App receives enrollment URL and QR code
   - User completes biometric enrollment via AuthID.ai interface

2. **Daily Access**:
   - User approaches building entrance
   - App captures biometric data (face/voice)
   - App calls `/api/auth/biometric-login`
   - System grants/denies access based on verification

3. **Access Management**:
   - Admins can update access levels via `/api/users/{id}/access-level`
   - Users can re-enroll if needed
   - Biometric data can be revoked when users leave

## 🚨 Emergency Access

Your system still supports traditional login and emergency bypass codes for backup access.

## 📈 Next Steps

1. **Test the endpoints** using the curl commands above
2. **Integrate with your iOS app** using the AuthService patterns
3. **Set up webhook handling** for real-time updates
4. **Configure building access controls** based on verification results
5. **Monitor usage** through the logging system

Need help with any specific integration? Let me know! 🚀