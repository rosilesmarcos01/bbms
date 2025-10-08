const jwt = require('jsonwebtoken');
const logger = require('../utils/logger');

/**
 * Verify JWT token middleware
 */
const verifyToken = (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        error: 'Access token required',
        code: 'NO_TOKEN'
      });
    }

    const token = authHeader.substring(7); // Remove 'Bearer ' prefix

    // Verify token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    // Add user info to request
    req.user = {
      userId: decoded.userId,
      email: decoded.email,
      role: decoded.role,
      accessLevel: decoded.accessLevel
    };

    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        error: 'Token expired',
        code: 'TOKEN_EXPIRED'
      });
    } else if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({
        error: 'Invalid token',
        code: 'INVALID_TOKEN'
      });
    } else {
      logger.error('❌ Token verification failed:', error.message);
      return res.status(401).json({
        error: 'Token verification failed',
        code: 'TOKEN_VERIFICATION_FAILED'
      });
    }
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
 * Require biometric verification for sensitive actions
 */
const requireBiometric = (req, res, next) => {
  // Check if the request has biometric verification header
  const biometricVerification = req.headers['x-biometric-verification'];
  
  if (!biometricVerification) {
    return res.status(401).json({
      error: 'Biometric verification required for this action',
      code: 'BIOMETRIC_REQUIRED'
    });
  }

  try {
    // Parse and verify biometric verification data
    const verificationData = JSON.parse(biometricVerification);
    
    // Add biometric data to request for further processing
    req.biometric = verificationData;
    
    next();
  } catch (error) {
    return res.status(400).json({
      error: 'Invalid biometric verification data',
      code: 'INVALID_BIOMETRIC_DATA'
    });
  }
};

/**
 * Optional authentication - sets user if token is valid, but doesn't require it
 */
const optionalAuth = (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.substring(7);
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      
      req.user = {
        userId: decoded.userId,
        email: decoded.email,
        role: decoded.role,
        accessLevel: decoded.accessLevel
      };
    }
    
    next();
  } catch (error) {
    // Continue without authentication if token is invalid
    next();
  }
};

module.exports = {
  verifyToken,
  requireRole,
  requireAccessLevel,
  requireBiometric,
  optionalAuth
};