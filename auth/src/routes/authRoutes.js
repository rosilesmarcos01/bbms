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
 * Initiate biometric authentication login
 * POST /api/auth/biometric-login/initiate
 * Step 1: Create authentication proof transaction
 */
router.post('/biometric-login/initiate', authLimiter, [
  body('email').isEmail().normalizeEmail().withMessage('Valid email is required')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Validation failed',
        code: 'VALIDATION_ERROR',
        details: errors.array()
      });
    }

    const { email } = req.body;

    // Get user by email
    const user = await userService.getUserByEmail(email);
    if (!user) {
      return res.status(404).json({
        error: 'User not found',
        code: 'USER_NOT_FOUND'
      });
    }

    if (!user.isActive) {
      return res.status(401).json({
        error: 'User account is inactive',
        code: 'USER_INACTIVE'
      });
    }

    // Check if user has biometric enrolled
    // This assumes you track enrollment status in your user service
    // If not enrolled, they should enroll first
    
    // Initiate authentication with AuthID
    const authOperation = await authIdService.initiateBiometricLogin(user.id, {
      name: user.name,
      email: user.email,
      department: user.department,
      role: user.role
    });

    logger.info(`🔐 Biometric login initiated for: ${email}`, {
      operationId: authOperation.operationId
    });

    res.json({
      message: 'Biometric authentication initiated',
      operationId: authOperation.operationId,
      authUrl: authOperation.authUrl,
      qrCode: authOperation.qrCode,
      expiresAt: authOperation.expiresAt
    });

  } catch (error) {
    logger.error('❌ Failed to initiate biometric login:', error.message);
    res.status(500).json({
      error: 'Failed to initiate biometric login',
      code: 'BIOMETRIC_LOGIN_INITIATION_ERROR',
      message: error.message
    });
  }
});

/**
 * Poll for biometric authentication result
 * GET /api/auth/biometric-login/poll/:operationId
 * Step 2: Check if authentication is complete
 */
router.get('/biometric-login/poll/:operationId', authLimiter, async (req, res) => {
  try {
    const { operationId } = req.params;

    if (!operationId) {
      return res.status(400).json({
        error: 'Operation ID is required',
        code: 'INVALID_OPERATION_ID'
      });
    }

    // Check operation status
    const status = await authIdService.checkOperationStatus(operationId);

    // Handle both numeric states (operations) and string states (transactions)
    // Numeric: State: 0=Pending, 1=Completed, 2=Failed, 3=Expired
    // String: state: 'completed', 'expired', 'unknown'
    // Result: 0=None, 1=Success, 2=Failure (numeric) or 'Success'/'Failed' (string)
    
    const stateStr = typeof status.state === 'string' ? status.state.toLowerCase() : null;
    const resultStr = typeof status.result === 'string' ? status.result.toLowerCase() : null;
    
    // Check for string state (from transactions)
    if (stateStr === 'completed' && (resultStr === 'success' || status.status === 1)) {
      // Transaction completed successfully
      return res.json({
        status: 'completed',
        message: 'Authentication completed successfully',
        operationId
      });
    } else if (stateStr === 'expired' || status.state === 3) {
      // Expired
      return res.json({
        status: 'expired',
        message: 'Authentication session expired',
        operationId
      });
    } else if (stateStr === 'unknown') {
      // Unknown state
      return res.json({
        status: 'pending',
        message: 'Authentication status unknown - still processing',
        operationId
      });
    }
    
    // Check for numeric state (from operations)
    if (status.state === 0) {
      // Still pending
      return res.json({
        status: 'pending',
        message: 'Authentication in progress',
        operationId
      });
    } else if (status.state === 1 && status.result === 1) {
      // Completed successfully
      return res.json({
        status: 'completed',
        message: 'Authentication completed - call verify endpoint',
        operationId
      });
    } else if (status.state === 1 && status.result === 2) {
      // Completed but failed
      return res.json({
        status: 'failed',
        message: 'Biometric verification failed',
        operationId
      });
    } else if (status.state === 2) {
      // Operation failed
      return res.json({
        status: 'failed',
        message: 'Operation failed',
        operationId
      });
    } else if (status.state === 3) {
      // Expired
      return res.json({
        status: 'expired',
        message: 'Operation expired - please try again',
        operationId
      });
    }

    res.json({
      status: 'unknown',
      message: 'Unknown operation state',
      operationId,
      state: status.state,
      result: status.result
    });

  } catch (error) {
    logger.error('❌ Failed to poll biometric login status:', error.message);
    res.status(500).json({
      error: 'Failed to check authentication status',
      code: 'POLL_ERROR',
      message: error.message
    });
  }
});

/**
 * Verify biometric authentication and issue JWT
 * POST /api/auth/biometric-login/verify
 * Step 3: Validate proof and issue access token
 */
