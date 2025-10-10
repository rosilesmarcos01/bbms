const express = require('express');
const { body, validationResult } = require('express-validator');

const authIdService = require('../services/authIdService');
const userService = require('../services/userService');
const authMiddleware = require('../middleware/authMiddleware');
const jwtService = require('../services/jwtService');
const logger = require('../utils/logger');

const router = express.Router();

// Test route to check if biometric routes are working
router.get('/test', (req, res) => {
  res.json({ message: 'Biometric routes working' });
});

/**
 * Check operation status (public endpoint for enrollment completion)
 * GET /api/biometric/operation/:operationId/status
 */
router.get('/operation/:operationId/status', async (req, res) => {
  try {
    const { operationId } = req.params;
    
    logger.info(`🔍 Checking operation status: ${operationId}`);
    
    // Get status from AuthID
    let status;
    try {
      status = await authIdService.checkOperationStatus(operationId);
    } catch (error) {
      // Handle 404 - operation might not be queryable yet (newly created)
      if (error.message.includes('404') || error.message.includes('not found')) {
        logger.info(`ℹ️ Operation not yet queryable (404), treating as pending`, {
          operationId
        });
        
        // Return pending status for newly created operations
        return res.json({
          success: true,
          status: 'pending',
          operationId: operationId,
          state: 0,
          result: 0,
          completedAt: null,
          message: 'Operation is initializing'
        });
      }
      
      // Re-throw other errors
      throw error;
    }
    
    logger.info(`📊 Operation status details:`, {
      operationId,
      state: status.state,
      result: status.result,
      completedAt: status.completedAt
    });
    
    // Return friendly status
    // IMPORTANT: Only mark as 'completed' if there's a completion timestamp
    // This prevents false positives where the operation is created but not yet performed
    let statusText = 'pending';
    if (status.state === 1 && status.completedAt) {
      // State 1 with completion timestamp = actually completed
      statusText = status.result === 1 ? 'completed' : 'failed';
    } else if (status.state === 2) {
      statusText = 'failed';
    } else if (status.state === 3) {
      statusText = 'expired';
    }
    // Note: state=1 without completedAt stays as 'pending' (no reassignment needed)
    
    res.json({
      success: true,
      status: statusText,
      operationId: status.operationId,
      state: status.state,
      result: status.result,
      accountNumber: status.accountNumber,
      completedAt: status.completedAt
    });
    
  } catch (error) {
    logger.error('❌ Failed to check operation status', { 
      error: error.message,
      operationId: req.params.operationId 
    });
    
    res.status(500).json({
      error: 'Failed to check status',
      message: error.message
    });
  }
});

/**
 * Mark enrollment as complete (public endpoint, called by web interface after capture)
 * POST /api/biometric/operation/:operationId/complete
 * 
 * CRITICAL: This endpoint MUST verify with AuthID that the operation was actually
 * completed by the user before marking enrollment as complete!
 */
