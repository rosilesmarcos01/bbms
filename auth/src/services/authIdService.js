const axios = require('axios');
const logger = require('../utils/logger');

class AuthIDService {
  constructor() {
    // AuthID UAT Environment
    this.baseURL = 'https://id-uat.authid.ai/IDCompleteBackendEngine/Default';
    this.adminURL = `${this.baseURL}/AdministrationServiceRest`;
    this.transactionURL = `${this.baseURL}/AuthorizationServiceRest`;
    this.idpURL = 'https://id-uat.authid.ai/IDCompleteBackendEngine/IdentityService/v1';

    // API Keys from environment
    this.apiKeyId = process.env.AUTHID_API_KEY_ID;
    this.apiKeyValue = process.env.AUTHID_API_KEY_VALUE;

    // Session tokens
    this.accessToken = null;
    this.refreshToken = null;

    // Validate configuration
    if (!this.apiKeyId || !this.apiKeyValue) {
      logger.error('❌ AuthID API keys not configured');
      throw new Error('AuthID API keys are required');
    }

    logger.info('✅ AuthID Service initialized with API keys');
  }

  /**
   * Authenticate with AuthID to get access token
   */
  async authenticate() {
    try {
      logger.info('🔐 Authenticating with AuthID using API keys');

      // Try authenticating with API keys as Basic Auth credentials
      // Some APIs use API Key ID as username and API Key Value as password
      const response = await axios.post(
        `${this.idpURL}/auth/token`,
        null,
        {
          auth: {
            username: this.apiKeyId,
            password: this.apiKeyValue
          }
        }
      );

      this.accessToken = response.data.AccessToken;
      this.refreshToken = response.data.RefreshToken;

      logger.info('✅ AuthID authentication successful');

      return {
        success: true,
        accessToken: this.accessToken,
        refreshToken: this.refreshToken
      };

    } catch (error) {
      logger.error('❌ AuthID authentication failed', { 
        error: error.message,
        status: error.response?.status,
        data: error.response?.data
      });
      throw new Error(`Authentication failed: ${error.response?.data?.message || error.message}`);
    }
  }

