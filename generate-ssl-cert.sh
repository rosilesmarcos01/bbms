#!/bin/bash

# Generate SSL Certificate for Dynamic IP
# This creates a self-signed certificate that works with both localhost and your current IP

echo "🔐 SSL Certificate Generator for BBMS"
echo "====================================="
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
    read -p "Enter your IP address: " DETECTED_IP
else
    echo "📍 Detected IP address: $DETECTED_IP"
    echo ""
    read -p "Use this IP? (y/n): " USE_DETECTED
    
    if [[ ! "$USE_DETECTED" =~ ^[Yy]$ ]]; then
        read -p "Enter your IP address: " DETECTED_IP
    fi
fi

echo ""
echo "🔧 Generating SSL certificate for:"
echo "   - localhost"
echo "   - 127.0.0.1"
echo "   - $DETECTED_IP"
echo ""

# Create OpenSSL config file with SANs (Subject Alternative Names)
cat > /tmp/openssl-san.cnf << EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C=US
ST=California
L=San Francisco
O=BBMS
OU=Development
CN=localhost

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = *.localhost
IP.1 = 127.0.0.1
IP.2 = $DETECTED_IP
EOF

echo "📝 OpenSSL configuration created"

# Generate the certificate
openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout /tmp/localhost-key.pem \
    -out /tmp/localhost-cert.pem \
    -days 365 \
    -config /tmp/openssl-san.cnf \
    -extensions v3_req

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Certificate generated successfully!"
    echo ""
    echo "📋 Installing certificates..."
    
    # Backup existing certificates
    if [ -f "auth/localhost-cert.pem" ]; then
        cp auth/localhost-cert.pem auth/localhost-cert.pem.backup
        echo "   ✓ Backed up auth/localhost-cert.pem"
    fi
    
    if [ -f "authid-web/localhost-cert.pem" ]; then
        cp authid-web/localhost-cert.pem authid-web/localhost-cert.pem.backup
        echo "   ✓ Backed up authid-web/localhost-cert.pem"
    fi
    
    # Copy new certificates to services
    cp /tmp/localhost-cert.pem auth/localhost-cert.pem
    cp /tmp/localhost-key.pem auth/localhost-key.pem
    echo "   ✓ Installed to auth/"
    
    cp /tmp/localhost-cert.pem authid-web/localhost-cert.pem
    cp /tmp/localhost-key.pem authid-web/localhost-key.pem
    echo "   ✓ Installed to authid-web/"
    
    # Clean up temp files
    rm /tmp/openssl-san.cnf
    rm /tmp/localhost-cert.pem
    rm /tmp/localhost-key.pem
    
    echo ""
    echo "🎉 Certificate installation complete!"
    echo ""
    echo "⚠️  IMPORTANT: Trust the certificate on your iPhone:"
    echo ""
    echo "1. Open Safari on your iPhone and go to:"
    echo "   https://$DETECTED_IP:3001"
    echo ""
    echo "2. You'll see a certificate warning - tap 'Show Details'"
    echo ""
    echo "3. Tap 'visit this website' and accept the certificate"
    echo ""
    echo "4. Do the same for:"
    echo "   https://$DETECTED_IP:3002"
    echo ""
    echo "5. Alternatively, you can install the certificate in iOS:"
    echo "   Settings > General > VPN & Device Management"
    echo ""
    echo "🔄 Next steps:"
    echo "1. Restart your services:"
    echo "   cd auth && npm start"
    echo "   cd authid-web && npm start"
    echo ""
    echo "2. Test enrollment from your iPhone"
    echo ""
    echo "💾 Certificate backups saved with .backup extension"
else
    echo ""
    echo "❌ Failed to generate certificate"
    exit 1
fi
