const { v4: uuidv4 } = require('uuid');
const logger = require('../utils/logger');

/**
 * User Service - Handles user data management
 * This is a simplified in-memory implementation.
 * In production, this should be replaced with a proper database.
 */
class UserService {
  constructor() {
    // In-memory storage (replace with database in production)
    this.users = new Map();
    this.biometricEnrollments = new Map();
    this.biometricPreferences = new Map();
    this.accessLogs = new Map();
    
    // Initialize with some sample users for development
    this.initializeSampleUsers();
  }

  /**
   * Initialize sample users for development
   */
  initializeSampleUsers() {
    const sampleUsers = [
      {
        id: uuidv4(),
        name: 'Marcos Rosiles',
        email: 'marcos@bbms.ai',
        password: '$2a$12$IWQerjq2TXe8PnKVJgmM0.kHRhAGwhQFwxEp6ElB17q.OuSd1vsJa', // password: admin123
        department: 'QA',
        role: 'admin',
        accessLevel: 'admin',
        isActive: true,
        createdAt: new Date('2023-01-01'),
        lastLoginAt: null
      },
      {
        id: uuidv4(),
        name: 'Dr. Oscar Chaparro',
        email: 'oscar@bbms.ai',
        password: '$2a$12$IWQerjq2TXe8PnKVJgmM0.kHRhAGwhQFwxEp6ElB17q.OuSd1vsJa', // password: admin123
        department: 'Facilities',
        role: 'manager',
        accessLevel: 'elevated',
        isActive: true,
        createdAt: new Date('2023-02-01'),
        lastLoginAt: null
      },
      {
        id: uuidv4(),
        name: 'Clay Perreault',
        email: 'clay@bbms.ai',
        password: '$2a$12$IWQerjq2TXe8PnKVJgmM0.kHRhAGwhQFwxEp6ElB17q.OuSd1vsJa', // password: admin123
        department: 'Dev',
        role: 'user',
        accessLevel: 'standard',
        isActive: true,
        createdAt: new Date('2023-03-01'),
        lastLoginAt: null
      },
      {
        id: uuidv4(),
        name: 'Valeria Cabrera',
        email: 'valeria@bbms.ai',
        password: '$2a$12$IWQerjq2TXe8PnKVJgmM0.kHRhAGwhQFwxEp6ElB17q.OuSd1vsJa', // password: admin123
        department: 'UXUI',
        role: 'user',
        accessLevel: 'standard',
        isActive: true,
        createdAt: new Date('2023-04-01'),
        lastLoginAt: null
      }
    ];

    sampleUsers.forEach(user => {
      this.users.set(user.id, user);
    });

    logger.info(`📊 Initialized ${sampleUsers.length} sample users`);
  }

  /**
   * Create a new user
   */
  async createUser(userData) {
    const user = {
      id: uuidv4(),
      ...userData,
      createdAt: new Date(),
      lastLoginAt: null
    };

    this.users.set(user.id, user);
    logger.info(`👤 Created new user: ${user.email}`);
    
    return user;
  }

  /**
   * Get user by ID
   */
  async getUserById(userId) {
    return this.users.get(userId) || null;
  }

  /**
   * Get user by email
   */
  async getUserByEmail(email) {
    for (const [, user] of this.users) {
      if (user.email.toLowerCase() === email.toLowerCase()) {
        return user;
      }
    }
    return null;
  }

  /**
   * Update user
   */
  async updateUser(userId, updates) {
    const user = this.users.get(userId);
    if (!user) {
      throw new Error('User not found');
    }

    const updatedUser = {
      ...user,
      ...updates,
      updatedAt: new Date()
    };

    this.users.set(userId, updatedUser);
    logger.info(`👤 Updated user: ${user.email}`);
    
    return updatedUser;
  }

  /**
   * Update user's last login time
   */
  async updateLastLogin(userId) {
    const user = this.users.get(userId);
    if (user) {
      user.lastLoginAt = new Date();
      this.users.set(userId, user);
    }
  }

  /**
   * Get all users (admin only)
   */
  async getAllUsers(filters = {}) {
    let users = Array.from(this.users.values());

    // Apply filters
    if (filters.role) {
      users = users.filter(user => user.role === filters.role);
    }
    if (filters.department) {
      users = users.filter(user => user.department === filters.department);
    }
    if (filters.isActive !== undefined) {
      users = users.filter(user => user.isActive === filters.isActive);
    }

    // Remove password from results
    return users.map(user => {
      const { password, ...userWithoutPassword } = user;
      return userWithoutPassword;
    });
  }

  /**
   * Deactivate user
   */
  async deactivateUser(userId) {
    const user = this.users.get(userId);
    if (!user) {
      throw new Error('User not found');
    }

    user.isActive = false;
    user.deactivatedAt = new Date();
    this.users.set(userId, user);
    
    logger.info(`🚫 Deactivated user: ${user.email}`);
    return user;
  }

  /**
   * Save biometric enrollment data
   */
  async saveBiometricEnrollment(userId, enrollmentData) {
    this.biometricEnrollments.set(userId, enrollmentData);
    logger.info(`🔐 Saved biometric enrollment for user: ${userId}`);
  }

  /**
   * Get biometric enrollment data
   */
  async getBiometricEnrollment(userId) {
    return this.biometricEnrollments.get(userId) || null;
  }

