const express = require('express');
const router = express.Router();

// Simple test route
router.get('/test', (req, res) => {
  res.json({ message: 'Biometric routes working!' });
});

// Simple enrollment route for testing
router.post('/enroll', (req, res) => {
  res.json({ message: 'Enrollment endpoint reached' });
});

module.exports = router;