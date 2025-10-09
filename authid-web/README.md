# AuthID Enrollment Web Interface

A standalone web application for handling AuthID biometric enrollment via their React component.

## Quick Start

```bash
# Install dependencies
cd authid-web
npm install

# Start the server
npm start
```

The server will run on **port 3002** and display your network IP addresses.

## Access URLs

### Local (on your Mac)
```
http://localhost:3002
```

### From iPhone (same network)
```
http://YOUR_MAC_IP:3002
```

**To find your Mac's IP:**
```bash
ipconfig getifaddr en0
```

## How It Works

1. **Backend creates enrollment operation** → Gets `OperationId` and `OneTimeSecret`
2. **Generates URL** → `http://YOUR_IP:3002?operationId=xxx&secret=xxx&baseUrl=...`
3. **User opens URL** → Web page loads AuthID React component
4. **Component handles enrollment** → Camera access, face capture, etc.
5. **Success callback** → Notifies app and shows success message

## URL Parameters

The enrollment page expects these query parameters:

- **`operationId`** (required) - The AuthID operation ID
- **`secret`** (required) - The one-time secret from AuthID
- **`baseUrl`** (optional) - AuthID API base URL (defaults to UAT)

Example:
```
http://localhost:3002?operationId=abc123&secret=xyz789&baseUrl=https%3A%2F%2Fid-uat.authid.ai
```

## Integration with BBMS

The auth service (`auth/src/services/authIdService.js`) automatically generates the enrollment URL:

```javascript
const enrollmentUrl = `${AUTHID_WEB_URL}?operationId=${operationId}&secret=${secret}&baseUrl=...`;
```

## Testing

### 1. Test with Browser
Open the enrollment URL in Safari to verify the page loads and AuthID component initializes.

### 2. Test from iOS App
1. Login to BBMS app
2. Tap "Enable Biometric Authentication"
3. Tap "Open Enrollment Page"
4. Complete face capture
5. See success message

### 3. Test QR Code
Generate QR code containing the enrollment URL and scan with any device on the same network.

## Troubleshooting

### Component doesn't load
- Check console for errors (F12 in browser)
- Verify `@authid/react-component` package exists
- Check network tab for failed requests

### Camera access denied
- Grant camera permissions in browser
- Try on iPhone (better camera support)
- Check HTTPS requirements

### Network access issues
- Ensure iPhone and Mac are on same WiFi
- Check firewall settings
- Verify port 3002 is not blocked

### AuthID API errors
- Verify operation hasn't expired (1 hour timeout)
- Check `operationId` and `secret` are correct
- Ensure base URL is correct

## Environment Variables

Set in `/auth/.env`:

```env
AUTHID_WEB_URL=http://YOUR_IP:3002
```

For production, use your server's public URL:
```env
AUTHID_WEB_URL=https://enroll.yourdomain.com
```

## Production Deployment

### Option 1: Same Server as Backend
```bash
# Run both services with PM2
pm2 start auth/src/server.js --name bbms-auth
pm2 start authid-web/server.js --name authid-web
```

### Option 2: Separate Server
Deploy to Netlify, Vercel, or any static hosting:

```bash
# Build for production
npm run build

# Deploy
netlify deploy --prod
```

### Option 3: Docker
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install --production
COPY . .
EXPOSE 3002
CMD ["npm", "start"]
```

## Notes

- **Port 3002** - Enrollment web interface
- **Port 3001** - BBMS auth service
- **Network Access** - Must be accessible from devices performing enrollment
- **HTTPS** - Some camera APIs require HTTPS in production

## Support

If the `@authid/react-component` package doesn't exist or doesn't work, we may need to:
1. Contact AuthID for proper integration documentation
2. Implement custom camera capture and API calls
3. Use AuthID's alternative integration methods
