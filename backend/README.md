# BBMS Backend

Backend API for Building Management System with Rubidex Blockchain Integration.

## Quick Start

```bash
# Install dependencies
npm install

# Create environment file
cp .env.example .env

# Start development server
npm run dev
```

## API Endpoints

### Device Management
- `GET /api/devices` - Get all devices from blockchain
- `GET /api/devices/:id` - Get specific device
- `GET /api/devices/:id/history` - Get historical readings

### Temperature Monitoring
- `POST /api/temperature/reading` - Write temperature to blockchain
- `GET /api/temperature/current` - Get current readings
- `POST /api/temperature/alert` - Process temperature alert

### Real-time Updates
- `WebSocket /ws/temperature` - Live temperature updates

## Architecture

```
iOS App ↔ Backend API ↔ Rubidex Blockchain
                ↓
        Push Notifications
```

## Environment Variables

```env
PORT=3000
RUBIDEX_API_URL=https://app.rubidex.ai/api/v1/chaincode/document
RUBIDEX_COLLECTION_ID=fb9147b198b1f7ccc2c91cb8d9bc29bff48d3e34a908d72c95d387f8b8db8771
RUBIDEX_API_KEY=22d9eef8-9d41-4251-bcf0-3f09b4023085
REDIS_URL=redis://localhost:6379
```

## Deployment

The backend is designed to be deployed alongside the iOS app in this monorepo.

### Heroku Deployment
```bash
# From backend directory
git subtree push --prefix=backend heroku main
```

### Docker Deployment
```bash
docker build -t bbms-backend .
docker run -p 3000:3000 bbms-backend
```