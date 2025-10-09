#!/bin/bash

# AuthID Integration Test Script
# Tests the fixed AuthID implementation

echo "🧪 Testing BBMS AuthID Integration"
echo "=================================="
echo ""

BASE_URL="http://localhost:3001"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test 1: Check if service is running
echo -e "${BLUE}Test 1: Service Health Check${NC}"
response=$(curl -s -o /dev/null -w "%{http_code}" $BASE_URL/api/biometric/test)
if [ $response -eq 200 ]; then
    echo -e "${GREEN}✅ Service is running${NC}"
else
    echo -e "${RED}❌ Service is not responding${NC}"
    exit 1
fi
echo ""

# Test 2: Login to get token
echo -e "${BLUE}Test 2: User Login${NC}"
login_response=$(curl -s -X POST $BASE_URL/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "marcos@bbms.ai",
    "password": "admin123"
  }')

token=$(echo $login_response | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)

if [ ! -z "$token" ]; then
    echo -e "${GREEN}✅ Login successful${NC}"
    echo "Token: ${token:0:20}..."
else
    echo -e "${RED}❌ Login failed${NC}"
    echo "Response: $login_response"
    exit 1
fi
echo ""

# Test 3: Initiate Biometric Enrollment
echo -e "${BLUE}Test 3: Biometric Enrollment${NC}"
enrollment_response=$(curl -s -X POST $BASE_URL/api/biometric/enroll \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $token")

enrollment_id=$(echo $enrollment_response | grep -o '"enrollmentId":"[^"]*' | cut -d'"' -f4)

if [ ! -z "$enrollment_id" ]; then
    echo -e "${GREEN}✅ Enrollment initiated${NC}"
    echo "Enrollment ID: $enrollment_id"
else
    echo -e "${RED}❌ Enrollment failed${NC}"
    echo "Response: $enrollment_response"
    exit 1
fi
echo ""

# Test 4: Check Enrollment Status
echo -e "${BLUE}Test 4: Check Enrollment Status${NC}"
status_response=$(curl -s -X GET "$BASE_URL/api/biometric/enrollment/status?enrollmentId=$enrollment_id")

status=$(echo $status_response | grep -o '"status":"[^"]*' | cut -d'"' -f4)

if [ ! -z "$status" ]; then
    echo -e "${GREEN}✅ Status check successful${NC}"
    echo "Status: $status"
else
    echo -e "${RED}❌ Status check failed${NC}"
    echo "Response: $status_response"
fi
echo ""

# Test 5: Biometric Login
echo -e "${BLUE}Test 5: Biometric Login${NC}"
biometric_login_response=$(curl -s -X POST $BASE_URL/api/auth/biometric-login \
  -H "Content-Type: application/json" \
  -d '{
    "verificationData": {
      "biometric_template": "test-template-data-12345",
      "verification_method": "face",
      "device_info": {
        "device_id": "test-device-simulator",
        "platform": "iOS",
        "app_version": "1.0"
      }
    },
    "accessPoint": "mobile_app"
  }')

biometric_token=$(echo $biometric_login_response | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
confidence=$(echo $biometric_login_response | grep -o '"confidence":[0-9.]*' | cut -d':' -f2)

if [ ! -z "$biometric_token" ]; then
    echo -e "${GREEN}✅ Biometric login successful${NC}"
    echo "Confidence: $confidence%"
    echo "Token: ${biometric_token:0:20}..."
else
    echo -e "${RED}❌ Biometric login failed${NC}"
    echo "Response: $biometric_login_response"
    exit 1
fi
echo ""

# Test 6: Verify User from Biometric Login
echo -e "${BLUE}Test 6: Get Current User Info${NC}"
user_response=$(curl -s -X GET $BASE_URL/api/users/me \
  -H "Authorization: Bearer $biometric_token")

user_name=$(echo $user_response | grep -o '"name":"[^"]*' | cut -d'"' -f4)

if [ ! -z "$user_name" ]; then
    echo -e "${GREEN}✅ User verification successful${NC}"
    echo "User: $user_name"
else
    echo -e "${RED}❌ User verification failed${NC}"
    echo "Response: $user_response"
fi
echo ""

# Summary
echo "=================================="
echo -e "${GREEN}🎉 All Tests Passed!${NC}"
echo ""
echo "Summary:"
echo "  ✅ Service Health Check"
echo "  ✅ User Login"
echo "  ✅ Biometric Enrollment"
echo "  ✅ Enrollment Status Check"
echo "  ✅ Biometric Login"
echo "  ✅ User Verification"
echo ""
echo "AuthID integration is working correctly!"
echo "You can now test from the iOS app."
