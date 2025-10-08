const express = require('express');
const { body, query, validationResult } = require('express-validator');

const userService = require('../services/userService');
const authMiddleware = require('../middleware/authMiddleware');
const logger = require('../utils/logger');

const router = express.Router();

// All building access routes require authentication
router.use(authMiddleware.verifyToken);

/**
 * Log building zone access
 * POST /api/building-access/log
 */
router.post('/log', [
  body('zoneId').notEmpty().withMessage('Zone ID is required'),
  body('accessType').isIn(['entry', 'exit']).withMessage('Access type must be entry or exit'),
  body('method').isIn(['biometric', 'card', 'emergency']).withMessage('Invalid access method'),
  body('deviceId').optional().trim(),
  body('biometricData').optional().isObject()
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
    const { zoneId, accessType, method, deviceId, biometricData } = req.body;

    // Log the access attempt
    const accessLog = {
      userId,
      zoneId,
      accessType,
      method,
      deviceId,
      timestamp: new Date(),
      ipAddress: req.ip,
      userAgent: req.get('User-Agent'),
      biometricData: biometricData ? {
        confidence: biometricData.confidence,
        verificationId: biometricData.verificationId
      } : null
    };

    // For now, we'll log this with the user service
    // In a real implementation, you'd have a dedicated access control service
    await userService.logUserAccess(userId, `building_access_${accessType}`, req.ip, {
      zoneId,
      method,
      deviceId,
      accessType,
      biometricData: accessLog.biometricData
    });

    logger.info(`🏢 Building access logged: ${accessType} to zone ${zoneId} by user ${userId} via ${method}`);

    res.json({
      message: 'Building access logged successfully',
      accessLog: {
        timestamp: accessLog.timestamp,
        zoneId: accessLog.zoneId,
        accessType: accessLog.accessType,
        method: accessLog.method
      }
    });

  } catch (error) {
    logger.error('❌ Failed to log building access:', error.message);
    res.status(500).json({
      error: 'Failed to log building access',
      code: 'ACCESS_LOG_ERROR'
    });
  }
});

/**
 * Get user's building access history
 * GET /api/building-access/history
 */
router.get('/history', [
  query('limit').optional().isInt({ min: 1, max: 100 }).withMessage('Limit must be between 1 and 100'),
  query('zoneId').optional().trim(),
  query('accessType').optional().isIn(['entry', 'exit']),
  query('from').optional().isISO8601().withMessage('Invalid from date'),
  query('to').optional().isISO8601().withMessage('Invalid to date')
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
    const { zoneId, accessType, from, to } = req.query;

    // Get access logs from user service
    let accessLogs = await userService.getUserAccessLogs(userId, limit);

    // Filter for building access events
    accessLogs = accessLogs.filter(log => 
      log.loginType.startsWith('building_access_') &&
      log.metadata
    );

    // Apply additional filters
    if (zoneId) {
      accessLogs = accessLogs.filter(log => log.metadata.zoneId === zoneId);
    }
    if (accessType) {
      accessLogs = accessLogs.filter(log => log.metadata.accessType === accessType);
    }
    if (from) {
      const fromDate = new Date(from);
      accessLogs = accessLogs.filter(log => log.timestamp >= fromDate);
    }
    if (to) {
      const toDate = new Date(to);
      accessLogs = accessLogs.filter(log => log.timestamp <= toDate);
    }

    // Format response
    const formattedLogs = accessLogs.map(log => ({
      id: log.id,
      zoneId: log.metadata.zoneId,
      accessType: log.metadata.accessType,
      method: log.metadata.method,
      deviceId: log.metadata.deviceId,
      timestamp: log.timestamp,
      biometricData: log.metadata.biometricData
    }));

    res.json({
      accessHistory: formattedLogs,
      pagination: {
        total: formattedLogs.length,
        limit
      }
    });

  } catch (error) {
    logger.error('❌ Failed to get access history:', error.message);
    res.status(500).json({
      error: 'Failed to get access history',
      code: 'ACCESS_HISTORY_ERROR'
    });
  }
});

/**
 * Check user's access permissions for a zone
 * GET /api/building-access/permissions/:zoneId
 */
router.get('/permissions/:zoneId', async (req, res) => {
  try {
    const { zoneId } = req.params;
    const userId = req.user.userId;
    const userAccessLevel = req.user.accessLevel;
    const userRole = req.user.role;

    // Zone access rules (this would typically come from a database)
    const zoneAccessRules = {
      'lobby': ['basic', 'standard', 'elevated', 'admin'],
      'office-general': ['standard', 'elevated', 'admin'],
      'office-private': ['elevated', 'admin'],
      'server-room': ['admin'],
      'maintenance': ['technician', 'admin'],
      'emergency-exit': ['basic', 'standard', 'elevated', 'admin']
    };

    const roleAccessRules = {
      'server-room': ['admin'],
      'maintenance': ['technician', 'admin'],
      'office-private': ['manager', 'admin']
    };

    // Check access based on access level
    const allowedLevels = zoneAccessRules[zoneId] || [];
    const hasLevelAccess = allowedLevels.includes(userAccessLevel);

    // Check access based on role
    const allowedRoles = roleAccessRules[zoneId] || [];
    const hasRoleAccess = allowedRoles.length === 0 || allowedRoles.includes(userRole);

    const hasAccess = hasLevelAccess && hasRoleAccess;

    // Get additional zone information
    const zoneInfo = {
      'lobby': { name: 'Main Lobby', requiresBiometric: false },
      'office-general': { name: 'General Office Area', requiresBiometric: false },
      'office-private': { name: 'Private Offices', requiresBiometric: true },
      'server-room': { name: 'Server Room', requiresBiometric: true },
      'maintenance': { name: 'Maintenance Area', requiresBiometric: false },
      'emergency-exit': { name: 'Emergency Exit', requiresBiometric: false }
    };

    const zone = zoneInfo[zoneId] || { name: 'Unknown Zone', requiresBiometric: false };

    logger.info(`🔍 Access permission check for user ${userId} to zone ${zoneId}: ${hasAccess ? 'GRANTED' : 'DENIED'}`);

    res.json({
      zoneId,
      zoneName: zone.name,
      hasAccess,
      requiresBiometric: zone.requiresBiometric,
      userAccessLevel,
      userRole,
      accessReason: hasAccess ? 'Access granted based on user permissions' : 'Insufficient permissions for this zone',
      restrictions: {
        requiredAccessLevels: allowedLevels,
        requiredRoles: allowedRoles.length > 0 ? allowedRoles : ['any']
      }
    });

  } catch (error) {
    logger.error('❌ Failed to check access permissions:', error.message);
    res.status(500).json({
      error: 'Failed to check access permissions',
      code: 'PERMISSION_CHECK_ERROR'
    });
  }
});

