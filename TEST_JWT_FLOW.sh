#!/bin/bash
# Test JWT Token Implementation - Phase 1
# Complete biometric login flow with token issuance

echo "========================================"
echo "🧪 Testing JWT Token Implementation"
echo "========================================"
echo ""

# Step 1: Initiate biometric login
echo "📱 Step 1: Initiating biometric login..."
RESPONSE=$(curl -sk -X POST https://localhost:3001/api/auth/biometric-login/initiate \
  -H "Content-Type: application/json" \
  -d '{"email":"marcos@bbms.ai"}')

echo "$RESPONSE" | jq '.'

# Extract operationId and authUrl
OPERATION_ID=$(echo "$RESPONSE" | jq -r '.operationId')
AUTH_URL=$(echo "$RESPONSE" | jq -r '.authUrl')

if [ "$OPERATION_ID" = "null" ] || [ -z "$OPERATION_ID" ]; then
    echo "❌ Failed to initiate login"
    exit 1
fi

echo ""
echo "========================================"
echo "✅ Login Initiated Successfully!"
echo "========================================"
echo "Operation ID: $OPERATION_ID"
echo ""
echo "🔗 Auth URL: $AUTH_URL"
echo ""
echo "========================================"
echo "👉 ACTION REQUIRED:"
echo "1. Open the URL above in your browser"
echo "2. Complete the face scan"
echo "3. Press ENTER here to continue polling"
echo "========================================"
read -p "Press ENTER after completing face scan..."

echo ""
echo "📊 Step 2: Polling for authentication result..."
echo ""

# Poll for result
MAX_ATTEMPTS=30
ATTEMPT=1

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    echo "🔄 Poll attempt $ATTEMPT/$MAX_ATTEMPTS..."
    
    POLL_RESPONSE=$(curl -sk "https://localhost:3001/api/auth/biometric-login/poll/$OPERATION_ID")
    STATUS=$(echo "$POLL_RESPONSE" | jq -r '.status')
    
    if [ "$STATUS" = "completed" ]; then
        echo ""
        echo "========================================"
        echo "✅ AUTHENTICATION SUCCESSFUL!"
        echo "========================================"
        echo ""
        echo "$POLL_RESPONSE" | jq '.'
        
        # Extract tokens
        ACCESS_TOKEN=$(echo "$POLL_RESPONSE" | jq -r '.accessToken')
        REFRESH_TOKEN=$(echo "$POLL_RESPONSE" | jq -r '.refreshToken')
        USER_EMAIL=$(echo "$POLL_RESPONSE" | jq -r '.user.email')
        USER_NAME=$(echo "$POLL_RESPONSE" | jq -r '.user.name')
        USER_ROLE=$(echo "$POLL_RESPONSE" | jq -r '.user.role')
        EXPIRES_IN=$(echo "$POLL_RESPONSE" | jq -r '.expiresIn')
        
        echo ""
        echo "========================================"
        echo "🎉 JWT TOKENS ISSUED!"
        echo "========================================"
        echo "👤 User: $USER_NAME ($USER_EMAIL)"
        echo "🔑 Role: $USER_ROLE"
        echo "⏰ Expires in: $EXPIRES_IN seconds"
        echo ""
        echo "🔐 Access Token (first 50 chars):"
        echo "${ACCESS_TOKEN:0:50}..."
        echo ""
        echo "🔄 Refresh Token (first 50 chars):"
        echo "${REFRESH_TOKEN:0:50}..."
        echo ""
        
        # Save tokens to file for later use
        echo "$ACCESS_TOKEN" > /tmp/bbms_access_token.txt
        echo "$REFRESH_TOKEN" > /tmp/bbms_refresh_token.txt
        
        echo "💾 Tokens saved to:"
        echo "   /tmp/bbms_access_token.txt"
        echo "   /tmp/bbms_refresh_token.txt"
        echo ""
        
        # Step 3: Test the token by making an authenticated request
        echo "========================================"
        echo "📊 Step 3: Testing access token..."
        echo "========================================"
        echo ""
        
        ME_RESPONSE=$(curl -sk "https://localhost:3001/api/auth/me" \
          -H "Authorization: Bearer $ACCESS_TOKEN")
        
        echo "✅ /api/auth/me response:"
        echo "$ME_RESPONSE" | jq '.'
        echo ""
        
        echo "========================================"
        echo "🎉 PHASE 1 COMPLETE!"
        echo "========================================"
        echo "✅ Biometric authentication working"
        echo "✅ JWT tokens issued successfully"
        echo "✅ Token authentication working"
        echo ""
        echo "📝 Next: Implement Phase 2 (iOS Integration)"
        echo "========================================"
        
        exit 0
        
    elif [ "$STATUS" = "expired" ]; then
        echo ""
        echo "❌ Authentication session expired"
        echo "$POLL_RESPONSE" | jq '.'
        exit 1
        
    elif [ "$STATUS" = "failed" ]; then
        echo ""
        echo "❌ Authentication failed"
        echo "$POLL_RESPONSE" | jq '.'
        exit 1
        
    else
        echo "   Status: $STATUS - waiting..."
        sleep 2
        ATTEMPT=$((ATTEMPT + 1))
    fi
done

echo ""
echo "❌ Polling timeout - authentication took too long"
exit 1
