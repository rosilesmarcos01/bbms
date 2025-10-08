const axios = require('axios');
const logger = require('../utils/logger');

class AuthIDService {
  constructor() {
    this.apiUrl = process.env.AUTHID_API_URL || 'https://api.authid.ai';
    this.clientId = process.env.AUTHID_CLIENT_ID;
    this.clientSecret = process.env.AUTHID_CLIENT_SECRET;
    this.webhookSecret = process.env.AUTHID_WEBHOOK_SECRET;
    
    if (!this.clientId || !this.clientSecret) {
      logger.warn('⚠️ AuthID.ai credentials not configured');
    }
  }

  /**
   * Initialize biometric enrollment for a user
   */
  async initiateBiometricEnrollment(userId, userData) {
    try {
      const response = await axios.post(`${this.apiUrl}/v1/enrollments`, {
        user_id: userId,
        user_data: {
          name: userData.name,
          email: userData.email,
          department: userData.department,
          role: userData.role,
          building_access_level: userData.accessLevel
        },
        enrollment_type: 'biometric',
        verification_methods: ['face', 'voice'], // Can include 'fingerprint' if available
        metadata: {
          building_id: process.env.BUILDING_ID,
          facility_name: process.env.FACILITY_NAME,
          enrollment_timestamp: new Date().toISOString()
        }
      }, {
        headers: {
          'Authorization': `Bearer ${await this.getAccessToken()}`,
          'Content-Type': 'application/json'
        }
      });

      logger.info(`✅ Biometric enrollment initiated for user ${userId}`);
      return {
        success: true,
        enrollmentId: response.data.enrollment_id,
        enrollmentUrl: response.data.enrollment_url,
        qrCode: response.data.qr_code,
        expiresAt: response.data.expires_at
      };
    } catch (error) {
      logger.error(`❌ Failed to initiate biometric enrollment for user ${userId}:`, error.response?.data || error.message);
      throw new Error('Failed to initiate biometric enrollment');
    }
  }

  /**
   * Verify biometric authentication
   */
  async verifyBiometric(verificationData) {
    try {
      const response = await axios.post(`${this.apiUrl}/v1/verifications`, {
        verification_type: 'biometric',
        verification_data: verificationData,
        building_context: {
          building_id: process.env.BUILDING_ID,
          facility_name: process.env.FACILITY_NAME,
          access_point: verificationData.accessPoint || 'mobile_app',
          timestamp: new Date().toISOString()
        }
      }, {
        headers: {
          'Authorization': `Bearer ${await this.getAccessToken()}`,
          'Content-Type': 'application/json'
        }
      });

      const verification = response.data;
      
      logger.info(`🔍 Biometric verification ${verification.verified ? 'successful' : 'failed'} for user ${verification.user_id}`);
      
      return {
        success: verification.verified,
        userId: verification.user_id,
        confidence: verification.confidence_score,
        verificationId: verification.verification_id,
        userData: verification.user_data,
        accessLevel: verification.user_data?.building_access_level,
        timestamp: verification.timestamp
      };
    } catch (error) {
      logger.error('❌ Biometric verification failed:', error.response?.data || error.message);
      throw new Error('Biometric verification failed');
    }
  }

  /**
   * Check enrollment status
   */
  async getEnrollmentStatus(enrollmentId) {
    try {
      const response = await axios.get(`${this.apiUrl}/v1/enrollments/${enrollmentId}`, {
        headers: {
          'Authorization': `Bearer ${await this.getAccessToken()}`
        }
      });

      return {
        status: response.data.status,
        progress: response.data.progress,
        completed: response.data.status === 'completed',
        enrollmentData: response.data
      };
    } catch (error) {
      logger.error(`❌ Failed to get enrollment status for ${enrollmentId}:`, error.response?.data || error.message);
      throw new Error('Failed to get enrollment status');
    }
  }