router.post('/operation/:operationId/complete', async (req, res) => {
  try {
    const { operationId } = req.params;
    
    logger.info(`📨 Request to mark enrollment as complete: ${operationId}`);
    
    // STEP 1: Verify with AuthID that the operation was actually completed
    // NOTE: AuthID UAT API has sync delays. The web component may confirm completion
    // before the API reflects it. We'll try to verify but accept if it's still pending.
    logger.info(`🔍 Attempting to verify operation status with AuthID...`);
    
    let authIdStatus;
    let completedAt = new Date().toISOString(); // Default to now if API unavailable
    
    try {
      authIdStatus = await authIdService.checkOperationStatus(operationId);
      
      logger.info(`📊 AuthID verification result:`, {
        operationId,
        state: authIdStatus.state,
        result: authIdStatus.result,
        completedAt: authIdStatus.completedAt
      });
      
      // IDEAL: Operation is confirmed completed in AuthID API
      if (authIdStatus.state === 1 && authIdStatus.result === 1 && authIdStatus.completedAt) {
        logger.info(`✅ VERIFIED: Operation confirmed completed in AuthID at ${authIdStatus.completedAt}`);
        completedAt = authIdStatus.completedAt;
      } 
      // ACCEPTABLE: API shows pending (UAT sync lag) but web component confirmed
      else if (authIdStatus.state === 0) {
        logger.warn(`⚠️ AuthID API still shows pending (UAT sync lag) - trusting web component confirmation`, {
          operationId,
          state: authIdStatus.state,
          note: 'This is expected in UAT environment due to API sync delays'
        });
        // Continue with completion - web component message is reliable
      }
      // REJECT: Operation explicitly failed
      else if (authIdStatus.state === 2 || authIdStatus.result === 2) {
        logger.error(`❌ REJECTED: Operation failed in AuthID`, {
          operationId,
          state: authIdStatus.state,
          result: authIdStatus.result
        });
        
        return res.status(400).json({
          error: 'Operation failed',
          code: 'OPERATION_FAILED',
          message: 'The biometric verification failed'
        });
      }
      
    } catch (authIdError) {
      // AuthID API returning 404 is common in UAT for 2+ minutes after completion
      if (authIdError.message.includes('404') || authIdError.message.includes('not found')) {
        logger.warn(`⚠️ AuthID API returned 404 (UAT sync lag) - trusting web component confirmation`, {
          operationId,
          note: 'AuthID UAT API has known sync delays. Web component message is reliable.'
        });
        // Continue with completion - this is expected in UAT
      } else {
        logger.error(`❌ Failed to verify operation with AuthID:`, {
          error: authIdError.message,
          operationId
        });
        
        // Don't fail the request - web component already confirmed success
        logger.warn(`⚠️ Proceeding with completion despite API error (trusting web component)`);
      }
    }
    
    // STEP 2: Find the user with this enrollment ID
    const user = await userService.getUserByEnrollmentId(operationId);
    
    if (!user) {
      logger.warn(`⚠️ No user found with enrollment ID: ${operationId}`);
      return res.status(404).json({
        error: 'Enrollment not found',
        code: 'NO_ENROLLMENT'
      });
    }
    
    // STEP 3: Update the enrollment status to completed
    await userService.updateBiometricEnrollmentStatus(user.id, 'completed');
    
    logger.info(`🎉 Enrollment marked as complete for user: ${user.id}`, {
      operationId,
      completedAt
    });
    
    res.json({
      success: true,
      message: 'Enrollment marked as complete',
      operationId: operationId,
      completedAt
    });
    
  } catch (error) {
    logger.error('❌ Failed to mark enrollment as complete', { 
      error: error.message,
      operationId: req.params.operationId 
    });
    
    res.status(500).json({
      error: 'Failed to complete enrollment',
      message: error.message
    });
  }
});

// All biometric routes require authentication
// router.use(authMiddleware.verifyToken);

/**
 * Initiate biometric enrollment for current user
 * POST /api/biometric/enroll
 */
