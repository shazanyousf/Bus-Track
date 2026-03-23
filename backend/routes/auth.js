const router = require('express').Router();
const jwt = require('jsonwebtoken');
const User = require('../models/User');

const sign = (user) => jwt.sign(
  { id: user._id, role: user.role, name: user.name },
  process.env.JWT_SECRET || 'bustrack_secret',
  { expiresIn: '7d' }
);

// Register
router.post('/register', async (req, res) => {
  try {
    const user = await User.create(req.body);
    res.status(201).json({ token: sign(user), user: { id: user._id, name: user.name, role: user.role } });
  } catch (e) {
    res.status(400).json({ message: e.message });
  }
});

// Login
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    const user = await User.findOne({ email });
    if (!user || !(await user.comparePassword(password)))
      return res.status(401).json({ message: 'Invalid credentials' });
    res.json({ token: sign(user), user: { id: user._id, name: user.name, role: user.role } });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// Forgot Password - Generate reset code
router.post('/forgot-password', async (req, res) => {
  try {
    const { email } = req.body;
    const user = await User.findOne({ email });
    if (!user) return res.status(404).json({ message: 'User not found' });
    
    // Generate 6-digit code
    const resetCode = Math.floor(100000 + Math.random() * 900000).toString();
    const resetCodeExpiry = new Date(Date.now() + 10 * 60000); // 10 minutes
    
    await User.findByIdAndUpdate(user._id, { resetCode, resetCodeExpiry });
    
    // In production, send this via email. For demo, return it directly.
    res.json({ message: 'Reset code sent to email', resetCode });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// Verify reset code
router.post('/verify-reset-code', async (req, res) => {
  try {
    const { email, resetCode } = req.body;
    const user = await User.findOne({ email });
    if (!user) return res.status(404).json({ message: 'User not found' });
    if (user.resetCode !== resetCode || new Date() > user.resetCodeExpiry)
      return res.status(400).json({ message: 'Invalid or expired reset code' });
    
    res.json({ message: 'Code verified' });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// Reset Password
router.post('/reset-password', async (req, res) => {
  try {
    const { email, resetCode, newPassword } = req.body;
    const user = await User.findOne({ email });
    if (!user) return res.status(404).json({ message: 'User not found' });
    if (user.resetCode !== resetCode || new Date() > user.resetCodeExpiry)
      return res.status(400).json({ message: 'Invalid or expired reset code' });
    
    user.password = newPassword;
    user.resetCode = null;
    user.resetCodeExpiry = null;
    await user.save();
    
    res.json({ message: 'Password reset successfully' });
  } catch (e) {
    res.status(400).json({ message: e.message });
  }
});

module.exports = router;