  /**
   * Get user by enrollment ID
   */
  async getUserByEnrollmentId(enrollmentId) {
    // Find the user that has this enrollment ID
    for (const [userId, enrollment] of this.biometricEnrollments) {
      if (enrollment.enrollmentId === enrollmentId) {
        const user = await this.getUserById(userId);
        if (user) {
          logger.info(`🔍 Found user by enrollment ID ${enrollmentId}: ${user.email}`);
          return user;
        }
      }
    }
    logger.warn(`⚠️ No user found with enrollment ID: ${enrollmentId}`);
    return null;
  }

  /**
   * Find user by login operation ID
   * Used during biometric login to identify which user is logging in
   */
  async getUserByLoginOperation(operationId) {
    // Find the user that has this pending login operation
    for (const [userId, user] of this.users) {
      if (user.pending_login_operation === operationId) {
        logger.info(`🔍 Found user by login operation ${operationId}: ${user.email}`);
        return user;
      }
    }
    logger.warn(`⚠️ No user found with login operation: ${operationId}`);
    return null;
  }

  /**
   * Find user by biometric template
   * In production, this would query a proper database
   */
  async getUserByBiometricTemplate(biometricTemplate) {
    // For development, we'll use device_id from the template as a simple identifier
    // In production, this would match against stored biometric templates in AuthID
    
    // For now, return the first enrolled user or a default user
    for (const [userId, enrollment] of this.biometricEnrollments) {
      if (enrollment.status === 'completed') {
        const user = await this.getUserById(userId);
        if (user) {
          logger.info(`🔍 Found user by biometric template: ${user.email}`);
          return user;
        }
      }
    }
    
    // Fallback to first active user for development
    for (const [, user] of this.users) {
      if (user.isActive) {
        logger.info(`🔍 Using default active user for biometric: ${user.email}`);
        return user;
      }
    }
    
    return null;
  }

  /**
   * Update biometric enrollment status
   */
  async updateBiometricEnrollmentStatus(userId, status) {
    const enrollment = this.biometricEnrollments.get(userId);
    if (enrollment) {
      enrollment.status = status;
      enrollment.updatedAt = new Date();
      this.biometricEnrollments.set(userId, enrollment);
      logger.info(`🔐 Updated biometric enrollment status for user ${userId}: ${status}`);
    }
  }

  /**
   * Clear biometric enrollment
   */
  async clearBiometricEnrollment(userId) {
    this.biometricEnrollments.delete(userId);
    logger.info(`🗑️ Cleared biometric enrollment for user: ${userId}`);
  }

  /**
   * Get biometric preferences
   */
  async getBiometricPreferences(userId) {
    return this.biometricPreferences.get(userId) || null;
  }

  /**
   * Update biometric preferences
   */
  async updateBiometricPreferences(userId, preferences) {
    this.biometricPreferences.set(userId, preferences);
    logger.info(`⚙️ Updated biometric preferences for user: ${userId}`);
  }

  /**
   * Log user access
   */
  async logUserAccess(userId, loginType, ipAddress, metadata = {}) {
    const accessLog = {
      id: uuidv4(),
      userId,
      loginType,
      ipAddress,
      timestamp: new Date(),
      metadata
    };

    if (!this.accessLogs.has(userId)) {
      this.accessLogs.set(userId, []);
    }

    const userLogs = this.accessLogs.get(userId);
    userLogs.push(accessLog);

    // Keep only last 100 access logs per user
    if (userLogs.length > 100) {
      userLogs.splice(0, userLogs.length - 100);
    }

    this.accessLogs.set(userId, userLogs);

    // Update last login time
    await this.updateLastLogin(userId);

    logger.info(`📊 Logged access for user ${userId}: ${loginType} from ${ipAddress}`);
  }

  /**
   * Get user access logs
   */
  async getUserAccessLogs(userId, limit = 50) {
    const logs = this.accessLogs.get(userId) || [];
    return logs
      .sort((a, b) => b.timestamp - a.timestamp)
      .slice(0, limit);
  }

  /**
   * Get building access statistics
   */
  async getBuildingAccessStats(timeframe = 'day') {
    const now = new Date();
    let startTime;

    switch (timeframe) {
      case 'hour':
        startTime = new Date(now.getTime() - 60 * 60 * 1000);
        break;
      case 'day':
        startTime = new Date(now.getTime() - 24 * 60 * 60 * 1000);
        break;
      case 'week':
        startTime = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
        break;
      case 'month':
        startTime = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
        break;
      default:
        startTime = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    }

    const stats = {
      totalAccess: 0,
      biometricAccess: 0,
      passwordAccess: 0,
      uniqueUsers: new Set(),
      accessByHour: new Array(24).fill(0)
    };

    for (const [userId, logs] of this.accessLogs) {
      for (const log of logs) {
        if (log.timestamp >= startTime) {
          stats.totalAccess++;
          stats.uniqueUsers.add(userId);

          if (log.loginType === 'biometric_login') {
            stats.biometricAccess++;
          } else if (log.loginType === 'password_login') {
            stats.passwordAccess++;
          }

          const hour = log.timestamp.getHours();
          stats.accessByHour[hour]++;
        }
      }
    }

    stats.uniqueUsers = stats.uniqueUsers.size;

    return stats;
  }

  /**
   * Search users
   */
  async searchUsers(query, limit = 20) {
    const searchTerm = query.toLowerCase();
    const users = Array.from(this.users.values())
      .filter(user => 
        user.isActive &&
        (user.name.toLowerCase().includes(searchTerm) ||
         user.email.toLowerCase().includes(searchTerm) ||
         user.department.toLowerCase().includes(searchTerm))
      )
      .slice(0, limit);

    // Remove password from results
    return users.map(user => {
      const { password, ...userWithoutPassword } = user;
      return userWithoutPassword;
    });
  }
}

module.exports = new UserService();