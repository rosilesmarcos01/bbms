#!/bin/bash

# BBMS Network Configuration Helper
# This script helps you update the HOST_IP in all .env files when switching networks

echo "🌐 BBMS Network Configuration"
echo "=============================="
echo ""

# Detect current IP address
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    DETECTED_IP=$(ipconfig getifaddr en0 2>/dev/null)
    if [ -z "$DETECTED_IP" ]; then
        DETECTED_IP=$(ipconfig getifaddr en1 2>/dev/null)
    fi
else
    # Linux
    DETECTED_IP=$(hostname -I | awk '{print $1}')
fi

if [ -z "$DETECTED_IP" ]; then
    echo "⚠️  Could not automatically detect IP address"
    echo ""
    echo "Please find your IP manually:"
    echo "  - Mac: ipconfig getifaddr en0"
    echo "  - Linux: hostname -I"
    echo "  - Windows: ipconfig"
    echo ""
    read -p "Enter your IP address: " DETECTED_IP
else
    echo "📍 Detected IP address: $DETECTED_IP"
    echo ""
    read -p "Use this IP? (y/n): " USE_DETECTED
    
    if [[ ! "$USE_DETECTED" =~ ^[Yy]$ ]]; then
        read -p "Enter your IP address: " DETECTED_IP
    fi
fi

# Function to update .env file
update_env_file() {
    local ENV_FILE=$1
    local SERVICE_NAME=$2
    
    if [ ! -f "$ENV_FILE" ]; then
        echo "⚠️  $SERVICE_NAME .env not found: $ENV_FILE"
        return
    fi
    
    # Backup existing .env
    cp "$ENV_FILE" "$ENV_FILE.backup"
    
    # Update HOST_IP
    if grep -q "^HOST_IP=" "$ENV_FILE"; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|^HOST_IP=.*|HOST_IP=$DETECTED_IP|" "$ENV_FILE"
        else
            sed -i "s|^HOST_IP=.*|HOST_IP=$DETECTED_IP|" "$ENV_FILE"
        fi
    else
        echo "" >> "$ENV_FILE"
        echo "HOST_IP=$DETECTED_IP" >> "$ENV_FILE"
    fi
    
    # Update all service URLs with the new IP
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|http://[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}:|http://$DETECTED_IP:|g" "$ENV_FILE"
    else
        sed -i "s|http://[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}:|http://$DETECTED_IP:|g" "$ENV_FILE"
    fi
    
    echo "✅ Updated $SERVICE_NAME"
}

echo ""
echo "🔄 Updating .env files..."
echo ""

# Update all .env files
update_env_file ".env" "Root"
update_env_file "auth/.env" "Auth Service"
update_env_file "backend/.env" "Backend Service"
update_env_file "authid-web/.env" "AuthID Web"

# Update iOS AppConfig.swift
IOS_CONFIG="BBMS/Config/AppConfig.swift"
if [ -f "$IOS_CONFIG" ]; then
    cp "$IOS_CONFIG" "$IOS_CONFIG.backup"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|static let hostIP = \".*\"|static let hostIP = \"$DETECTED_IP\"|" "$IOS_CONFIG"
    else
        sed -i "s|static let hostIP = \".*\"|static let hostIP = \"$DETECTED_IP\"|" "$IOS_CONFIG"
    fi
    echo "✅ Updated iOS AppConfig"
fi

echo ""
echo "📋 Updated Service URLs:"
echo "  - Backend:    http://$DETECTED_IP:3000"
echo "  - Auth:       http://$DETECTED_IP:3001"
echo "  - AuthID Web: http://$DETECTED_IP:3002"
echo ""
echo "🔄 Next steps:"
echo "  1. Restart all services:"
echo "     cd auth && npm start"
echo "     cd authid-web && npm start"
echo "     cd backend && npm start"
echo ""
echo "  2. Rebuild iOS app in Xcode (AppConfig.swift updated)"
echo ""
echo "  3. Test enrollment from your iPhone:"
echo "     Open: http://$DETECTED_IP:3002?operationId=test&secret=test"
echo ""
echo "💾 Backups saved to: *.env.backup and AppConfig.swift.backup"
