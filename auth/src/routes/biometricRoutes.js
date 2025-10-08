const express = require('express');
const { body, validationResult } = require('express-validator');

const authIdService = require('../services/authIdService');
const userService = require('../services/userService');
const authMiddleware = require('../middleware/authMiddleware');
const logger = require('../utils/logger');

const router = express.Router();

// All biometric routes require authentication
router.use(authMiddleware.verifyToken);

/**
 * Initiate biometric enrollment for current user
 * POST /api/biometric/enroll
 */
router.post('/enroll', async (req, res) => {
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

    // Check if user already has biometric enrollment
    const existingEnrollment = await userService.getBiometricEnrollment(userId);
    if (existingEnrollment && existingEnrollment.status === 'completed') {
      return res.status(409).json({
        error: 'User already has biometric enrollment',
        code: 'ENROLLMENT_EXISTS'
      });
    }

    // Initiate biometric enrollment with AuthID.ai
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
    logger.error('❌ Failed to initiate biometric enrollment:', error.message);
    res.status(500).json({
      error: 'Failed to initiate biometric enrollment',
      code: 'ENROLLMENT_ERROR'
    });
  }
});

/**
 * Get biometric enrollment status
 * GET /api/biometric/enrollment/status
 */
router.get('/enrollment/status', async (req, res) => {
  try {
    const userId = req.user.userId;
    
    // Get enrollment from database
    const enrollment = await userService.getBiometricEnrollment(userId);
    if (!enrollment) {
      return res.status(404).json({
        error: 'No enrollment found',
        code: 'NO_ENROLLMENT'
      });
    }

    // Get status from AuthID.ai
    let authIdStatus = null;
    try {
      authIdStatus = await authIdService.getEnrollmentStatus(enrollment.enrollmentId);
    } catch (error) {
      logger.warn(`⚠️ Failed to get AuthID.ai enrollment status: ${error.message}`);
    }

    // Update local status if different
    if (authIdStatus && authIdStatus.status !== enrollment.status) {
      await userService.updateBiometricEnrollmentStatus(userId, authIdStatus.status);
    }

    res.json({
      enrollment: {
        enrollmentId: enrollment.enrollmentId,
        status: authIdStatus?.status || enrollment.status,
        progress: authIdStatus?.progress || 0,
        completed: authIdStatus?.completed || false,
        createdAt: enrollment.createdAt,
        expiresAt: enrollment.expiresAt
      }
    });

  } catch (error) {
    logger.error('❌ Failed to get enrollment status:', error.message);
    res.status(500).json({
      error: 'Failed to get enrollment status',
      code: 'STATUS_ERROR'
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

module.exports = router;