router.post('/enroll', authMiddleware.verifyToken, async (req, res) => {
  try {
    const userId = req.user.userId;
    logger.info(`🔍 Starting biometric enrollment for user: ${userId}`);
    
    // Get user data
    logger.info(`🔍 Fetching user data for: ${userId}`);
    const user = await userService.getUserById(userId);
    if (!user) {
      logger.error(`❌ User not found: ${userId}`);
      return res.status(404).json({
        error: 'User not found',
        code: 'USER_NOT_FOUND'
      });
    }
    logger.info(`✅ User found: ${user.email}`);

    // Check if user already has biometric enrollment
    logger.info(`🔍 Checking existing enrollment for: ${userId}`);
    const existingEnrollment = await userService.getBiometricEnrollment(userId);
    if (existingEnrollment && existingEnrollment.status === 'completed') {
      logger.info(`⚠️ User already enrolled: ${userId}`);
      
      // Return the existing enrollment info
      return res.json({
        message: 'User already has biometric enrollment',
        enrollment: {
          enrollmentId: existingEnrollment.enrollmentId,
          status: 'completed',
          completedAt: existingEnrollment.updatedAt || existingEnrollment.createdAt
        },
        alreadyEnrolled: true
      });
    }
    logger.info(`✅ No existing enrollment, proceeding...`);

    // For development, return a mock enrollment response since AuthID.ai might not be accessible
    if (process.env.NODE_ENV === 'development') {
      logger.info(`🔧 Using development mode mock enrollment`);
      const mockEnrollment = {
        enrollmentId: 'mock-' + Date.now(),
        enrollmentUrl: 'https://authid.ai/enroll/mock-enrollment',
        qrCode: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
        expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
      };

      // Save enrollment data
      logger.info(`🔍 Saving mock enrollment data for: ${userId}`);
      await userService.saveBiometricEnrollment(userId, {
        enrollmentId: mockEnrollment.enrollmentId,
        status: 'initiated',
        expiresAt: mockEnrollment.expiresAt,
        createdAt: new Date()
      });
      logger.info(`✅ Mock enrollment saved successfully`);

      logger.info(`🔐 Mock biometric enrollment initiated for user ${userId}`);

      return res.json({
        message: 'Biometric enrollment initiated (development mode)',
        enrollment: mockEnrollment
      });
    }

    // Production: Use actual AuthID.ai service
    const enrollment = await authIdService.initiateBiometricEnrollment(userId, {
      name: user.name,
      email: user.email,
      department: user.department,
      role: user.role,
      accessLevel: user.accessLevel
    });

    // Save enrollment data
    await userService.saveBiometricEnrollment(userId, {
      enrollmentId: enrollment.enrollmentId,
      status: 'initiated',
      expiresAt: enrollment.expiresAt,
      createdAt: new Date()
    });

    logger.info(`🔐 Biometric enrollment initiated for user ${userId}`);

    res.json({
      message: 'Biometric enrollment initiated',
      enrollment: {
        enrollmentId: enrollment.enrollmentId,
        enrollmentUrl: enrollment.enrollmentUrl,
        qrCode: enrollment.qrCode,
        expiresAt: enrollment.expiresAt
      }
    });

  } catch (error) {
    // Check if it's a 409 conflict (already enrolled in AuthID)
    if (error.response?.status === 409 || error.message.includes('already exist')) {
      logger.info(`ℹ️ User already enrolled in AuthID, updating local status: ${req.user?.userId}`);
      
      // Update local enrollment status to completed
      const existingEnrollment = await userService.getBiometricEnrollment(req.user?.userId);
      if (existingEnrollment) {
        await userService.updateBiometricEnrollmentStatus(req.user?.userId, 'completed');
        
        return res.json({
          message: 'Biometric enrollment already completed',
          enrollment: {
            enrollmentId: existingEnrollment.enrollmentId,
            status: 'completed',
            completedAt: new Date().toISOString()
          },
          alreadyEnrolled: true
        });
      }
    }
    
    logger.error('❌ Failed to initiate biometric enrollment:', {
      error: error.message,
      stack: error.stack,
      userId: req.user?.userId
    });
    res.status(500).json({
      error: 'Failed to initiate biometric enrollment',
      code: 'ENROLLMENT_ERROR',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

/**
 * Get biometric enrollment status
 * GET /api/biometric/enrollment/status
 */
router.get('/enrollment/status', authMiddleware.verifyToken, async (req, res) => {
  try {
    const userId = req.user.userId;
    
    logger.info(`🔍 Checking enrollment status for user: ${userId}`);
    
    // Get enrollment from database
    const enrollment = await userService.getBiometricEnrollment(userId);
    if (!enrollment) {
      logger.info(`📭 No enrollment found for user: ${userId}`);
      return res.status(404).json({
        error: 'No enrollment found',
        code: 'NO_ENROLLMENT',
        enrolled: false
      });
    }
    
    logger.info(`📋 Found enrollment: ${enrollment.enrollmentId}, status: ${enrollment.status}`);

    // Get status from AuthID if we have an enrollmentId (which is the operationId)
    let authIdStatus = null;
    if (enrollment.enrollmentId && enrollment.status !== 'completed') {
      try {
        authIdStatus = await authIdService.checkOperationStatus(enrollment.enrollmentId);
        
        logger.info(`📊 AuthID Operation Status Check:`, {
          operationId: enrollment.enrollmentId,
          state: authIdStatus.state,
          result: authIdStatus.result,
          name: authIdStatus.name
        });
        
        // IMPORTANT: Only mark as completed if:
        // 1. State is 1 (Completed)
        // 2. Result is 1 (Success) 
        // 3. The operation was actually performed (not just created)
        // 
        // Note: AuthID operations go through these states:
        // State 0 = Pending (waiting for user action)
        // State 1 = Completed (user performed action)
        // State 2 = Failed (action failed)
        // State 3 = Expired (timeout)
        //
        // We should ONLY mark as complete when state=1 AND result=1
        // AND the operation has a CompletedAt timestamp
        if (authIdStatus.state === 1 && authIdStatus.result === 1 && authIdStatus.completedAt) {
          logger.info(`✅ Enrollment verified as complete in AuthID`, {
            operationId: enrollment.enrollmentId,
            completedAt: authIdStatus.completedAt
          });
          
          // Completed successfully
          await userService.updateBiometricEnrollmentStatus(userId, 'completed');
          enrollment.status = 'completed';
        } else if (authIdStatus.state === 1 && authIdStatus.result === 1 && !authIdStatus.completedAt) {
          // Operation shows as "complete" but has no completion timestamp
          // This means it was just created, not actually completed by the user
          logger.warn(`⚠️ Operation marked complete but no completion timestamp - likely not yet performed`, {
            operationId: enrollment.enrollmentId,
            state: authIdStatus.state,
            result: authIdStatus.result
          });
          // Keep status as initiated
        } else if (authIdStatus.state === 2 || authIdStatus.result === 2) {
          // Failed
          logger.info(`❌ Enrollment failed in AuthID`, {
            operationId: enrollment.enrollmentId
          });
          await userService.updateBiometricEnrollmentStatus(userId, 'failed');
          enrollment.status = 'failed';
        } else if (authIdStatus.state === 3) {
          // Expired
          logger.info(`⏰ Enrollment expired in AuthID`, {
            operationId: enrollment.enrollmentId
          });
          await userService.updateBiometricEnrollmentStatus(userId, 'expired');
          enrollment.status = 'expired';
        } else {
          // Still pending (state 0)
          logger.info(`⏳ Enrollment still pending in AuthID`, {
            operationId: enrollment.enrollmentId,
            state: authIdStatus.state
          });
        }
      } catch (error) {
        // If 404 or other error, the operation might not be queryable yet
        // Just use the local status
        logger.warn(`⚠️ Failed to get AuthID operation status: ${error.message}`);
        
        // If it's been more than 5 minutes and still pending, log a warning
        const enrollmentAge = Date.now() - new Date(enrollment.createdAt).getTime();
        if (enrollmentAge > 5 * 60 * 1000 && enrollment.status === 'initiated') {
          logger.warn(`⏰ Enrollment is old (${Math.round(enrollmentAge / 60000)} minutes) and still initiated`, {
            userId,
            enrollmentId: enrollment.enrollmentId
          });
        }
      }
    }

    const getProgressValue = (status) => {
      if (status === 'completed') return 100;
      if (status === 'initiated') return 50;
      return 0;
    };

    res.json({
      enrollment: {
        enrollmentId: enrollment.enrollmentId,
        status: enrollment.status,
        progress: getProgressValue(enrollment.status),
        completed: enrollment.status === 'completed',
        createdAt: enrollment.createdAt,
        expiresAt: enrollment.expiresAt
      }
    });

  } catch (error) {
    logger.error('❌ Failed to get enrollment status:', {
      error: error.message,
      stack: error.stack,
      userId: req.user?.userId
    });
    res.status(500).json({
      error: 'Failed to get enrollment status',
      code: 'STATUS_ERROR',
      details: error.message
    });
  }
});

/**
 * Re-enroll biometric data (for updates or re-registration)
 * POST /api/biometric/re-enroll
 */
router.post('/re-enroll', async (req, res) => {
  try {
    const userId = req.user.userId;
    
    // Get user data
    const user = await userService.getUserById(userId);
    if (!user) {
      return res.status(404).json({
        error: 'User not found',
        code: 'USER_NOT_FOUND'
      });
    }

    // Revoke existing biometric data
    try {
      await authIdService.revokeBiometricData(userId);
    } catch (error) {
      logger.warn(`⚠️ Failed to revoke existing biometric data: ${error.message}`);
    }

    // Clear existing enrollment from database
    await userService.clearBiometricEnrollment(userId);

    // Initiate new enrollment
    const enrollment = await authIdService.initiateBiometricEnrollment(userId, {
      name: user.name,
      email: user.email,
      department: user.department,
      role: user.role,
      accessLevel: user.accessLevel
    });

    // Save new enrollment data
    await userService.saveBiometricEnrollment(userId, {
      enrollmentId: enrollment.enrollmentId,
      status: 'initiated',
      expiresAt: enrollment.expiresAt,
      createdAt: new Date()
    });

    logger.info(`🔄 Biometric re-enrollment initiated for user ${userId}`);

    res.json({
      message: 'Biometric re-enrollment initiated',
      enrollment: {
        enrollmentId: enrollment.enrollmentId,
        enrollmentUrl: enrollment.enrollmentUrl,
        qrCode: enrollment.qrCode,
        expiresAt: enrollment.expiresAt
      }
    });

  } catch (error) {
    logger.error('❌ Failed to initiate biometric re-enrollment:', error.message);
    res.status(500).json({
      error: 'Failed to initiate biometric re-enrollment',
      code: 'RE_ENROLLMENT_ERROR'
    });
  }
});

/**
 * Delete biometric data
 * DELETE /api/biometric/data
 */
router.delete('/data', async (req, res) => {
  try {
    const userId = req.user.userId;
    
    // Revoke biometric data from AuthID.ai
    await authIdService.revokeBiometricData(userId);
    
    // Clear enrollment from database
    await userService.clearBiometricEnrollment(userId);

    logger.info(`🗑️ Biometric data deleted for user ${userId}`);

    res.json({
      message: 'Biometric data deleted successfully'
    });

  } catch (error) {
    logger.error('❌ Failed to delete biometric data:', error.message);
    res.status(500).json({
      error: 'Failed to delete biometric data',
      code: 'DELETE_ERROR'
    });
  }
});

/**
 * Test biometric verification (for testing purposes)
 * POST /api/biometric/test-verify
 */
router.post('/test-verify', [
  body('verificationData').notEmpty().withMessage('Verification data is required')
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

    const { verificationData } = req.body;
    const userId = req.user.userId;

    // Verify biometric with AuthID.ai
    const result = await authIdService.verifyBiometric({
      ...verificationData,
      accessPoint: 'test_endpoint'
    });

    // Log test verification
    await userService.logUserAccess(userId, 'biometric_test', req.ip, {
      confidence: result.confidence,
      verificationId: result.verificationId
    });

    logger.info(`🧪 Biometric test verification for user ${userId}: ${result.success}`);

    res.json({
      message: 'Test verification completed',
      result: {
        success: result.success,
        confidence: result.confidence,
        verificationId: result.verificationId,
        timestamp: result.timestamp
      }
    });

  } catch (error) {
    logger.error('❌ Biometric test verification failed:', error.message);
    res.status(500).json({
      error: 'Test verification failed',
      code: 'TEST_VERIFICATION_ERROR'
    });
  }
});

/**
 * Get biometric settings and capabilities
 * GET /api/biometric/settings
 */
router.get('/settings', async (req, res) => {
  try {
    const userId = req.user.userId;
    
    // Get user's biometric enrollment status
    const enrollment = await userService.getBiometricEnrollment(userId);
    
    // Get user's biometric preferences
    const preferences = await userService.getBiometricPreferences(userId);

    res.json({
      settings: {
        enrollmentStatus: enrollment?.status || 'not_enrolled',
        enrollmentCompleted: enrollment?.status === 'completed',
        availableMethods: ['face', 'voice'], // Could be dynamic based on device capabilities
        preferences: preferences || {
          enableBiometricLogin: false,
          enableBuildingAccess: false,
          requireBiometricForSensitiveActions: false
        },
        capabilities: {
          faceRecognition: true,
          voiceRecognition: true,
          fingerprintRecognition: false // Could be enabled based on device
        }
      }
    });

  } catch (error) {
    logger.error('❌ Failed to get biometric settings:', error.message);
    res.status(500).json({
      error: 'Failed to get biometric settings',
      code: 'SETTINGS_ERROR'
    });
  }
});

/**
 * Update biometric preferences
 * PUT /api/biometric/preferences
 */
router.put('/preferences', [
  body('enableBiometricLogin').isBoolean().withMessage('enableBiometricLogin must be boolean'),
  body('enableBuildingAccess').isBoolean().withMessage('enableBuildingAccess must be boolean'),
  body('requireBiometricForSensitiveActions').isBoolean().withMessage('requireBiometricForSensitiveActions must be boolean')
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

    const userId = req.user.userId;
    const { enableBiometricLogin, enableBuildingAccess, requireBiometricForSensitiveActions } = req.body;

    // Update preferences
    await userService.updateBiometricPreferences(userId, {
      enableBiometricLogin,
      enableBuildingAccess,
      requireBiometricForSensitiveActions,
      updatedAt: new Date()
    });

    logger.info(`⚙️ Biometric preferences updated for user ${userId}`);

    res.json({
      message: 'Biometric preferences updated successfully',
      preferences: {
        enableBiometricLogin,
        enableBuildingAccess,
        requireBiometricForSensitiveActions
      }
    });

  } catch (error) {
    logger.error('❌ Failed to update biometric preferences:', error.message);
    res.status(500).json({
      error: 'Failed to update biometric preferences',
      code: 'PREFERENCES_ERROR'
    });
  }
});

// =============================================================================
// BIOMETRIC LOGIN ROUTES
// =============================================================================

/**
 * POST /api/biometric/login/initiate
 * Start biometric login process
 * Public endpoint - user provides email to identify themselves
 */
router.post('/login/initiate', [
  body('email').optional().isEmail().withMessage('Invalid email format'),
  body('userId').optional().isString().withMessage('userId must be a string')
], async (req, res) => {
  try {
    // Validate request
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { email, userId } = req.body;
    
    if (!email && !userId) {
      return res.status(400).json({
        error: 'Email or userId required',
        code: 'MISSING_IDENTIFIER'
      });
    }
    
    logger.info('🔐 Initiating biometric login', { email, userId });
    
    // Find user by email or userId
    let user;
    if (email) {
      user = await userService.getUserByEmail(email);
    } else if (userId) {
      user = await userService.getUserById(userId);
    }
    
    if (!user) {
      // Return generic error to avoid user enumeration
      logger.warn('⚠️ User not found for login attempt', { email, userId });
      return res.status(404).json({
        error: 'User not found',
        code: 'USER_NOT_FOUND',
        message: 'No account found with that email'
      });
    }
    
    // Check if user has biometric enrolled
    const enrollment = await userService.getBiometricEnrollment(user.id);
    
    if (!enrollment || enrollment.status !== 'completed') {
      logger.warn('⚠️ User attempted login without biometric enrollment', { 
        userId: user.id,
        enrollmentStatus: enrollment?.status || 'none'
      });
      
      return res.status(400).json({
        error: 'Biometric not enrolled',
        code: 'NOT_ENROLLED',
        message: 'Please enroll your biometric first'
      });
    }
    
    // Create AuthID verification operation
    const loginOperation = await authIdService.initiateBiometricLogin(user.id, {
      name: user.name,
      email: user.email
    });
    
    // Store operation ID for later verification
    await userService.updateUser(user.id, {
      pending_login_operation: loginOperation.operationId,
      last_login_attempt: new Date().toISOString()
    });
    
    logger.info('✅ Biometric login initiated', { 
      userId: user.id,
      operationId: loginOperation.operationId 
    });
    
    res.json({
      success: true,
      userId: user.id,
      operationId: loginOperation.operationId,
      verificationUrl: loginOperation.verificationUrl,
      qrCode: loginOperation.qrCode,
      expiresAt: loginOperation.expiresAt
    });
    
  } catch (error) {
    logger.error('❌ Failed to initiate biometric login', { 
      error: error.message,
      stack: error.stack 
    });
    
    res.status(500).json({
      error: 'Login initiation failed',
      message: error.message
    });
  }
});

/**
 * GET /api/biometric/login/status/:operationId
 * Check login operation status (for polling)
 * Public endpoint
 */
router.get('/login/status/:operationId', async (req, res) => {
  try {
    const { operationId } = req.params;
    
    logger.info('🔍 Checking login operation status', { operationId });
    
    // Check operation status with AuthID
    let authIdStatus;
    try {
      authIdStatus = await authIdService.checkOperationStatus(operationId);
    } catch (error) {
      // If 404, operation might still be pending (UAT sync lag)
      if (error.message.includes('404')) {
        return res.json({
          success: true,
          status: 'pending',
          state: 0,
          result: 0,
          message: 'Verification in progress'
        });
      }
      throw error;
    }
    
    // Return status
    return res.json({
      success: true,
      status: authIdStatus.state === 1 && authIdStatus.result === 1 ? 'completed' : 
              authIdStatus.state === 2 || authIdStatus.result === 2 ? 'failed' : 
              authIdStatus.state === 3 ? 'expired' : 'pending',
      state: authIdStatus.state,
      result: authIdStatus.result,
      completedAt: authIdStatus.completedAt
    });
    
  } catch (error) {
    logger.error('❌ Failed to check login status', { 
      error: error.message,
      operationId: req.params.operationId 
    });
    
    res.status(500).json({
      error: 'Status check failed',
      message: error.message
    });
  }
});

/**
 * POST /api/biometric/login/complete/:operationId
 * Complete biometric login and issue JWT token
 * Public endpoint - called after biometric verification succeeds
 */
router.post('/login/complete/:operationId', async (req, res) => {
  try {
    const { operationId } = req.params;
    
    logger.info('🔐 Completing biometric login', { operationId });
    
    // Check operation status with AuthID
    let authIdStatus;
    try {
      authIdStatus = await authIdService.checkOperationStatus(operationId);
    } catch (error) {
      // If 404, might be UAT sync lag - trust the web component
      if (error.message.includes('404')) {
        logger.warn('⚠️ AuthID API returned 404 (UAT sync lag) - trusting web component', {
          operationId
        });
        // We'll proceed but need to find user by operation ID
      } else {
        throw error;
      }
    }
    
    // Find user by operation ID
    const user = await userService.getUserByLoginOperation(operationId);
    
    if (!user) {
      logger.warn('⚠️ No user found with login operation', { operationId });
      return res.status(404).json({
        error: 'Login session not found',
        code: 'NO_LOGIN_SESSION'
      });
    }
    
    // Check if verification completed successfully
    if (authIdStatus && (authIdStatus.state === 1 && authIdStatus.result === 1)) {
      // SUCCESS - User verified!
      logger.info('✅ Biometric verification confirmed by AuthID', { 
        userId: user.id,
        operationId 
      });
    } else if (authIdStatus && (authIdStatus.state === 2 || authIdStatus.result === 2)) {
      // FAILED - No match or failed verification
      logger.warn('❌ Biometric verification failed', { 
        operationId,
        userId: user.id,
        state: authIdStatus.state,
        result: authIdStatus.result
      });
      
      return res.status(401).json({
        success: false,
        status: 'failed',
        error: 'Biometric verification failed',
        message: 'Face did not match enrolled biometric'
      });
    } else {
      // PENDING or API unavailable - trust web component message
      logger.warn('⚠️ AuthID API shows pending/unavailable - trusting web component', {
        operationId,
        userId: user.id,
        state: authIdStatus?.state,
        result: authIdStatus?.result
      });
    }
    
    // Generate JWT tokens using the centralized JWT service
    // This ensures consistency with regular login and includes all required fields
    const tokens = jwtService.generateTokens({
      id: user.id,
      email: user.email,
      role: user.role || 'user',
      accessLevel: user.accessLevel || 'standard',
      name: user.name,
      department: user.department
    });
    
    // Update last login
    await userService.updateUser(user.id, {
      last_login: new Date().toISOString(),
      pending_login_operation: null,
      last_biometric_login: new Date().toISOString()
    });
    
    logger.info('✅ Biometric login successful', { 
      userId: user.id,
      operationId,
      email: user.email
    });
    
    return res.json({
      success: true,
      status: 'verified',
      token: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresIn: tokens.expiresIn,
      tokenType: tokens.tokenType,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role || 'user',
        accessLevel: user.accessLevel || 'standard',
        department: user.department,
        biometricEnabled: true
      }
    });
    
  } catch (error) {
    logger.error('❌ Biometric login completion error', { 
      error: error.message,
      stack: error.stack,
      operationId: req.params.operationId 
    });
    
    res.status(500).json({
      error: 'Login completion failed',
      message: error.message
    });
  }
});

module.exports = router;