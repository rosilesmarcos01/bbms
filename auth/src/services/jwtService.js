const jwt = require('jsonwebtoken');
const logger = require('../utils/logger');

/**
 * JWT Service - Handles token generation and validation
 * Centralized service for all JWT operations
 */
class JWTService {
  constructor() {
    this.secret = process.env.JWT_SECRET;
    this.accessTokenExpiry = process.env.JWT_EXPIRES_IN || '24h';
    this.refreshTokenExpiry = process.env.JWT_REFRESH_EXPIRES_IN || '7d';

    if (!this.secret) {
      logger.error('❌ JWT_SECRET is not configured');
      throw new Error('JWT_SECRET is required in environment variables');
    }

    logger.info('✅ JWT Service initialized');
  }

  /**
   * Generate access and refresh tokens for a user
   * @param {Object} user - User object with id, email, role, accessLevel
   * @returns {Object} - { accessToken, refreshToken, expiresIn }
   */
  generateTokens(user) {
    try {
      // Access token payload - includes user info for authorization
      const accessPayload = {
        userId: user.id,
        email: user.email,
        role: user.role || 'user',
        accessLevel: user.accessLevel || 'standard',
        name: user.name || user.email,
        department: user.department || 'Unknown'
      };

      // Refresh token payload - minimal info for token refresh
      const refreshPayload = {
        userId: user.id,
        tokenType: 'refresh'
      };

      const accessToken = jwt.sign(accessPayload, this.secret, {
        expiresIn: this.accessTokenExpiry,
        issuer: 'bbms-auth-service',
        audience: 'bbms-api'
      });

      const refreshToken = jwt.sign(refreshPayload, this.secret, {
        expiresIn: this.refreshTokenExpiry,
        issuer: 'bbms-auth-service',
        audience: 'bbms-api'
      });

      // Calculate expiry timestamp
      const expiresIn = this.parseExpiryToSeconds(this.accessTokenExpiry);

      logger.info(`🔑 Generated tokens for user: ${user.email} (${user.id})`);

      return {
        accessToken,
        refreshToken,
        expiresIn,
        tokenType: 'Bearer'
      };
    } catch (error) {
      logger.error('❌ Failed to generate tokens:', error.message);
      throw new Error('Token generation failed');
    }
  }

  /**
   * Verify and decode an access token
   * @param {string} token - JWT token to verify
   * @returns {Object} - Decoded token payload
   */
  verifyAccessToken(token) {
    try {
      const decoded = jwt.verify(token, this.secret, {
        issuer: 'bbms-auth-service',
        audience: 'bbms-api'
      });

      return decoded;
    } catch (error) {
      if (error.name === 'TokenExpiredError') {
        logger.warn('⚠️ Token expired');
        throw new Error('Token expired');
      } else if (error.name === 'JsonWebTokenError') {
        logger.warn('⚠️ Invalid token');
        throw new Error('Invalid token');
      }
      throw error;
    }
  }

  /**
   * Verify and decode a refresh token
   * @param {string} token - Refresh token to verify
   * @returns {Object} - Decoded token payload
   */
  verifyRefreshToken(token) {
    try {
      const decoded = jwt.verify(token, this.secret, {
        issuer: 'bbms-auth-service',
        audience: 'bbms-api'
      });

      if (decoded.tokenType !== 'refresh') {
        throw new Error('Invalid token type');
      }

      return decoded;
    } catch (error) {
      if (error.name === 'TokenExpiredError') {
        logger.warn('⚠️ Refresh token expired');
        throw new Error('Refresh token expired');
      } else if (error.name === 'JsonWebTokenError') {
        logger.warn('⚠️ Invalid refresh token');
        throw new Error('Invalid refresh token');
      }
      throw error;
    }
  }

  /**
   * Generate a new access token from a refresh token
   * @param {string} refreshToken - Valid refresh token
   * @param {Object} user - User object to generate new token for
   * @returns {Object} - { accessToken, expiresIn }
   */
  refreshAccessToken(refreshToken, user) {
    try {
      // Verify refresh token
      const decoded = this.verifyRefreshToken(refreshToken);

      // Ensure user ID matches
      if (decoded.userId !== user.id) {
        throw new Error('Token user mismatch');
      }

      // Generate new access token
      const accessPayload = {
        userId: user.id,
        email: user.email,
        role: user.role || 'user',
        accessLevel: user.accessLevel || 'standard',
        name: user.name || user.email,
        department: user.department || 'Unknown'
      };

      const accessToken = jwt.sign(accessPayload, this.secret, {
        expiresIn: this.accessTokenExpiry,
        issuer: 'bbms-auth-service',
        audience: 'bbms-api'
      });

      const expiresIn = this.parseExpiryToSeconds(this.accessTokenExpiry);

      logger.info(`🔄 Refreshed access token for user: ${user.email}`);

      return {
        accessToken,
        expiresIn,
        tokenType: 'Bearer'
      };
    } catch (error) {
      logger.error('❌ Failed to refresh token:', error.message);
      throw error;
    }
  }

  /**
   * Parse expiry time string to seconds
   * @param {string} expiry - Expiry time (e.g., '24h', '7d', '3600')
   * @returns {number} - Expiry in seconds
   */
  parseExpiryToSeconds(expiry) {
    if (typeof expiry === 'number') {
      return expiry;
    }

    const regex = /^(\d+)([smhd])$/;
    const match = regex.exec(expiry);
    if (!match) {
      return 86400; // Default to 24 hours
    }

    const value = parseInt(match[1], 10);
    const unit = match[2];

    const multipliers = {
      s: 1,
      m: 60,
      h: 3600,
      d: 86400
    };

    return value * multipliers[unit];
  }

  /**
   * Decode token without verification (for debugging)
   * @param {string} token - JWT token
   * @returns {Object} - Decoded token
   */
  decodeToken(token) {
    return jwt.decode(token);
  }
}

// Export singleton instance
module.exports = new JWTService();
