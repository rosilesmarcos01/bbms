const axios = require('axios');
const logger = require('../utils/logger');

// Auth service configuration
const AUTH_SERVICE_URL = process.env.AUTH_SERVICE_URL || 'http://localhost:3001';

/**
 * Middleware to verify JWT tokens with the auth service
 */
const verifyToken = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        error: 'Access token required',
        code: 'NO_TOKEN'
      });
    }

    const token = authHeader.substring(7);

    // Verify token with auth service
    const response = await axios.get(`${AUTH_SERVICE_URL}/api/auth/me`, {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });

    // Add user info to request
    req.user = response.data.user;
    req.token = token;

    next();
  } catch (error) {
    logger.error('❌ Token verification failed:', error.response?.data || error.message);
    
    if (error.response?.status === 401) {
      return res.status(401).json({
        error: 'Invalid or expired token',
        code: 'INVALID_TOKEN'
      });
    }

    return res.status(500).json({
      error: 'Token verification failed',
      code: 'TOKEN_VERIFICATION_ERROR'
    });
  }
};

/**
 * Optional authentication - sets user if token is valid, but doesn't require it
 */
const optionalAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.substring(7);
      
      const response = await axios.get(`${AUTH_SERVICE_URL}/api/auth/me`, {
        headers: {
          'Authorization': `Bearer ${token}`
        }
      });

      req.user = response.data.user;
      req.token = token;
    }
    
    next();
  } catch (error) {
    // Continue without authentication if token is invalid
    next();
  }
};

/**
 * Check if user has required role
 */
const requireRole = (roles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED'
      });
    }

    const userRole = req.user.role;
    const allowedRoles = Array.isArray(roles) ? roles : [roles];

    if (!allowedRoles.includes(userRole)) {
      return res.status(403).json({
        error: 'Insufficient permissions',
        code: 'INSUFFICIENT_PERMISSIONS',
        required: allowedRoles,
        current: userRole
      });
    }

    next();
  };
};

/**
 * Check if user has required access level
 */
const requireAccessLevel = (levels) => {
  const accessLevelHierarchy = {
    'basic': 1,
    'standard': 2,
    'elevated': 3,
    'admin': 4
  };

  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED'
      });
    }

    const userAccessLevel = req.user.accessLevel;
    const userLevel = accessLevelHierarchy[userAccessLevel] || 0;
    const allowedLevels = Array.isArray(levels) ? levels : [levels];
    
    const hasAccess = allowedLevels.some(level => {
      const requiredLevel = accessLevelHierarchy[level] || 0;
      return userLevel >= requiredLevel;
    });

    if (!hasAccess) {
      return res.status(403).json({
        error: 'Insufficient access level',
        code: 'INSUFFICIENT_ACCESS_LEVEL',
        required: allowedLevels,
        current: userAccessLevel
      });
    }

    next();
  };
};

/**
 * Log building access with auth service
 */
const logBuildingAccess = async (userId, zoneId, accessType, method = 'api', deviceId = null) => {
  try {
    await axios.post(`${AUTH_SERVICE_URL}/api/building-access/log`, {
      zoneId,
      accessType,
      method,
      deviceId
    }, {
      headers: {
        'Authorization': `Bearer ${userId}` // This should use proper user token
      }
    });
  } catch (error) {
    logger.warn('⚠️ Failed to log building access:', error.message);
  }
};

/**
 * Check zone access permissions
 */
const checkZoneAccess = async (userId, zoneId, token) => {
  try {
    const response = await axios.get(`${AUTH_SERVICE_URL}/api/building-access/permissions/${zoneId}`, {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });

    return response.data;
  } catch (error) {
    logger.warn('⚠️ Failed to check zone access:', error.message);
    return { hasAccess: false, reason: 'Unable to verify access permissions' };
  }
};

module.exports = {
  verifyToken,
  optionalAuth,
  requireRole,
  requireAccessLevel,
  logBuildingAccess,
  checkZoneAccess
};