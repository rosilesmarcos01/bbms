const express = require('express');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { body, validationResult } = require('express-validator');
const rateLimit = require('express-rate-limit');

const authIdService = require('../services/authIdService');
const userService = require('../services/userService');
const logger = require('../utils/logger');

const router = express.Router();

// Rate limiting for auth endpoints
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs for auth endpoints (increased from 5)
  message: {
    error: 'Too many authentication attempts, please try again later.',
    code: 'AUTH_RATE_LIMIT_EXCEEDED'
  }
});

// Validation middleware
const validateRegistration = [
  body('name').trim().isLength({ min: 2, max: 100 }).withMessage('Name must be 2-100 characters'),
  body('email').isEmail().normalizeEmail().withMessage('Valid email is required'),
  body('password').isLength({ min: 8 }).withMessage('Password must be at least 8 characters'),
  body('department').trim().isLength({ min: 2, max: 50 }).withMessage('Department is required'),
  body('role').isIn(['admin', 'manager', 'technician', 'user']).withMessage('Valid role is required')
];

const validateLogin = [
  body('email').isEmail().normalizeEmail().withMessage('Valid email is required'),
  body('password').notEmpty().withMessage('Password is required')
];

const validateBiometricLogin = [
  body('verificationData').notEmpty().withMessage('Biometric verification data is required'),
  body('accessPoint').optional().trim()
];

/**
 * Register a new user
 * POST /api/auth/register
 */
router.post('/register', authLimiter, validateRegistration, async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Validation failed',
        code: 'VALIDATION_ERROR',
        details: errors.array()
      });
    }

    const { name, email, password, department, role, accessLevel = 'basic' } = req.body;

    // Check if user already exists
    const existingUser = await userService.getUserByEmail(email);
    if (existingUser) {
      return res.status(409).json({
        error: 'User already exists',
        code: 'USER_EXISTS'
      });
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, parseInt(process.env.BCRYPT_ROUNDS) || 12);

    // Create user
    const user = await userService.createUser({
      name,
      email,
      password: hashedPassword,
      department,
      role,
      accessLevel,
      isActive: true,
      createdAt: new Date()
    });

    // Initiate biometric enrollment
    let biometricEnrollment = null;
    try {
      biometricEnrollment = await authIdService.initiateBiometricEnrollment(user.id, {
        name,
        email,
        department,
        role,
        accessLevel
      });
    } catch (error) {
      logger.warn(`⚠️ Biometric enrollment failed for user ${user.id}:`, error.message);
    }

    // Generate JWT tokens
    const { accessToken, refreshToken } = generateTokens(user);

    // Set refresh token in HTTP-only cookie
    res.cookie('refreshToken', refreshToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      maxAge: 7 * 24 * 60 * 60 * 1000 // 7 days
    });

    logger.info(`👤 User registered successfully: ${email}`);

    res.status(201).json({
      message: 'User registered successfully',
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        department: user.department,
        role: user.role,
        accessLevel: user.accessLevel,
        joinDate: user.createdAt,
        isActive: user.isActive,
        lastLoginAt: user.lastLoginAt,
        createdAt: user.createdAt,
        preferences: {
          notificationsEnabled: true,
          darkModeEnabled: false,
          alertsEnabled: true,
          emailNotifications: true,
          pushNotifications: true,
          language: "English",
          temperatureUnit: "Celsius",
          enableBiometricLogin: false,
          enableBuildingAccess: false,
          requireBiometricForSensitiveActions: false
        }
      },
      accessToken,
      biometricEnrollment
    });

  } catch (error) {
    logger.error('❌ Registration failed:', error.message);
    res.status(500).json({
      error: 'Registration failed',
      code: 'REGISTRATION_ERROR'
    });
  }
});

/**
 * Traditional email/password login
 * POST /api/auth/login
 */
router.post('/login', authLimiter, validateLogin, async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Validation failed',
        code: 'VALIDATION_ERROR',
        details: errors.array()
      });
    }

    const { email, password } = req.body;

    // Get user
    const user = await userService.getUserByEmail(email);
    if (!user?.isActive) {
      return res.status(401).json({
        error: 'Invalid credentials',
        code: 'INVALID_CREDENTIALS'
      });
    }

    // Verify password
    const isValidPassword = await bcrypt.compare(password, user.password);
    if (!isValidPassword) {
      return res.status(401).json({
        error: 'Invalid credentials',
        code: 'INVALID_CREDENTIALS'
      });
    }

    // Generate JWT tokens
    const { accessToken, refreshToken } = generateTokens(user);

    // Set refresh token in HTTP-only cookie
    res.cookie('refreshToken', refreshToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      maxAge: 7 * 24 * 60 * 60 * 1000 // 7 days
    });

    // Log access
    await userService.logUserAccess(user.id, 'password_login', req.ip);

    logger.info(`🔐 User logged in: ${email}`);

    res.json({
      message: 'Login successful',
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        department: user.department,
        role: user.role,
        accessLevel: user.accessLevel,
        joinDate: user.createdAt,
        isActive: user.isActive,
        lastLoginAt: user.lastLoginAt,
        createdAt: user.createdAt,
        preferences: {
          notificationsEnabled: true,
          darkModeEnabled: false,
          alertsEnabled: true,
          emailNotifications: true,
          pushNotifications: true,
          language: "English",
          temperatureUnit: "Celsius",
          enableBiometricLogin: false,
          enableBuildingAccess: false,
          requireBiometricForSensitiveActions: false
        }
      },
      accessToken
    });

  } catch (error) {
    logger.error('❌ Login failed:', error.message);
    res.status(500).json({
      error: 'Login failed',
      code: 'LOGIN_ERROR'
    });
  }
});

