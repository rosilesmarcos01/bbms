const express = require('express');
const crypto = require('crypto');

const authIdService = require('../services/authIdService');
const userService = require('../services/userService');
const logger = require('../utils/logger');

const router = express.Router();

/**
 * AuthID.ai webhook endpoint
 * POST /webhooks/authid
 */
router.post('/', async (req, res) => {
  try {
    const signature = req.headers['x-authid-signature'];
    const payload = JSON.stringify(req.body);

    // Validate webhook signature
    if (!authIdService.validateWebhookSignature(payload, signature)) {
      logger.warn('⚠️ Invalid webhook signature from AuthID.ai');
      return res.status(401).json({
        error: 'Invalid signature',
        code: 'INVALID_SIGNATURE'
      });
    }

    const { event_type, data } = req.body;

    logger.info(`📨 Received AuthID.ai webhook: ${event_type}`);

    // Process the webhook event
    await authIdService.processWebhookEvent(event_type, data);

    // Handle specific events for our BBMS system
    switch (event_type) {
      case 'enrollment.completed':
        await handleEnrollmentCompleted(data);
        break;
      case 'enrollment.failed':
        await handleEnrollmentFailed(data);
        break;
      case 'verification.completed':
        await handleVerificationCompleted(data);
        break;
      case 'verification.failed':
        await handleVerificationFailed(data);
        break;
      case 'user.updated':
        await handleUserUpdated(data);
        break;
      case 'security.alert':
        await handleSecurityAlert(data);
        break;
      default:
        logger.info(`ℹ️ Unhandled webhook event: ${event_type}`);
    }

    // Acknowledge the webhook
    res.status(200).json({
      message: 'Webhook processed successfully',
      event_type,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    logger.error('❌ Webhook processing failed:', error.message);
    res.status(500).json({
      error: 'Webhook processing failed',
      code: 'WEBHOOK_ERROR'
    });
  }
});

/**
 * Handle enrollment completion
 */
async function handleEnrollmentCompleted(data) {
  try {
    const { user_id, enrollment_id, confidence_score, biometric_methods } = data;

    // Update enrollment status in our database
    await userService.updateBiometricEnrollmentStatus(user_id, 'completed');

    // Enable biometric login by default
    await userService.updateBiometricPreferences(user_id, {
      enableBiometricLogin: true,
      enableBuildingAccess: true,
      requireBiometricForSensitiveActions: false
    });

    // Log the successful enrollment
    await userService.logUserAccess(user_id, 'biometric_enrollment_completed', '127.0.0.1', {
      enrollmentId: enrollment_id,
      confidenceScore: confidence_score,
      biometricMethods: biometric_methods
    });

    logger.info(`✅ Biometric enrollment completed for user ${user_id} with confidence ${confidence_score}`);

    // Here you could also send a notification to the user
    // await notificationService.sendEnrollmentSuccessNotification(user_id);

  } catch (error) {
    logger.error(`❌ Failed to handle enrollment completion for user ${data.user_id}:`, error.message);
  }
}

/**
 * Handle enrollment failure
 */
async function handleEnrollmentFailed(data) {
  try {
    const { user_id, enrollment_id, failure_reason, retry_count } = data;

    // Update enrollment status in our database
    await userService.updateBiometricEnrollmentStatus(user_id, 'failed');

    // Log the failed enrollment
    await userService.logUserAccess(user_id, 'biometric_enrollment_failed', '127.0.0.1', {
      enrollmentId: enrollment_id,
      failureReason: failure_reason,
      retryCount: retry_count
    });

    logger.warn(`❌ Biometric enrollment failed for user ${user_id}: ${failure_reason} (retry ${retry_count})`);

    // Here you could send a notification to the user about the failure
    // await notificationService.sendEnrollmentFailureNotification(user_id, failure_reason);

  } catch (error) {
    logger.error(`❌ Failed to handle enrollment failure for user ${data.user_id}:`, error.message);
  }
}

/**
 * Handle verification completion (successful login)
 */
async function handleVerificationCompleted(data) {
  try {
    const { 
      user_id, 
      verification_id, 
      confidence_score, 
      verification_method,
      access_point,
      location,
      device_info 
    } = data;

    // Log the successful verification
    await userService.logUserAccess(user_id, 'biometric_verification_success', location?.ip || '127.0.0.1', {
      verificationId: verification_id,
      confidenceScore: confidence_score,
      verificationMethod: verification_method,
      accessPoint: access_point,
      deviceInfo: device_info,
      location: location
    });

    logger.info(`🔍 Biometric verification successful for user ${user_id} (confidence: ${confidence_score})`);

    // Check for unusual access patterns
    if (confidence_score < 0.8) {
      logger.warn(`⚠️ Low confidence biometric verification for user ${user_id}: ${confidence_score}`);
      // Could trigger additional security checks here
    }

    // Track access for security monitoring
    // await securityService.trackAccess(user_id, verification_data);

  } catch (error) {
    logger.error(`❌ Failed to handle verification completion for user ${data.user_id}:`, error.message);
  }
}

/**
 * Handle verification failure
 */
async function handleVerificationFailed(data) {
  try {
    const { 
      user_id, 
      verification_id, 
      failure_reason,
      confidence_score,
      access_point,
      location,
      attempt_count 
    } = data;

    // Log the failed verification
    await userService.logUserAccess(user_id || 'unknown', 'biometric_verification_failed', location?.ip || '127.0.0.1', {
      verificationId: verification_id,
      failureReason: failure_reason,
      confidenceScore: confidence_score,
      accessPoint: access_point,
      attemptCount: attempt_count,
      location: location
    });

    logger.warn(`❌ Biometric verification failed for user ${user_id || 'unknown'}: ${failure_reason} (attempt ${attempt_count})`);

    // Security monitoring for failed attempts
    if (attempt_count >= 3) {
      logger.error(`🚨 Multiple failed biometric attempts detected for user ${user_id || 'unknown'}`);
      // Could trigger security alerts or account lockdown here
    }

  } catch (error) {
    logger.error(`❌ Failed to handle verification failure:`, error.message);
  }
}

/**
 * Handle user data updates from AuthID.ai
 */
async function handleUserUpdated(data) {
  try {
    const { user_id, updated_fields, timestamp } = data;

    logger.info(`👤 User data updated in AuthID.ai for user ${user_id}:`, updated_fields);

    // Sync relevant updates with our local user data
    if (updated_fields.access_level) {
      const user = await userService.getUserById(user_id);
      if (user) {
        await userService.updateUser(user_id, {
          accessLevel: updated_fields.access_level
        });
      }
    }

    // Log the user update
    await userService.logUserAccess(user_id, 'user_data_updated', '127.0.0.1', {
      updatedFields: updated_fields,
      source: 'authid_webhook',
      timestamp: timestamp
    });

  } catch (error) {
    logger.error(`❌ Failed to handle user update for user ${data.user_id}:`, error.message);
  }
}

/**
 * Handle security alerts from AuthID.ai
 */
async function handleSecurityAlert(data) {
  try {
    const { 
      alert_type, 
      user_id, 
      severity, 
      description, 
      location,
      recommended_actions 
    } = data;

    logger.error(`🚨 Security alert from AuthID.ai: ${alert_type} - ${description}`);

    // Log the security alert
    await userService.logUserAccess(user_id || 'system', 'security_alert', location?.ip || '127.0.0.1', {
      alertType: alert_type,
      severity: severity,
      description: description,
      recommendedActions: recommended_actions,
      location: location
    });

    // Handle different types of security alerts
    switch (alert_type) {
      case 'suspicious_access':
        logger.warn(`⚠️ Suspicious access detected for user ${user_id}`);
        // Could implement account temporary lockdown
        break;
      
      case 'biometric_spoofing':
        logger.error(`🚨 Biometric spoofing attempt detected for user ${user_id}`);
        // Could implement immediate account suspension
        break;
      
      case 'unusual_location':
        logger.warn(`📍 Unusual location access for user ${user_id}`);
        // Could trigger additional verification requirements
        break;
      
      case 'device_compromise':
        logger.error(`📱 Device compromise detected for user ${user_id}`);
        // Could revoke all sessions for the user
        break;
      
      default:
        logger.warn(`⚠️ Unknown security alert type: ${alert_type}`);
    }

    // Send notifications to security team
    // await notificationService.sendSecurityAlert(alert_data);

  } catch (error) {
    logger.error(`❌ Failed to handle security alert:`, error.message);
  }
}

/**
 * Health check for webhook endpoint
 * GET /webhooks/authid/health
 */
router.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    service: 'BBMS AuthID.ai Webhook Handler',
    timestamp: new Date().toISOString(),
    webhook_url: `${req.protocol}://${req.get('host')}/webhooks/authid`
  });
});

module.exports = router;