router.post('/biometric-login/verify', authLimiter, [
  body('operationId').notEmpty().withMessage('Operation ID is required'),
  body('accountNumber').notEmpty().withMessage('Account number is required')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Validation failed',
        code: 'VALIDATION_ERROR',
        details: errors.array()
      });
    }

    const { operationId, accountNumber } = req.body;

    // Get the operation result (proof data)
    const proofResult = await authIdService.getOperationResult(operationId);

    if (!proofResult.success) {
      return res.status(400).json({
        error: 'Failed to retrieve authentication proof',
        code: 'PROOF_RETRIEVAL_ERROR'
      });
    }

    // Validate the proof
    const validation = authIdService.validateProof(proofResult.result);

    if (validation.decision === 'reject') {
      logger.warn('❌ Authentication proof rejected', {
        operationId,
        accountNumber,
        reasons: validation.reasons
      });

      return res.status(401).json({
        error: 'Authentication proof rejected',
        code: 'PROOF_REJECTED',
        reasons: validation.reasons
      });
    }

    if (validation.decision === 'manual_review') {
      logger.warn('⚠️ Authentication proof requires manual review', {
        operationId,
        accountNumber,
        warnings: validation.warnings
      });

      return res.status(202).json({
        message: 'Authentication requires manual review',
        code: 'MANUAL_REVIEW_REQUIRED',
        warnings: validation.warnings
      });
    }

    // Proof is valid - get user and issue token
    const user = await userService.getUserById(accountNumber);
    
    if (!user) {
      return res.status(404).json({
        error: 'User not found',
        code: 'USER_NOT_FOUND'
      });
    }

    if (!user.isActive) {
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
      operationId,
      confidence: validation.proof.confidenceScore,
      faceMatchScore: validation.proof.faceMatchScore
    });

    logger.info(`✅ Biometric login successful: ${user.email}`, {
      operationId,
      confidence: validation.proof.confidenceScore
    });

    res.json({
      message: 'Biometric login successful',
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
          enableBiometricLogin: true,
          enableBuildingAccess: false,
          requireBiometricForSensitiveActions: false
        }
      },
      accessToken,
      biometric: {
        confidence: validation.proof.confidenceScore,
        faceMatchScore: validation.proof.faceMatchScore,
        operationId
      }
    });

  } catch (error) {
    logger.error('❌ Biometric login verification failed:', error.message);
    res.status(500).json({
      error: 'Biometric login verification failed',
      code: 'VERIFICATION_ERROR',
      message: error.message
    });
  }
});

/**
 * Complete biometric login (all-in-one polling)
 * POST /api/auth/biometric-login/complete
 * Alternative: Wait for completion and verify in one request
 */
router.post('/biometric-login/complete', authLimiter, [
  body('operationId').notEmpty().withMessage('Operation ID is required'),
  body('accountNumber').notEmpty().withMessage('Account number is required')
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Validation failed',
        code: 'VALIDATION_ERROR',
        details: errors.array()
      });
    }

    const { operationId, accountNumber } = req.body;

    // Wait for authentication to complete (with polling)
    const authResult = await authIdService.waitForAuthenticationProof(
      operationId,
      accountNumber,
      60, // max 60 attempts
      2000 // poll every 2 seconds
    );

    if (!authResult.success) {
      return res.status(401).json({
        error: authResult.error || 'Authentication failed',
        code: 'AUTHENTICATION_FAILED'
      });
    }

    // Validate the proof
    const validation = authIdService.validateProof(authResult.proof);

    if (validation.decision === 'reject') {
      logger.warn('❌ Authentication proof rejected', {
        operationId,
        accountNumber,
        reasons: validation.reasons
      });

      return res.status(401).json({
        error: 'Authentication proof rejected',
        code: 'PROOF_REJECTED',
        reasons: validation.reasons
      });
    }

    if (validation.decision === 'manual_review') {
      logger.warn('⚠️ Authentication proof requires manual review', {
        operationId,
        accountNumber,
        warnings: validation.warnings
      });

      return res.status(202).json({
        message: 'Authentication requires manual review',
        code: 'MANUAL_REVIEW_REQUIRED',
        warnings: validation.warnings
      });
    }

    // Proof is valid - get user and issue token
    const user = await userService.getUserById(accountNumber);
    
    if (!user || !user.isActive) {
      return res.status(401).json({
        error: 'User not found or inactive',
        code: 'USER_NOT_FOUND'
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
      operationId,
      confidence: validation.proof.confidenceScore,
      faceMatchScore: validation.proof.faceMatchScore
    });

    logger.info(`✅ Biometric login completed: ${user.email}`, {
      operationId,
      confidence: validation.proof.confidenceScore
    });

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
        confidence: validation.proof.confidenceScore,
        faceMatchScore: validation.proof.faceMatchScore,
        operationId
      }
    });

  } catch (error) {
    logger.error('❌ Biometric login completion failed:', error.message);
    res.status(500).json({
      error: 'Biometric login failed',
      code: 'LOGIN_ERROR',
      message: error.message
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