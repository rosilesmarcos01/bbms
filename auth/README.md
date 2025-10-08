# BBMS Authentication Service

A dedicated authentication service for the Building Management System (BBMS) with AuthID.ai biometric verification integration.

## Features

- **Multi-factor Authentication**: Traditional email/password + AuthID.ai biometric verification
- **Building Access Control**: Zone-based access permissions with role hierarchy
- **Session Management**: JWT tokens with refresh token support
- **Audit Trail**: Comprehensive logging of all authentication and access events
- **Webhook Integration**: Real-time updates from AuthID.ai for enrollment and verification events
- **Security Monitoring**: Rate limiting, security alerts, and suspicious activity detection

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   iOS BBMS App  │────│   Auth Service   │────│   AuthID.ai     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │
                              │
                       ┌──────────────────┐
                       │   Main Backend   │
                       └──────────────────┘
```

## Getting Started

### Prerequisites

- Node.js 16+
- Redis (for session management)
- AuthID.ai account and API credentials

### Installation

1. Install dependencies:
```bash
npm install
```

2. Copy environment variables:
```bash
cp .env.example .env
```

3. Configure your environment variables in `.env`:
   - `AUTHID_CLIENT_ID`: Your AuthID.ai client ID
   - `AUTHID_CLIENT_SECRET`: Your AuthID.ai client secret
   - `JWT_SECRET`: Strong secret for JWT token signing
   - `REDIS_URL`: Redis connection string

### Running the Service

Development mode:
```bash
npm run dev
```

Production mode:
```bash
npm start
```

## API Endpoints

### Authentication

- `POST /api/auth/register` - Register new user with biometric enrollment
- `POST /api/auth/login` - Traditional email/password login
- `POST /api/auth/biometric-login` - Biometric authentication
- `POST /api/auth/refresh` - Refresh access token
- `POST /api/auth/logout` - Logout and clear tokens
- `GET /api/auth/me` - Get current user profile

### Biometric Management

- `POST /api/biometric/enroll` - Initiate biometric enrollment
- `GET /api/biometric/enrollment/status` - Check enrollment status
- `POST /api/biometric/re-enroll` - Re-enroll biometric data
- `DELETE /api/biometric/data` - Delete biometric data
- `POST /api/biometric/test-verify` - Test biometric verification
- `GET /api/biometric/settings` - Get biometric settings
- `PUT /api/biometric/preferences` - Update biometric preferences

### User Management

- `GET /api/users/profile` - Get user profile
- `PUT /api/users/profile` - Update user profile
- `GET /api/users/access-logs` - Get user access history
- `GET /api/users` - Get all users (admin/manager only)
- `PUT /api/users/:userId/permissions` - Update user permissions (admin only)
- `DELETE /api/users/:userId` - Deactivate user (admin only)
- `GET /api/users/search` - Search users (admin/manager only)
- `GET /api/users/stats/building-access` - Access statistics (admin/manager only)

### Building Access Control

- `POST /api/building-access/log` - Log building zone access
- `GET /api/building-access/history` - Get access history
- `GET /api/building-access/permissions/:zoneId` - Check zone access permissions
- `GET /api/building-access/zones` - Get available building zones
- `GET /api/building-access/stats` - Building access statistics (admin/manager only)

### Webhooks

- `POST /webhooks/authid` - AuthID.ai webhook endpoint
- `GET /webhooks/authid/health` - Webhook health check

## User Roles and Access Levels

### Roles
- **admin**: Full system access
- **manager**: User management and statistics access
- **technician**: Maintenance area access
- **user**: Basic building access

### Access Levels
- **basic**: Lobby and emergency exits
- **standard**: General office areas
- **elevated**: Private offices and sensitive areas
- **admin**: Server rooms and critical infrastructure

## Building Zones

The system supports the following building zones:

1. **Lobby** (basic access)
2. **General Office Area** (standard access)
3. **Private Offices** (elevated access, biometric required)
4. **Server Room** (admin access, biometric required)
5. **Maintenance Area** (technician role required)
6. **Emergency Exits** (always accessible)

## Security Features

### Rate Limiting
- Authentication endpoints: 5 requests per 15 minutes
- General API: 100 requests per 15 minutes

### Token Security
- Access tokens: 24-hour expiration
- Refresh tokens: 7-day expiration, HTTP-only cookies
- Automatic token refresh capability

### Biometric Security
- AuthID.ai integration for face and voice recognition
- Confidence score monitoring
- Spoofing detection and alerts
- Automatic enrollment quality validation

### Audit Trail
- All authentication events logged
- Building access tracking
- Security alert monitoring
- Failed attempt detection

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `PORT` | Server port (default: 3001) | No |
| `NODE_ENV` | Environment (development/production) | No |
| `JWT_SECRET` | JWT signing secret | Yes |
| `JWT_EXPIRES_IN` | Access token expiration | No |
| `JWT_REFRESH_EXPIRES_IN` | Refresh token expiration | No |
| `AUTHID_API_URL` | AuthID.ai API endpoint | No |
| `AUTHID_CLIENT_ID` | AuthID.ai client ID | Yes |
| `AUTHID_CLIENT_SECRET` | AuthID.ai client secret | Yes |
| `AUTHID_WEBHOOK_SECRET` | AuthID.ai webhook secret | Yes |
| `REDIS_URL` | Redis connection string | No |
| `ALLOWED_ORIGINS` | CORS allowed origins | No |
| `BUILDING_ID` | Unique building identifier | No |
| `FACILITY_NAME` | Building facility name | No |

## Development

### Project Structure

```
src/
├── middleware/
│   ├── authMiddleware.js    # JWT and permission middleware
│   └── errorHandler.js      # Global error handling
├── routes/
│   ├── authRoutes.js        # Authentication endpoints
│   ├── biometricRoutes.js   # Biometric management
│   ├── userRoutes.js        # User management
│   ├── buildingAccessRoutes.js # Building access control
│   └── webhookRoutes.js     # AuthID.ai webhooks
├── services/
│   ├── authIdService.js     # AuthID.ai integration
│   └── userService.js       # User data management
├── utils/
│   └── logger.js           # Winston logging configuration
└── server.js               # Express app setup
```

### Testing

Run tests:
```bash
npm test
```

### Linting

Check code style:
```bash
npm run lint
```

Fix code style issues:
```bash
npm run lint:fix
```

## Integration with iOS App

The iOS BBMS app should integrate with this service for:

1. **User Registration**: Create account with biometric enrollment
2. **Authentication**: Support both password and biometric login
3. **Building Access**: Request access permissions and log zone entries
4. **Profile Management**: Update user preferences and view access history

### Example iOS Integration

```swift
// Biometric login example
func performBiometricLogin(verificationData: [String: Any]) async {
    let request = BiometricLoginRequest(
        verificationData: verificationData,
        accessPoint: "ios_app"
    )
    
    do {
        let response = try await authService.biometricLogin(request)
        // Handle successful login
        await UserSession.shared.setUser(response.user, token: response.accessToken)
    } catch {
        // Handle login error
        print("Biometric login failed: \(error)")
    }
}
```

## Production Deployment

### Docker

Build the image:
```bash
docker build -t bbms-auth-service .
```

Run the container:
```bash
docker run -p 3001:3001 --env-file .env bbms-auth-service
```

### Environment Setup

1. Set up Redis instance
2. Configure AuthID.ai webhooks to point to your service
3. Set strong JWT secrets
4. Configure proper CORS origins
5. Set up SSL/TLS certificates
6. Configure logging and monitoring

## Security Considerations

1. **Never expose JWT secrets** in logs or client-side code
2. **Use HTTPS** in production for all communications
3. **Regularly rotate** JWT secrets and AuthID.ai credentials
4. **Monitor** failed authentication attempts and suspicious patterns
5. **Implement** proper backup and disaster recovery for user data
6. **Keep dependencies updated** to patch security vulnerabilities

## License

MIT License - see LICENSE file for details.