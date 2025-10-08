const logger = require('../utils/logger');

/**
 * Global error handler middleware
 */
const errorHandler = (err, req, res, next) => {
  // Log the error
  logger.error('❌ Unhandled error:', {
    message: err.message,
    stack: err.stack,
    url: req.url,
    method: req.method,
    ip: req.ip,
    userAgent: req.get('User-Agent')
  });

  // Default error
  let error = {
    message: 'Internal server error',
    code: 'INTERNAL_ERROR',
    status: 500
  };

  // Handle specific error types
  if (err.name === 'ValidationError') {
    error = {
      message: 'Validation error',
      code: 'VALIDATION_ERROR',
      status: 400,
      details: err.errors
    };
  } else if (err.name === 'CastError') {
    error = {
      message: 'Invalid data format',
      code: 'INVALID_FORMAT',
      status: 400
    };
  } else if (err.name === 'MongoError' && err.code === 11000) {
    error = {
      message: 'Duplicate data detected',
      code: 'DUPLICATE_ERROR',
      status: 409
    };
  } else if (err.name === 'JsonWebTokenError') {
    error = {
      message: 'Invalid token',
      code: 'INVALID_TOKEN',
      status: 401
    };
  } else if (err.name === 'TokenExpiredError') {
    error = {
      message: 'Token expired',
      code: 'TOKEN_EXPIRED',
      status: 401
    };
  } else if (err.status || err.statusCode) {
    error = {
      message: err.message || 'Request failed',
      code: err.code || 'REQUEST_ERROR',
      status: err.status || err.statusCode
    };
  }

  // Send error response
  res.status(error.status).json({
    error: error.message,
    code: error.code,
    ...(error.details && { details: error.details }),
    ...(process.env.NODE_ENV === 'development' && { 
      stack: err.stack,
      originalError: err.message 
    })
  });
};

/**
 * 404 Not Found handler
 */
const notFoundHandler = (req, res) => {
  res.status(404).json({
    error: 'Endpoint not found',
    code: 'NOT_FOUND',
    path: req.originalUrl,
    method: req.method
  });
};

/**
 * Async error wrapper
 * Wraps async route handlers to catch errors
 */
const asyncHandler = (fn) => (req, res, next) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

module.exports = {
  errorHandler,
  notFoundHandler,
  asyncHandler
};