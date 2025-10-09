#!/bin/bash

# Test AuthID.ai API Connectivity
# This script tests if your AuthID credentials are valid

echo "🔐 Testing AuthID.ai API Connectivity"
echo "======================================"
echo ""

API_URL="https://id-uat.authid.ai"
API_KEY_ID="e10a04fc-0bbc-4872-8e46-3ed1a800c99b"
API_KEY_VALUE="yew0dmPpYOHjIbfUsJbR0ukcVvXCcUql"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Testing endpoint: ${API_URL}${NC}"
echo ""

# Test 1: Check if API is reachable
echo -e "${BLUE}Test 1: API Reachability${NC}"
if curl -s -I "${API_URL}" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ AuthID UAT API is reachable${NC}"
else
    echo -e "${RED}❌ Cannot reach AuthID UAT API${NC}"
    echo "Check your internet connection"
    exit 1
fi
echo ""

# Test 2: Health check endpoint
echo -e "${BLUE}Test 2: Health Check${NC}"
response=$(curl -s -w "\n%{http_code}" -X GET "${API_URL}/api/v1/health" \
  -H "Content-Type: application/json" \
  -H "X-API-Key-ID: ${API_KEY_ID}" \
  -H "X-API-Key-Value: ${API_KEY_VALUE}")

http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" -eq 200 ]; then
    echo -e "${GREEN}✅ Health check passed${NC}"
    echo "Response: $body"
else
    echo -e "${YELLOW}⚠️  Health endpoint returned: $http_code${NC}"
    echo "Response: $body"
fi
echo ""

# Test 3: Try to initiate a test onboarding (this will fail without valid user data but tests auth)
echo -e "${BLUE}Test 3: API Authentication${NC}"
response=$(curl -s -w "\n%{http_code}" -X POST "${API_URL}/api/v1/onboarding/start" \
  -H "Content-Type: application/json" \
  -H "X-API-Key-ID: ${API_KEY_ID}" \
  -H "X-API-Key-Value: ${API_KEY_VALUE}" \
  -d '{
    "user_id": "test-user-123",
    "email": "test@example.com",
    "first_name": "Test",
    "last_name": "User"
  }')

http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

case "$http_code" in
    200|201)
        echo -e "${GREEN}✅ API credentials are VALID${NC}"
        echo -e "${GREEN}✅ Enrollment can be initiated${NC}"
        echo "Response: $body"
        ;;
    401)
        echo -e "${RED}❌ API credentials are INVALID${NC}"
        echo "Check your AUTHID_API_KEY_ID and AUTHID_API_KEY_VALUE in .env"
        echo "Response: $body"
        ;;
    400)
        echo -e "${YELLOW}⚠️  Bad request (but credentials work)${NC}"
        echo "This is normal - it means your API keys are valid!"
        echo "Response: $body"
        ;;
    403)
        echo -e "${RED}❌ Access forbidden${NC}"
        echo "Your credentials might not have permission for this endpoint"
        echo "Response: $body"
        ;;
    *)
        echo -e "${YELLOW}⚠️  Unexpected response: $http_code${NC}"
        echo "Response: $body"
        ;;
esac
echo ""

echo "======================================"
echo "Summary:"
echo "  API URL: ${API_URL}"
echo "  Key ID: ${API_KEY_ID:0:20}..."
echo ""
echo "If credentials are valid, your app should now work with real AuthID!"
echo ""
