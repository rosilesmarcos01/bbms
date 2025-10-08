const express = require('express');
const { body, query, validationResult } = require('express-validator');

const userService = require('../services/userService');
const authIdService = require('../services/authIdService');
const authMiddleware = require('../middleware/authMiddleware');
const logger = require('../utils/logger');

const router = express.Router();

// All user routes require authentication
router.use(authMiddleware.verifyToken);

/**
 * Get current user profile
 * GET /api/users/profile
 */
router.get('/profile', async (req, res) => {
  try {
    const userId = req.user.userId;
    const user = await userService.getUserById(userId);
    
    if (!user) {
      return res.status(404).json({
        error: 'User not found',
        code: 'USER_NOT_FOUND'
      });
    }

    // Get biometric enrollment status
    const biometricEnrollment = await userService.getBiometricEnrollment(userId);
    const biometricPreferences = await userService.getBiometricPreferences(userId);

    res.json({
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        department: user.department,
        role: user.role,
        accessLevel: user.accessLevel,
        isActive: user.isActive,
        createdAt: user.createdAt,
        lastLoginAt: user.lastLoginAt
      },
      biometric: {
        enrollmentStatus: biometricEnrollment?.status || 'not_enrolled',
        enrollmentCompleted: biometricEnrollment?.status === 'completed',
        preferences: biometricPreferences || {
          enableBiometricLogin: false,
          enableBuildingAccess: false,
          requireBiometricForSensitiveActions: false
        }
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
 * Update user profile
 * PUT /api/users/profile
 */
router.put('/profile', [
  body('name').optional().trim().isLength({ min: 2, max: 100 }).withMessage('Name must be 2-100 characters'),
  body('department').optional().trim().isLength({ min: 2, max: 50 }).withMessage('Department must be 2-50 characters')
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
    const { name, department } = req.body;

    const updates = {};
    if (name) updates.name = name;
    if (department) updates.department = department;

    const updatedUser = await userService.updateUser(userId, updates);

    logger.info(`👤 User profile updated: ${updatedUser.email}`);

    res.json({
      message: 'Profile updated successfully',
      user: {
        id: updatedUser.id,
        name: updatedUser.name,
        email: updatedUser.email,
        department: updatedUser.department,
        role: updatedUser.role,
        accessLevel: updatedUser.accessLevel
      }
    });

  } catch (error) {
    logger.error('❌ Failed to update user profile:', error.message);
    res.status(500).json({
      error: 'Failed to update user profile',
      code: 'PROFILE_UPDATE_ERROR'
    });
  }
});

/**
 * Get user access logs
 * GET /api/users/access-logs
 */
router.get('/access-logs', [
  query('limit').optional().isInt({ min: 1, max: 100 }).withMessage('Limit must be between 1 and 100')
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
    const limit = parseInt(req.query.limit) || 50;

    const accessLogs = await userService.getUserAccessLogs(userId, limit);

    res.json({
      accessLogs: accessLogs.map(log => ({
        id: log.id,
        loginType: log.loginType,
        timestamp: log.timestamp,
        ipAddress: log.ipAddress,
        metadata: log.metadata
      }))
    });

  } catch (error) {
    logger.error('❌ Failed to get access logs:', error.message);
    res.status(500).json({
      error: 'Failed to get access logs',
      code: 'ACCESS_LOGS_ERROR'
    });
  }
});

/**
 * Get all users (admin/manager only)
 * GET /api/users
 */
router.get('/', 
  authMiddleware.requireRole(['admin', 'manager']),
  [
    query('role').optional().isIn(['admin', 'manager', 'technician', 'user']).withMessage('Invalid role'),
    query('department').optional().trim(),
    query('isActive').optional().isBoolean().withMessage('isActive must be boolean'),
    query('limit').optional().isInt({ min: 1, max: 100 }).withMessage('Limit must be between 1 and 100'),
    query('offset').optional().isInt({ min: 0 }).withMessage('Offset must be non-negative')
  ],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          error: 'Validation failed',
          code: 'VALIDATION_ERROR',
          details: errors.array()
        });
      }

      const filters = {};
      if (req.query.role) filters.role = req.query.role;
      if (req.query.department) filters.department = req.query.department;
      if (req.query.isActive !== undefined) filters.isActive = req.query.isActive === 'true';

      const users = await userService.getAllUsers(filters);
      
      // Apply pagination
      const limit = parseInt(req.query.limit) || 50;
      const offset = parseInt(req.query.offset) || 0;
      const paginatedUsers = users.slice(offset, offset + limit);

      res.json({
        users: paginatedUsers,
        pagination: {
          total: users.length,
          limit,
          offset,
          hasMore: offset + limit < users.length
        }
      });

    } catch (error) {
      logger.error('❌ Failed to get users:', error.message);
      res.status(500).json({
        error: 'Failed to get users',
        code: 'USERS_ERROR'
      });
    }
  }
);

/**
 * Update user role/access level (admin only)
 * PUT /api/users/:userId/permissions
 */