  /**
   * Revoke user's biometric data
   */
  async revokeBiometricData(userId) {
    try {
      await axios.delete(`${this.apiUrl}/v1/users/${userId}/biometric-data`, {
        headers: {
          'Authorization': `Bearer ${await this.getAccessToken()}`
        }
      });

      logger.info(`🗑️ Biometric data revoked for user ${userId}`);
      return { success: true };
    } catch (error) {
      logger.error(`❌ Failed to revoke biometric data for user ${userId}:`, error.response?.data || error.message);
      throw new Error('Failed to revoke biometric data');
    }
  }

  /**
   * Update user access level
   */
  async updateUserAccessLevel(userId, accessLevel) {
    try {
      await axios.patch(`${this.apiUrl}/v1/users/${userId}`, {
        building_access_level: accessLevel,
        updated_timestamp: new Date().toISOString()
      }, {
        headers: {
          'Authorization': `Bearer ${await this.getAccessToken()}`,
          'Content-Type': 'application/json'
        }
      });

      logger.info(`🔑 Updated access level for user ${userId} to ${accessLevel}`);
      return { success: true };
    } catch (error) {
      logger.error(`❌ Failed to update access level for user ${userId}:`, error.response?.data || error.message);
      throw new Error('Failed to update user access level');
    }
  }

  /**
   * Get access token for AuthID.ai API
   */
  async getAccessToken() {
    try {
      if (!this.clientId || !this.clientSecret) {
        throw new Error('AuthID.ai credentials not configured');
      }

      const response = await axios.post(`${this.apiUrl}/oauth/token`, {
        grant_type: 'client_credentials',
        client_id: this.clientId,
        client_secret: this.clientSecret,
        scope: 'biometric:read biometric:write users:read users:write'
      }, {
        headers: {
          'Content-Type': 'application/json'
        }
      });

      return response.data.access_token;
    } catch (error) {
      logger.error('❌ Failed to get AuthID.ai access token:', error.response?.data || error.message);
      throw new Error('Failed to authenticate with AuthID.ai');
    }
  }

  /**
   * Validate webhook signature
   */
  validateWebhookSignature(payload, signature) {
    const crypto = require('crypto');
    const expectedSignature = crypto
      .createHmac('sha256', this.webhookSecret)
      .update(payload)
      .digest('hex');
    
    return `sha256=${expectedSignature}` === signature;
  }

  /**
   * Process webhook event from AuthID.ai
   */
  async processWebhookEvent(eventType, eventData) {
    try {
      logger.info(`📨 Processing AuthID.ai webhook event: ${eventType}`);
      
      switch (eventType) {
        case 'enrollment.completed':
          await this.handleEnrollmentCompleted(eventData);
          break;
        case 'enrollment.failed':
          await this.handleEnrollmentFailed(eventData);
          break;
        case 'verification.completed':
          await this.handleVerificationCompleted(eventData);
          break;
        case 'user.updated':
          await this.handleUserUpdated(eventData);
          break;
        default:
          logger.warn(`⚠️ Unhandled webhook event type: ${eventType}`);
      }
    } catch (error) {
      logger.error(`❌ Failed to process webhook event ${eventType}:`, error.message);
      throw error;
    }
  }

  async handleEnrollmentCompleted(eventData) {
    // Implementation for handling completed enrollments
    logger.info(`✅ Enrollment completed for user ${eventData.user_id}`);
    // You can add database updates or notifications here
  }

  async handleEnrollmentFailed(eventData) {
    // Implementation for handling failed enrollments
    logger.warn(`❌ Enrollment failed for user ${eventData.user_id}: ${eventData.reason}`);
    // You can add error handling or user notifications here
  }

  async handleVerificationCompleted(eventData) {
    // Implementation for handling verification events
    logger.info(`🔍 Verification completed for user ${eventData.user_id}, result: ${eventData.verified}`);
    // You can add access logging or real-time notifications here
  }

  async handleUserUpdated(eventData) {
    // Implementation for handling user updates
    logger.info(`👤 User updated: ${eventData.user_id}`);
    // You can sync user data with your local database here
  }
}

module.exports = new AuthIDService();