/**
 * Get all building zones (for UI purposes)
 * GET /api/building-access/zones
 */
router.get('/zones', async (req, res) => {
  try {
    const zones = [
      {
        id: 'lobby',
        name: 'Main Lobby',
        description: 'Building entrance and reception area',
        accessLevel: 'basic',
        requiresBiometric: false,
        isActive: true
      },
      {
        id: 'office-general',
        name: 'General Office Area',
        description: 'Open office workspace',
        accessLevel: 'standard',
        requiresBiometric: false,
        isActive: true
      },
      {
        id: 'office-private',
        name: 'Private Offices',
        description: 'Executive and private office areas',
        accessLevel: 'elevated',
        requiresBiometric: true,
        isActive: true
      },
      {
        id: 'server-room',
        name: 'Server Room',
        description: 'Critical IT infrastructure area',
        accessLevel: 'admin',
        requiresBiometric: true,
        isActive: true
      },
      {
        id: 'maintenance',
        name: 'Maintenance Area',
        description: 'Building maintenance and utilities',
        accessLevel: 'standard',
        requiresBiometric: false,
        isActive: true,
        roleRestriction: ['technician', 'admin']
      },
      {
        id: 'emergency-exit',
        name: 'Emergency Exit',
        description: 'Emergency evacuation routes',
        accessLevel: 'basic',
        requiresBiometric: false,
        isActive: true,
        alwaysAccessible: true
      }
    ];

    // Filter zones based on user's access level and role
    const userAccessLevel = req.user.accessLevel;
    const userRole = req.user.role;

    const accessLevelHierarchy = {
      'basic': 1,
      'standard': 2,
      'elevated': 3,
      'admin': 4
    };

    const userLevel = accessLevelHierarchy[userAccessLevel] || 0;

    const accessibleZones = zones.filter(zone => {
      const requiredLevel = accessLevelHierarchy[zone.accessLevel] || 0;
      const hasLevelAccess = userLevel >= requiredLevel;
      
      const hasRoleAccess = !zone.roleRestriction || 
                           zone.roleRestriction.includes(userRole);
      
      return zone.isActive && (hasLevelAccess && hasRoleAccess);
    });

    res.json({
      zones: accessibleZones,
      userAccessLevel,
      userRole,
      totalZones: zones.length,
      accessibleZones: accessibleZones.length
    });

  } catch (error) {
    logger.error('❌ Failed to get building zones:', error.message);
    res.status(500).json({
      error: 'Failed to get building zones',
      code: 'ZONES_ERROR'
    });
  }
});

/**
 * Get building access statistics (admin/manager only)
 * GET /api/building-access/stats
 */
router.get('/stats',
  authMiddleware.requireRole(['admin', 'manager']),
  [
    query('timeframe').optional().isIn(['hour', 'day', 'week', 'month']).withMessage('Invalid timeframe'),
    query('zoneId').optional().trim()
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
      const { zoneId } = req.query;

      // Get building access statistics
      const stats = await userService.getBuildingAccessStats(timeframe);

      // This is a simplified version - in production you'd have more detailed analytics
      const buildingStats = {
        ...stats,
        topZones: [
          { zoneId: 'lobby', accesses: Math.floor(stats.totalAccess * 0.4) },
          { zoneId: 'office-general', accesses: Math.floor(stats.totalAccess * 0.3) },
          { zoneId: 'office-private', accesses: Math.floor(stats.totalAccess * 0.2) },
          { zoneId: 'server-room', accesses: Math.floor(stats.totalAccess * 0.1) }
        ],
        securityAlerts: 0, // Placeholder for security alerts
        emergencyExits: 0, // Placeholder for emergency exit usage
        peakHours: stats.accessByHour.indexOf(Math.max(...stats.accessByHour))
      };

      res.json({
        stats: buildingStats,
        timeframe,
        zoneFilter: zoneId || 'all',
        timestamp: new Date().toISOString()
      });

    } catch (error) {
      logger.error('❌ Failed to get building access stats:', error.message);
      res.status(500).json({
        error: 'Failed to get building access statistics',
        code: 'BUILDING_STATS_ERROR'
      });
    }
  }
);

module.exports = router;