/**
 * Biometric authentication login
 * POST /api/auth/biometric-login
 */
router.post('/biometric-login', authLimiter, validateBiometricLogin, async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Validation failed',
        code: 'VALIDATION_ERROR',
        details: errors.array()
      });
    }

    const { verificationData, accessPoint = 'mobile_app' } = req.body;

    // First, try to identify the user by their biometric template
    let user = null;
    if (verificationData.biometric_template) {
      user = await userService.getUserByBiometricTemplate(verificationData.biometric_template);
    }

    if (!user) {
      logger.warn('⚠️ Could not identify user from biometric template');
      return res.status(401).json({
        error: 'User not found or not enrolled',
        code: 'USER_NOT_IDENTIFIED'
      });
    }

    // Verify biometric with AuthID.ai
    const biometricResult = await authIdService.verifyBiometric({
      ...verificationData,
      userId: user.id, // Now we can pass the user ID
      accessPoint
    });

    if (!biometricResult.success) {
      return res.status(401).json({
        error: 'Biometric verification failed',
        code: 'BIOMETRIC_VERIFICATION_FAILED'
      });
    }

    // Double-check user is active
    if (!user?.isActive) {
      return res.status(401).json({
        error: 'User account is inactive',
        code: 'USER_INACTIVE'
      });
    }

    // Generate JWT tokens
    const { accessToken, refreshToken } = generateTokens(user);

    // Set refresh token in HTTP-only cookie
    res.cookie('refreshToken', refreshToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      maxAge: 7 * 24 * 60 * 60 * 1000 // 7 days
    });

    // Log access
    await userService.logUserAccess(user.id, 'biometric_login', req.ip, {
      confidence: biometricResult.confidence,
      verificationId: biometricResult.verificationId
    });

    logger.info(`🔍 Biometric login successful: ${user.email} (confidence: ${biometricResult.confidence})`);

    res.json({
      message: 'Biometric login successful',
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        department: user.department,
        role: user.role,
        accessLevel: user.accessLevel
      },
      accessToken,
      biometric: {
        confidence: biometricResult.confidence,
        verificationId: biometricResult.verificationId
      }
    });

  } catch (error) {
    logger.error('❌ Biometric login failed:', error.message);
    res.status(500).json({
      error: 'Biometric login failed',
      code: 'BIOMETRIC_LOGIN_ERROR'
    });
  }
});

/**
 * Refresh access token
 * POST /api/auth/refresh
 */
router.post('/refresh', async (req, res) => {
  try {
    const refreshToken = req.cookies.refreshToken;
    
    if (!refreshToken) {
      return res.status(401).json({
        error: 'Refresh token not provided',
        code: 'NO_REFRESH_TOKEN'
      });
    }

    // Verify refresh token
    const decoded = jwt.verify(refreshToken, process.env.JWT_SECRET);
    
    // Get user
    const user = await userService.getUserById(decoded.userId);
    if (!user || !user.isActive) {
      return res.status(401).json({
        error: 'User not found or inactive',
        code: 'USER_NOT_FOUND'
      });
    }

    // Generate new access token
    const accessToken = jwt.sign(
      { 
        userId: user.id,
        email: user.email,
        role: user.role,
        accessLevel: user.accessLevel
      },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || '24h' }
    );

    res.json({
      message: 'Token refreshed successfully',
      accessToken
    });

  } catch (error) {
    logger.error('❌ Token refresh failed:', error.message);
    res.status(401).json({
      error: 'Invalid refresh token',
      code: 'INVALID_REFRESH_TOKEN'
    });
  }
});

/**
 * Logout
 * POST /api/auth/logout
 */
router.post('/logout', (req, res) => {
  res.clearCookie('refreshToken');
  
  logger.info('👋 User logged out');
  
  res.json({
    message: 'Logout successful'
  });
});

/**
 * Get current user profile
 * GET /api/auth/me
 */
router.get('/me', require('../middleware/authMiddleware').verifyToken, async (req, res) => {
  try {
    const user = await userService.getUserById(req.user.userId);
    
    if (!user) {
      return res.status(404).json({
        error: 'User not found',
        code: 'USER_NOT_FOUND'
      });
    }

    res.json({
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        department: user.department,
        role: user.role,
        accessLevel: user.accessLevel,
        createdAt: user.createdAt,
        lastLoginAt: user.lastLoginAt
      }
    });

  } catch (error) {
    logger.error('❌ Failed to get user profile:', error.message);
    res.status(500).json({
      error: 'Failed to get user profile',
      code: 'PROFILE_ERROR'
    });
  }
});

/**
 * Generate JWT tokens
 */
function generateTokens(user) {
  const payload = {
    userId: user.id,
    email: user.email,
    role: user.role,
    accessLevel: user.accessLevel
  };

  const accessToken = jwt.sign(payload, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '24h'
  });

  const refreshToken = jwt.sign({ userId: user.id }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d'
  });

  return { accessToken, refreshToken };
}

module.exports = router;