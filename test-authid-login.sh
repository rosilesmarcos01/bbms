#!/bin/bash

# AuthID Biometric Login Test Script
# Tests the complete login flow

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AUTH_URL="http://localhost:3001"
TEST_EMAIL="test@example.com"

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  AuthID Biometric Login Test Script   ║${NC}"
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo ""

# Step 1: Initiate Login
echo -e "${YELLOW}[1/4] Initiating biometric login...${NC}"
INIT_RESPONSE=$(curl -s -X POST "${AUTH_URL}/api/auth/biometric-login/initiate" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"${TEST_EMAIL}\"}")

echo "$INIT_RESPONSE" | jq '.'

# Extract operation ID
OPERATION_ID=$(echo "$INIT_RESPONSE" | jq -r '.operationId')
AUTH_URL_LINK=$(echo "$INIT_RESPONSE" | jq -r '.authUrl')

if [ "$OPERATION_ID" = "null" ]; then
  echo -e "${RED}✗ Failed to initiate login${NC}"
  echo "$INIT_RESPONSE"
  exit 1
fi

echo -e "${GREEN}✓ Login initiated${NC}"
echo -e "${BLUE}Operation ID: ${OPERATION_ID}${NC}"
echo ""
echo -e "${YELLOW}╔════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║  MANUAL ACTION REQUIRED                ║${NC}"
echo -e "${YELLOW}╠════════════════════════════════════════╣${NC}"
echo -e "${YELLOW}║  Open this URL and complete face scan: ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}${AUTH_URL_LINK}${NC}"
echo ""

# Step 2: Poll for completion
echo -e "${YELLOW}[2/4] Waiting for authentication to complete...${NC}"
echo -e "${BLUE}Press Enter when you've completed the face scan${NC}"
read -p ""

MAX_POLLS=30
POLL_INTERVAL=2
STATUS="pending"

for i in $(seq 1 $MAX_POLLS); do
  echo -e "${BLUE}Polling attempt $i/$MAX_POLLS...${NC}"
  
  POLL_RESPONSE=$(curl -s "${AUTH_URL}/api/auth/biometric-login/poll/${OPERATION_ID}")
  STATUS=$(echo "$POLL_RESPONSE" | jq -r '.status')
  
  echo "$POLL_RESPONSE" | jq '.'
  
  if [ "$STATUS" = "completed" ]; then
    echo -e "${GREEN}✓ Authentication completed!${NC}"
    break
  elif [ "$STATUS" = "failed" ]; then
    echo -e "${RED}✗ Authentication failed${NC}"
    exit 1
  elif [ "$STATUS" = "expired" ]; then
    echo -e "${RED}✗ Operation expired${NC}"
    exit 1
  fi
  
  sleep $POLL_INTERVAL
done

if [ "$STATUS" != "completed" ]; then
  echo -e "${RED}✗ Timeout waiting for authentication${NC}"
  exit 1
fi

# Step 3: Get user ID (in real app, you'd have this from initiate response or stored)
echo ""
echo -e "${YELLOW}[3/4] Enter the account number (user ID) for verification:${NC}"
read -p "Account Number: " ACCOUNT_NUMBER

# Step 4: Verify and get token
echo ""
echo -e "${YELLOW}[4/4] Verifying proof and requesting token...${NC}"
VERIFY_RESPONSE=$(curl -s -X POST "${AUTH_URL}/api/auth/biometric-login/verify" \
  -H "Content-Type: application/json" \
  -d "{\"operationId\": \"${OPERATION_ID}\", \"accountNumber\": \"${ACCOUNT_NUMBER}\"}")

echo "$VERIFY_RESPONSE" | jq '.'

# Extract token
ACCESS_TOKEN=$(echo "$VERIFY_RESPONSE" | jq -r '.accessToken')

if [ "$ACCESS_TOKEN" = "null" ] || [ -z "$ACCESS_TOKEN" ]; then
  echo -e "${RED}✗ Failed to get access token${NC}"
  echo "$VERIFY_RESPONSE"
  exit 1
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ BIOMETRIC LOGIN SUCCESSFUL!        ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Access Token:${NC}"
echo "$ACCESS_TOKEN"
echo ""

# Test the token
echo -e "${YELLOW}Testing access token...${NC}"
ME_RESPONSE=$(curl -s "${AUTH_URL}/api/auth/me" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}")

echo "$ME_RESPONSE" | jq '.'

USER_EMAIL=$(echo "$ME_RESPONSE" | jq -r '.user.email')

if [ "$USER_EMAIL" != "null" ]; then
  echo ""
  echo -e "${GREEN}✓ Token is valid! Logged in as: ${USER_EMAIL}${NC}"
else
  echo ""
  echo -e "${RED}✗ Token validation failed${NC}"
  exit 1
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  All tests passed! ✓                  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