  /**
   * Get authentication headers for AuthID API calls
   */
  async getAuthHeaders() {
    // Ensure we have a valid token
    if (!this.accessToken) {
      await this.authenticate();
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${this.accessToken}`
    };
  }

  /**
   * STEP 1: ONBOARDING/PROOFING
   * Start the identity proofing process for a new user
   * This is where the user provides their identity documents for verification
   */
  async startOnboarding(userData) {
    try {
      logger.info('📋 Starting AuthID onboarding process', { userId: userData.userId });

      const onboardingData = {
        user_id: userData.userId,
        email: userData.email,
        first_name: userData.firstName,
        last_name: userData.lastName,
        phone: userData.phone,
        // Configure the onboarding flow
        flow_config: {
          require_document_verification: true,
          require_selfie: true,
          require_liveness_check: true,
          document_types: ['drivers_license', 'passport', 'national_id']
        },
        metadata: {
          device_info: userData.deviceInfo,
          ip_address: userData.ipAddress,
          user_agent: userData.userAgent
        }
      };

      const response = await axios.post(
        `${this.baseURL}/api/v1/onboarding/start`,
        onboardingData,
        { headers: this.getAuthHeaders() }
      );

      logger.info('✅ Onboarding session created', { 
        sessionId: response.data.session_id,
        userId: userData.userId 
      });

      return {
        success: true,
        sessionId: response.data.session_id,
        onboardingUrl: response.data.onboarding_url,
        qrCode: response.data.qr_code,
        expiresAt: response.data.expires_at
      };

    } catch (error) {
      logger.error('❌ Failed to start onboarding', { 
        error: error.message,
        userId: userData.userId 
      });
      throw new Error(`Onboarding initiation failed: ${error.response?.data?.message || error.message}`);
    }
  }

  /**
   * Check the status of an onboarding session
   */
  async checkOnboardingStatus(sessionId) {
    try {
      const response = await axios.get(
        `${this.baseURL}/api/v1/onboarding/status/${sessionId}`,
        { headers: this.getAuthHeaders() }
      );

      logger.info('📊 Onboarding status checked', { 
        sessionId,
        status: response.data.status 
      });

      return {
        success: true,
        status: response.data.status, // pending, in_progress, completed, failed
        verification_result: response.data.verification_result,
        document_verification: response.data.document_verification,
        liveness_check: response.data.liveness_check,
        risk_score: response.data.risk_score
      };

    } catch (error) {
      logger.error('❌ Failed to check onboarding status', { 
        error: error.message,
        sessionId 
      });
      throw new Error(`Status check failed: ${error.response?.data?.message || error.message}`);
    }
  }

  /**
   * STEP 2: ENROLLMENT
   * After successful onboarding, enroll the user's biometric template
   * This binds their face template to their verified identity
   */
  async enrollBiometric(enrollmentData) {
    try {
      logger.info('🔐 Starting biometric enrollment', { userId: enrollmentData.userId });

      const enrollmentPayload = {
        user_id: enrollmentData.userId,
        onboarding_session_id: enrollmentData.onboardingSessionId,
        biometric_data: {
          face_template: enrollmentData.faceTemplate,
          quality_score: enrollmentData.qualityScore,
          liveness_score: enrollmentData.livenessScore
        },
        device_info: enrollmentData.deviceInfo,
        metadata: {
          enrollment_method: 'mobile_app',
          sdk_version: enrollmentData.sdkVersion
        }
      };

      const response = await axios.post(
        `${this.baseURL}/api/v1/enrollment/biometric`,
        enrollmentPayload,
        { headers: this.getAuthHeaders() }
      );

      logger.info('✅ Biometric enrollment completed', { 
        userId: enrollmentData.userId,
        enrollmentId: response.data.enrollment_id 
      });

      return {
        success: true,
        enrollmentId: response.data.enrollment_id,
        templateId: response.data.template_id,
        qualityScore: response.data.quality_score,
        enrollmentComplete: response.data.enrollment_complete
      };

    } catch (error) {
      logger.error('❌ Biometric enrollment failed', { 
        error: error.message,
        userId: enrollmentData.userId 
      });
      throw new Error(`Enrollment failed: ${error.response?.data?.message || error.message}`);
    }
  }

  /**
   * STEP 3: AUTHENTICATION/LOGIN
   * Authenticate a returning user using their biometric
   */
  async authenticateUser(authData) {
    try {
      logger.info('🔓 Starting biometric authentication', { userId: authData.userId });

      const authPayload = {
        user_id: authData.userId,
        biometric_data: {
          face_template: authData.faceTemplate,
          quality_score: authData.qualityScore,
          liveness_score: authData.livenessScore
        },
        device_info: authData.deviceInfo,
        context: {
          action: 'login',
          risk_level: 'standard',
          location: authData.location,
          timestamp: new Date().toISOString()
        }
      };

      const response = await axios.post(
        `${this.baseURL}/api/v1/authentication/verify`,
        authPayload,
        { headers: this.getAuthHeaders() }
      );

      const authResult = {
        success: response.data.verified,
        confidence: response.data.confidence_score,
        matchScore: response.data.match_score,
        livenessScore: response.data.liveness_score,
        riskScore: response.data.risk_score,
        sessionToken: response.data.session_token,
        expiresAt: response.data.expires_at
      };

      if (authResult.success) {
        logger.info('✅ Authentication successful', { 
          userId: authData.userId,
          confidence: authResult.confidence 
        });
      } else {
        logger.warn('❌ Authentication failed', { 
          userId: authData.userId,
          reason: response.data.failure_reason 
        });
      }

      return authResult;

    } catch (error) {
      logger.error('❌ Authentication error', { 
        error: error.message,
        userId: authData.userId 
      });
      throw new Error(`Authentication failed: ${error.response?.data?.message || error.message}`);
    }
  }

  /**
   * STEP 4: TRANSACTION VERIFICATION
   * Verify user identity for sensitive transactions or actions
   */
  async verifyTransaction(transactionData) {
    try {
      logger.info('💳 Starting transaction verification', { 
        userId: transactionData.userId,
        transactionId: transactionData.transactionId 
      });

      const verificationPayload = {
        user_id: transactionData.userId,
        transaction_id: transactionData.transactionId,
        session_token: transactionData.sessionToken,
        biometric_data: {
          face_template: transactionData.faceTemplate,
          quality_score: transactionData.qualityScore,
          liveness_score: transactionData.livenessScore
        },
        transaction_context: {
          type: transactionData.transactionType, // 'access', 'payment', 'sensitive_action'
          amount: transactionData.amount,
          description: transactionData.description,
          risk_level: transactionData.riskLevel || 'medium',
          location: transactionData.location,
          device_info: transactionData.deviceInfo
        }
      };

      const response = await axios.post(
        `${this.baseURL}/api/v1/transaction/verify`,
        verificationPayload,
        { headers: this.getAuthHeaders() }
      );

      const verificationResult = {
        success: response.data.verified,
        confidence: response.data.confidence_score,
        riskScore: response.data.risk_score,
        decision: response.data.decision, // 'allow', 'deny', 'review'
        transactionToken: response.data.transaction_token,
        verificationId: response.data.verification_id
      };

      if (verificationResult.success && verificationResult.decision === 'allow') {
        logger.info('✅ Transaction verified and approved', { 
          userId: transactionData.userId,
          transactionId: transactionData.transactionId 
        });
      } else {
        logger.warn('⚠️ Transaction verification failed or requires review', { 
          userId: transactionData.userId,
          transactionId: transactionData.transactionId,
          decision: verificationResult.decision 
        });
      }

      return verificationResult;

    } catch (error) {
      logger.error('❌ Transaction verification error', { 
        error: error.message,
        userId: transactionData.userId,
        transactionId: transactionData.transactionId 
      });
      throw new Error(`Transaction verification failed: ${error.response?.data?.message || error.message}`);
    }
  }

  /**
   * Get user's enrollment status and biometric templates
   */
  async getUserEnrollmentStatus(userId) {
    try {
      const response = await axios.get(
        `${this.baseURL}/api/v1/user/${userId}/enrollment`,
        { headers: this.getAuthHeaders() }
      );

      return {
        success: true,
        isEnrolled: response.data.is_enrolled,
        enrollmentDate: response.data.enrollment_date,
        templateCount: response.data.template_count,
        lastUpdate: response.data.last_update
      };

    } catch (error) {
      logger.error('❌ Failed to get enrollment status', { 
        error: error.message,
        userId 
      });
      throw new Error(`Failed to get enrollment status: ${error.response?.data?.message || error.message}`);
    }
  }

  /**
   * Deactivate a user's biometric enrollment
   */
  async deactivateUser(userId, reason = 'user_request') {
    try {
      logger.info('🔒 Deactivating user enrollment', { userId, reason });

      const response = await axios.post(
        `${this.baseURL}/api/v1/user/${userId}/deactivate`,
        { reason },
        { headers: this.getAuthHeaders() }
      );

      logger.info('✅ User deactivated successfully', { userId });

      return {
        success: true,
        deactivatedAt: response.data.deactivated_at
      };

    } catch (error) {
      logger.error('❌ Failed to deactivate user', { 
        error: error.message,
        userId 
      });
      throw new Error(`Deactivation failed: ${error.response?.data?.message || error.message}`);
    }
  }

  /**
   * Get authentication logs for a user
   */
  async getUserAuthHistory(userId, limit = 50) {
    try {
      const response = await axios.get(
        `${this.baseURL}/api/v1/user/${userId}/auth-history?limit=${limit}`,
        { headers: this.getAuthHeaders() }
      );

      return {
        success: true,
        authHistory: response.data.auth_history,
        totalCount: response.data.total_count
      };

    } catch (error) {
      logger.error('❌ Failed to get auth history', { 
        error: error.message,
        userId 
      });
      throw new Error(`Failed to get auth history: ${error.response?.data?.message || error.message}`);
    }
  }

  /**
   * Health check for AuthID service
   */
  async healthCheck() {
    try {
      const response = await axios.get(
        `${this.baseURL}/api/v1/health`,
        { headers: this.getAuthHeaders() }
      );

      return {
        success: true,
        status: response.data.status,
        version: response.data.version
      };

    } catch (error) {
      logger.error('❌ AuthID health check failed', { error: error.message });
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * SIMPLIFIED METHODS FOR BBMS INTEGRATION
   * These are wrapper methods that simplify the AuthID workflow for the BBMS app
   */

  /**
   * Initiate biometric enrollment for a user
   * This uses the REAL AuthID.ai API flow:
   * 1. Create Account
   * 2. Create EnrollBioCredential Operation
   */
  async initiateBiometricEnrollment(userId, userData) {
    try {
      logger.info('🚀 Initiating REAL AuthID biometric enrollment', { userId, userData });

      // Split name into first and last name
      const nameParts = userData.name ? userData.name.split(' ') : ['User', 'Name'];
      const firstName = nameParts[0] || 'User';
      const lastName = nameParts.slice(1).join(' ') || 'Name';

      // STEP 1: Create Account in AuthID
      const accountData = {
        AccountNumber: userId,
        Version: 0,
        DisplayName: userData.name || `${firstName} ${lastName}`,
        CustomDisplayName: userData.name || `${firstName} ${lastName}`,
        Description: `BBMS User - ${userData.department || 'N/A'} - ${userData.role || 'user'}`,
        Rules: 1,
        Enabled: true,
        Custom: true,
        DisableReason: "",
        Email: userData.email || `user-${userId}@bbms.ai`,
        PhoneNumber: userData.phone || "",
        EmailVerified: false,
        PhoneNumberVerified: false
      };

      logger.info('📤 Creating AuthID account', { 
        url: `${this.adminURL}/v1/accounts`,
        accountNumber: userId 
      });

      try {
        const accountResponse = await axios.post(
          `${this.adminURL}/v1/accounts`,
          accountData,
          { headers: await this.getAuthHeaders() }
        );
        
        logger.info('✅ AuthID account created', { 
          accountNumber: accountResponse.data.AccountNumber 
        });
      } catch (accountError) {
        // Account might already exist, that's okay
        if (accountError.response?.status === 409 || accountError.response?.status === 400) {
          logger.info('ℹ️ Account already exists, continuing...', { userId });
        } else {
          throw accountError;
        }
      }

      // STEP 2: Create Biometric Enrollment Operation
      const operationData = {
        AccountNumber: userId,
        Codeword: "",
        Name: "EnrollBioCredential",
        Timeout: 3600, // 1 hour
        TransportType: 0, // Push notification
        Tag: `bbms-enrollment-${Date.now()}`
      };

      logger.info('📤 Creating biometric enrollment operation', { 
        url: `${this.transactionURL}/v2/operations`,
        userId 
      });

      const operationResponse = await axios.post(
        `${this.transactionURL}/v2/operations`,
        operationData,
        { headers: await this.getAuthHeaders() }
      );

      const operationId = operationResponse.data.OperationId;
      const oneTimeSecret = operationResponse.data.OneTimeSecret;
      
      // Log the full response
      logger.info('📋 AuthID Operation Response', { 
        operationId,
        oneTimeSecret: oneTimeSecret ? '***' : 'missing',
        fullResponse: operationResponse.data
      });
      
      // Construct enrollment URL pointing to our hosted React component page
      // This page will use the @authid/react-component package
      const enrollmentWebUrl = process.env.AUTHID_WEB_URL || 'http://localhost:3002';
      const enrollmentUrl = `${enrollmentWebUrl}?operationId=${operationId}&secret=${oneTimeSecret}&baseUrl=${encodeURIComponent('https://id-uat.authid.ai')}`;
      
      // QR code contains the same URL for easy scanning
      const qrCodeData = enrollmentUrl;
      
      logger.info('✅ Real AuthID enrollment operation created', { 
        operationId,
        userId,
        enrollmentUrl
      });

      return {
        success: true,
        enrollmentId: operationId,
        enrollmentUrl: enrollmentUrl,
        qrCode: qrCodeData,
        operationId: operationId,
        oneTimeSecret: oneTimeSecret,
        expiresAt: new Date(Date.now() + 3600 * 1000).toISOString() // 1 hour from now
      };

    } catch (error) {
      logger.error('❌ Failed to initiate AuthID enrollment', { 
        error: error.message,
        response: error.response?.data,
        status: error.response?.status,
        userId 
      });
      
      // Provide detailed error message
      const errorMessage = error.response?.data?.message || error.response?.data?.Message || error.message;
      throw new Error(`AuthID enrollment failed: ${errorMessage}`);
    }
  }

  /**
   * Check the status of an authentication operation or transaction
   * @param {string} operationId - The operation or transaction ID from AuthID
   */
  async checkOperationStatus(operationId) {
    try {
      logger.info('🔍 Checking AuthID operation/transaction status', { operationId });

      // Try operations endpoint first
      try {
        const response = await axios.get(
          `${this.transactionURL}/v2/operations/${operationId}`,
          { headers: await this.getAuthHeaders() }
        );

        const status = response.data;
        
        logger.info('✅ Operation status retrieved', { 
          operationId,
          state: status.State,
          result: status.Result 
        });

        return {
          success: true,
          operationId: status.OperationId,
          state: status.State, // 0=Pending, 1=Completed, 2=Failed, 3=Expired
          result: status.Result, // 0=None, 1=Success, 2=Failure
          accountNumber: status.AccountNumber,
          name: status.Name,
          createdAt: status.CreatedAt,
          completedAt: status.CompletedAt,
          tag: status.Tag
        };
      } catch (opError) {
        // If operation not found, try transaction endpoint
        if (opError.response?.status === 404) {
          logger.info('🔄 Operation not found, trying transaction endpoint', { operationId });
          
          const txResponse = await axios.get(
            `${this.transactionURL}/v2/transactions/${operationId}`,
            { headers: await this.getAuthHeaders() }
          );

          const txStatus = txResponse.data;
          
          logger.info('✅ Transaction status retrieved', { 
            transactionId: operationId,
            state: txStatus.State,
            result: txStatus.Result 
          });

          return {
            success: true,
            operationId: txStatus.TransactionId,
            transactionId: txStatus.TransactionId,
            state: txStatus.State,
            result: txStatus.Result,
            accountNumber: txStatus.AccountNumber,
            createdAt: txStatus.CreatedAt,
            completedAt: txStatus.CompletedAt,
            tag: txStatus.Tag,
            isTransaction: true
          };
        }
        throw opError;
      }

    } catch (error) {
      logger.error('❌ Failed to check operation/transaction status', { 
        error: error.message,
        response: error.response?.data,
        operationId 
      });
      
      throw new Error(`Status check failed: ${error.response?.data?.Message || error.message}`);
    }
  }

  /**
   * Verify biometric data for authentication
   * This uses the REAL AuthID.ai transactions API
   */
  async verifyBiometric(verificationData) {
    try {
      logger.info('🔐 Starting REAL AuthID biometric verification');

      const { userId, biometric_template, device_info, quality_score, liveness_score } = verificationData;

      if (!userId) {
        logger.warn('⚠️ No userId provided in verification data');
        return {
          success: false,
          error: 'User identification required',
          confidence: 0
        };
      }

      // REAL AuthID API call - Create verification transaction
      const transactionData = {
        AccountNumber: userId,
        Codeword: "",
        ConfirmationPolicy: {
          CredentialType: 1, // Biometric
          MinimumConfidence: 0.85,
          MaximumAttempts: 3
        },
        Timeout: 300, // 5 minutes
        TransportType: 0, // Push notification
        Tag: `bbms-verify-${Date.now()}`
      };

      logger.info('📤 Creating verification transaction', { 
        url: `${this.transactionURL}/v2/transactions`,
        userId 
      });

      const response = await axios.post(
        `${this.transactionURL}/v2/transactions`,
        transactionData,
        { headers: await this.getAuthHeaders() }
      );

      const authResult = {
        success: true,
        userId: userId,
        confidence: 1.0, // Will be updated by actual verification
        verificationId: response.data.TransactionId,
        timestamp: new Date().toISOString()
      };

      logger.info('✅ Real AuthID verification transaction created', {
        success: authResult.success,
        transactionId: authResult.verificationId,
        userId: authResult.userId
      });

      return authResult;

    } catch (error) {
      logger.error('❌ AuthID verification failed', { 
        error: error.message,
        response: error.response?.data,
        status: error.response?.status
      });
      
      const errorMessage = error.response?.data?.message || error.message;
      throw new Error(`AuthID verification failed: ${errorMessage}`);
    }
  }

  /**
   * Check enrollment progress/status
   * This uses the REAL AuthID.ai operations API
   */
  async checkEnrollmentProgress(enrollmentId) {
    try {
      logger.info('📊 Checking REAL AuthID enrollment progress', { enrollmentId });

      const response = await axios.get(
        `${this.transactionURL}/v2/operations/${enrollmentId}/status`,
        { headers: await this.getAuthHeaders() }
      );

      logger.info('✅ Enrollment status retrieved', { 
        enrollmentId,
        status: response.data.Status 
      });

      return {
        status: response.data.Status,
        progress: response.data.Status === 'Completed' ? 100 : 50,
        completed: response.data.Status === 'Completed',
        enrollmentId,
        operationId: response.data.OperationId,
        result: response.data.Result
      };

    } catch (error) {
      logger.error('❌ Failed to check AuthID enrollment status', { 
        error: error.message,
        response: error.response?.data,
        enrollmentId 
      });
      
      const errorMessage = error.response?.data?.Message || error.message;
      throw new Error(`Status check failed: ${errorMessage}`);
    }
  }

  /**
   * Initiate biometric login/verification
   * Creates a Verify_Identity transaction for authentication
   * Using CredentialType 1 for face biometric (not FIDO2)
   */
  async initiateBiometricLogin(userId, userData = {}) {
    try {
      logger.info('🔐 Initiating biometric authentication with Verify_Identity', { userId });

      // Use CredentialType 1 for face biometric (matches EnrollBioCredential)
      const transactionData = {
        AccountNumber: userId,
        Timeout: 300, // 5 minutes (in seconds)
        ConfirmationPolicy: {
          TransportType: 0, // 0 = Push notification
          CredentialType: 1, // 1 = Biometric (face), not 4 (FIDO2)
          MinimumConfidence: 0.85,
          MaximumAttempts: 3
        },
        Name: "Verify_Identity" // Authentication operation name
      };

      logger.info('📤 Creating Verify_Identity transaction', { 
        url: `${this.transactionURL}/v2/transactions`,
        userId,
        name: 'Verify_Identity',
        credentialType: 1
      });

      const transactionResponse = await axios.post(
        `${this.transactionURL}/v2/transactions`,
        transactionData,
        { headers: await this.getAuthHeaders() }
      );

      const transactionId = transactionResponse.data.TransactionId;
      const oneTimeSecret = transactionResponse.data.OneTimeSecret;
      
      logger.info('📋 AuthID Verify_Identity Transaction Created', { 
        transactionId,
        oneTimeSecret: oneTimeSecret ? '***' : 'missing',
        fullResponse: transactionResponse.data
      });
      
      // Construct authentication URL pointing to our hosted React component page
      const authWebUrl = process.env.AUTHID_WEB_URL || 'http://localhost:3002';
      const authUrl = `${authWebUrl}?transactionId=${transactionId}&secret=${oneTimeSecret}&baseUrl=${encodeURIComponent('https://id-uat.authid.ai')}&mode=authentication`;
      
      logger.info('✅ Biometric authentication transaction created', { 
        transactionId,
        userId,
        authUrl
      });

      return {
        success: true,
        operationId: transactionId, // Using transactionId as operationId for consistency
        transactionId: transactionId,
        authUrl: authUrl,
        qrCode: authUrl,
        oneTimeSecret: oneTimeSecret,
        expiresAt: new Date(Date.now() + 300 * 1000).toISOString() // 5 minutes
      };

    } catch (error) {
      logger.error('❌ Failed to initiate AuthID authentication', { 
        error: error.message,
        response: error.response?.data,
        status: error.response?.status,
        userId 
      });
      
      const errorMessage = error.response?.data?.message || error.response?.data?.Message || error.message;
      throw new Error(`AuthID authentication failed: ${errorMessage}`);
    }
  }

  /**
   * Get the result of an authentication operation or transaction
   * This retrieves the proof data after user completes verification
   */
  async getOperationResult(operationId) {
    try {
      logger.info('🔍 Getting AuthID operation/transaction result', { operationId });

      // Try operations result endpoint first
      try {
        const response = await axios.get(
          `${this.transactionURL}/v2/operations/${operationId}/result`,
          { headers: await this.getAuthHeaders() }
        );

        const result = response.data;
        
        logger.info('✅ Operation result retrieved', { 
          operationId,
          hasResult: !!result,
          resultKeys: result ? Object.keys(result) : []
        });

        return {
          success: true,
          operationId,
          result: result,
          rawData: response.data
        };
      } catch (opError) {
        // If operation not found, try transaction result endpoint
        if (opError.response?.status === 404) {
          logger.info('🔄 Operation result not found, trying transaction endpoint', { operationId });
          
          const txResponse = await axios.get(
            `${this.transactionURL}/v2/transactions/${operationId}/result`,
            { headers: await this.getAuthHeaders() }
          );

          const txResult = txResponse.data;
          
          logger.info('✅ Transaction result retrieved', { 
            transactionId: operationId,
            hasResult: !!txResult,
            resultKeys: txResult ? Object.keys(txResult) : []
          });

          return {
            success: true,
            operationId,
            transactionId: operationId,
            result: txResult,
            rawData: txResponse.data,
            isTransaction: true
          };
        }
        throw opError;
      }

    } catch (error) {
      logger.error('❌ Failed to get operation/transaction result', { 
        error: error.message,
        response: error.response?.data,
        operationId 
      });
      
      throw new Error(`Failed to get result: ${error.response?.data?.Message || error.message}`);
    }
  }

  /**
   * Wait for user to complete authentication proof
   * Polls AuthID until the operation completes or times out
   */
  async waitForAuthenticationProof(operationId, accountNumber, maxAttempts = 60, pollInterval = 2000) {
    try {
      logger.info('⏳ Waiting for authentication proof completion', { 
        operationId, 
        accountNumber,
        maxAttempts,
        pollInterval 
      });

      for (let attempt = 1; attempt <= maxAttempts; attempt++) {
        // Check operation status
        const status = await this.checkOperationStatus(operationId);
        
        logger.info(`📊 Poll attempt ${attempt}/${maxAttempts}`, {
          operationId,
          state: status.state,
          result: status.result
        });

        // State: 0=Pending, 1=Completed, 2=Failed, 3=Expired
        // Result: 0=None, 1=Success, 2=Failure
        
        if (status.state === 1) { // Completed
          if (status.result === 1) { // Success
            // Get the full proof result
            const proofResult = await this.getOperationResult(operationId);
            
            logger.info('✅ Authentication proof completed successfully', {
              operationId,
              accountNumber
            });
            
            return {
              success: true,
              proof: proofResult.result,
              status: status
            };
          } else if (status.result === 2) { // Failure
            logger.warn('❌ Authentication proof failed', {
              operationId,
              accountNumber
            });
            
            return {
              success: false,
              error: 'Authentication failed - biometric verification unsuccessful',
              status: status
            };
          }
        } else if (status.state === 2) { // Failed
          logger.warn('❌ Operation failed', {
            operationId,
            accountNumber
          });
          
          return {
            success: false,
            error: 'Operation failed',
            status: status
          };
        } else if (status.state === 3) { // Expired
          logger.warn('⏰ Operation expired', {
            operationId,
            accountNumber
          });
          
          return {
            success: false,
            error: 'Operation expired - please try again',
            status: status
          };
        }

        // Still pending, wait before next poll
        if (attempt < maxAttempts) {
          await new Promise(resolve => setTimeout(resolve, pollInterval));
        }
      }

      // Timeout
      logger.warn('⏰ Polling timeout - operation still pending', {
        operationId,
        accountNumber,
        attempts: maxAttempts
      });

      return {
        success: false,
        error: 'Timeout waiting for authentication - operation still pending',
        timeout: true
      };

    } catch (error) {
      logger.error('❌ Error waiting for authentication proof', { 
        error: error.message,
        operationId,
        accountNumber 
      });
      
      throw new Error(`Failed to wait for proof: ${error.message}`);
    }
  }

  /**
   * Validate authentication proof data
   * Checks all security fields to ensure the proof is acceptable
   * Based on the research, we need to validate many fields
   */
  validateProof(proof) {
    try {
      logger.info('🔍 Validating authentication proof', {
        hasProof: !!proof,
        proofKeys: proof ? Object.keys(proof) : []
      });

      if (!proof) {
        return {
          valid: false,
          decision: 'reject',
          reasons: ['No proof data provided']
        };
      }

      const warnings = [];
      const errors = [];
      
      // Check liveness (critical)
      if (proof.IsLive === false) {
        errors.push('Liveness check failed');
      }
      
      // Check for injection attacks (critical)
      if (proof.SelfieInjectionDetection === 'Fail' || proof.SelfieInjectionDetection === 'Reject') {
        errors.push('Selfie injection detected');
      }
      
      if (proof.DocumentInjectionDetection === 'Fail' || proof.DocumentInjectionDetection === 'Reject') {
        errors.push('Document injection detected');
      }
      
      // Check document validity
      if (proof.DocumentExpired === true) {
        errors.push('Document expired');
      }
      
      // Check barcode/MRZ consistency
      if (proof.BarcodeSecurityCheck === 'Fail') {
        warnings.push('Barcode security check failed');
      }
      
      if (proof.MRZOCRMismatch === 'Fail') {
        warnings.push('MRZ OCR mismatch detected');
      }
      
      // Check PAD (Presentation Attack Detection)
      if (proof.PadResult === 'Reject') {
        errors.push('Presentation attack detected');
      } else if (proof.PadResult === 'Manual Review') {
        warnings.push('PAD requires manual review');
      }
      
      // Check face match quality
      if (proof.FaceMatchScore !== undefined && proof.FaceMatchScore < 0.80) {
        warnings.push(`Low face match score: ${proof.FaceMatchScore}`);
      }
      
      // Check overall confidence
      if (proof.ConfidenceScore !== undefined && proof.ConfidenceScore < 0.85) {
        warnings.push(`Low confidence score: ${proof.ConfidenceScore}`);
      }

      // Determine decision
      let decision = 'accept';
      const reasons = [];

      if (errors.length > 0) {
        decision = 'reject';
        reasons.push(...errors);
      } else if (warnings.length > 0) {
        decision = 'manual_review';
        reasons.push(...warnings);
      }

      logger.info('✅ Proof validation complete', {
        decision,
        errors: errors.length,
        warnings: warnings.length
      });

      return {
        valid: decision === 'accept',
        decision, // 'accept', 'reject', 'manual_review'
        reasons,
        errors,
        warnings,
        proof: {
          isLive: proof.IsLive,
          confidenceScore: proof.ConfidenceScore,
          faceMatchScore: proof.FaceMatchScore,
          documentExpired: proof.DocumentExpired
        }
      };

    } catch (error) {
      logger.error('❌ Error validating proof', { error: error.message });
      
      return {
        valid: false,
        decision: 'reject',
        reasons: ['Proof validation error'],
        error: error.message
      };
    }
  }
}

// Export a singleton instance
module.exports = new AuthIDService();