router.put('/:userId/permissions',
  authMiddleware.requireRole(['admin']),
  [
    body('role').optional().isIn(['admin', 'manager', 'technician', 'user']).withMessage('Invalid role'),
    body('accessLevel').optional().isIn(['basic', 'standard', 'elevated', 'admin']).withMessage('Invalid access level')
  ],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          error: 'Validation failed',
          code: 'VALIDATION_ERROR',
          details: errors.array()
        });
      }

      const { userId } = req.params;
      const { role, accessLevel } = req.body;

      // Check if user exists
      const user = await userService.getUserById(userId);
      if (!user) {
        return res.status(404).json({
          error: 'User not found',
          code: 'USER_NOT_FOUND'
        });
      }

      // Prevent admin from modifying their own permissions
      if (userId === req.user.userId) {
        return res.status(403).json({
          error: 'Cannot modify your own permissions',
          code: 'SELF_MODIFICATION_DENIED'
        });
      }

      const updates = {};
      if (role) updates.role = role;
      if (accessLevel) updates.accessLevel = accessLevel;

      const updatedUser = await userService.updateUser(userId, updates);

      // Update access level in AuthID.ai if user has biometric enrollment
      if (accessLevel) {
        try {
          const biometricEnrollment = await userService.getBiometricEnrollment(userId);
          if (biometricEnrollment && biometricEnrollment.status === 'completed') {
            await authIdService.updateUserAccessLevel(userId, accessLevel);
          }
        } catch (error) {
          logger.warn(`⚠️ Failed to update AuthID.ai access level: ${error.message}`);
        }
      }

      logger.info(`🔑 User permissions updated: ${user.email} by ${req.user.email}`);

      res.json({
        message: 'User permissions updated successfully',
        user: {
          id: updatedUser.id,
          name: updatedUser.name,
          email: updatedUser.email,
          role: updatedUser.role,
          accessLevel: updatedUser.accessLevel
        }
      });

    } catch (error) {
      logger.error('❌ Failed to update user permissions:', error.message);
      res.status(500).json({
        error: 'Failed to update user permissions',
        code: 'PERMISSIONS_UPDATE_ERROR'
      });
    }
  }
);

/**
 * Deactivate user (admin only)
 * DELETE /api/users/:userId
 */
router.delete('/:userId',
  authMiddleware.requireRole(['admin']),
  async (req, res) => {
    try {
      const { userId } = req.params;

      // Check if user exists
      const user = await userService.getUserById(userId);
      if (!user) {
        return res.status(404).json({
          error: 'User not found',
          code: 'USER_NOT_FOUND'
        });
      }

      // Prevent admin from deactivating themselves
      if (userId === req.user.userId) {
        return res.status(403).json({
          error: 'Cannot deactivate your own account',
          code: 'SELF_DEACTIVATION_DENIED'
        });
      }

      // Deactivate user
      await userService.deactivateUser(userId);

      // Revoke biometric data
      try {
        await authIdService.revokeBiometricData(userId);
        await userService.clearBiometricEnrollment(userId);
      } catch (error) {
        logger.warn(`⚠️ Failed to revoke biometric data: ${error.message}`);
      }

      logger.info(`🚫 User deactivated: ${user.email} by ${req.user.email}`);

      res.json({
        message: 'User deactivated successfully'
      });

    } catch (error) {
      logger.error('❌ Failed to deactivate user:', error.message);
      res.status(500).json({
        error: 'Failed to deactivate user',
        code: 'USER_DEACTIVATION_ERROR'
      });
    }
  }
);

/**
 * Search users (admin/manager only)
 * GET /api/users/search
 */
router.get('/search',
  authMiddleware.requireRole(['admin', 'manager']),
  [
    query('q').notEmpty().withMessage('Search query is required'),
    query('limit').optional().isInt({ min: 1, max: 50 }).withMessage('Limit must be between 1 and 50')
  ],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          error: 'Validation failed',
          code: 'VALIDATION_ERROR',
          details: errors.array()
        });
      }

      const { q: query } = req.query;
      const limit = parseInt(req.query.limit) || 20;

      const users = await userService.searchUsers(query, limit);

      res.json({
        users,
        query,
        totalResults: users.length
      });

    } catch (error) {
      logger.error('❌ Failed to search users:', error.message);
      res.status(500).json({
        error: 'Failed to search users',
        code: 'USER_SEARCH_ERROR'
      });
    }
  }
);

/**
 * Get building access statistics (admin/manager only)
 * GET /api/users/stats/building-access
 */
router.get('/stats/building-access',
  authMiddleware.requireRole(['admin', 'manager']),
  [
    query('timeframe').optional().isIn(['hour', 'day', 'week', 'month']).withMessage('Invalid timeframe')
  ],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          error: 'Validation failed',
          code: 'VALIDATION_ERROR',
          details: errors.array()
        });
      }

      const timeframe = req.query.timeframe || 'day';
      const stats = await userService.getBuildingAccessStats(timeframe);

      res.json({
        stats,
        timeframe,
        timestamp: new Date().toISOString()
      });

    } catch (error) {
      logger.error('❌ Failed to get building access stats:', error.message);
      res.status(500).json({
        error: 'Failed to get building access statistics',
        code: 'STATS_ERROR'
      });
    }
  }
);

module.exports = router;