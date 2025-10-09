#!/bin/bash

# Test AuthID Biometric Login Flow
# Complete step-by-step test

echo "🔐 AuthID Biometric Login Test"
echo "=============================="
echo ""

# Step 1: Initiate Login
echo "Step 1: Initiating biometric login..."
RESPONSE=$(curl -k -s -X POST https://localhost:3001/api/auth/biometric-login/initiate \
  -H "Content-Type: application/json" \
  -d '{"email": "marcos@bbms.ai"}')

echo "$RESPONSE" | jq .

OPERATION_ID=$(echo "$RESPONSE" | jq -r '.operationId')
AUTH_URL=$(echo "$RESPONSE" | jq -r '.authUrl')

if [ "$OPERATION_ID" = "null" ]; then
  echo "❌ Failed to initiate login"
  exit 1
fi

echo ""
echo "✅ Login initiated!"
echo "📱 Operation ID: $OPERATION_ID"
echo ""
echo "🌐 Open this URL and complete biometric scan:"
echo "$AUTH_URL"
echo ""
read -p "Press Enter after completing the scan..."

# Step 2: Poll for status
echo ""
echo "Step 2: Polling for authentication status..."
for i in {1..30}; do
  echo "Poll attempt $i/30..."
  
  STATUS_RESPONSE=$(curl -k -s "https://localhost:3001/api/auth/biometric-login/poll/$OPERATION_ID")
  STATUS=$(echo "$STATUS_RESPONSE" | jq -r '.status')
  
  echo "$STATUS_RESPONSE" | jq .
  
  if [ "$STATUS" = "completed" ]; then
    echo "✅ Authentication completed!"
    break
  elif [ "$STATUS" = "failed" ] || [ "$STATUS" = "expired" ]; then
    echo "❌ Authentication $STATUS"
    exit 1
  fi
  
  sleep 2
done

if [ "$STATUS" != "completed" ]; then
  echo "⏰ Timeout - authentication still pending"
  exit 1
fi

# Step 3: Verify and get token
echo ""
echo "Step 3: Verifying proof and requesting token..."

# Get user ID (you should have this from your user records)
read -p "Enter your user ID (account number): " USER_ID

VERIFY_RESPONSE=$(curl -k -s -X POST https://localhost:3001/api/auth/biometric-login/verify \
  -H "Content-Type: application/json" \
  -d "{\"operationId\": \"$OPERATION_ID\", \"accountNumber\": \"$USER_ID\"}")

echo "$VERIFY_RESPONSE" | jq .

ACCESS_TOKEN=$(echo "$VERIFY_RESPONSE" | jq -r '.accessToken')

if [ "$ACCESS_TOKEN" = "null" ] || [ -z "$ACCESS_TOKEN" ]; then
  echo "❌ Failed to get access token"
  exit 1
fi

echo ""
echo "✅ Biometric login successful!"
echo ""
echo "🎟️  Access Token: $ACCESS_TOKEN"
echo ""

# Step 4: Test the token
echo "Step 4: Testing access token..."
ME_RESPONSE=$(curl -k -s "https://localhost:3001/api/auth/me" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

echo "$ME_RESPONSE" | jq .

USER_EMAIL=$(echo "$ME_RESPONSE" | jq -r '.user.email')

if [ "$USER_EMAIL" != "null" ]; then
  echo ""
  echo "✅ Token is valid! Logged in as: $USER_EMAIL"
  echo ""
  echo "🎉 BIOMETRIC LOGIN TEST PASSED!"
else
  echo ""
  echo "❌ Token validation failed"
  exit 1
fi
