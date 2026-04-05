const router = require('express').Router();
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');
const User = require('../models/User');

const sign = (user) => jwt.sign(
  { id: user._id, role: user.role, name: user.name },
  process.env.JWT_SECRET || 'bustrack_secret',
  { expiresIn: '7d' }
);

const _sendEmail = async ({ to, subject, text, html }) => {
  if (!process.env.SMTP_HOST || !process.env.SMTP_USER || !process.env.SMTP_PASS) {
    return false;
  }

  const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: parseInt(process.env.SMTP_PORT || '587', 10),
    secure: process.env.SMTP_SECURE === 'true',
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS,
    },
  });

  await transporter.sendMail({
    from: process.env.EMAIL_FROM || process.env.SMTP_USER,
    to,
    subject,
    text,
    html,
  });
  return true;
};

// Register with email verification
router.post('/register', async (req, res) => {
  try {
    const { name, email, password, phone } = req.body;
    const existing = await User.findOne({ email });
    const verificationCode = Math.floor(100000 + Math.random() * 900000).toString();
    const verificationExpiry = new Date(Date.now() + 10 * 60000); // 10 minutes

    if (existing) {
      return res.status(400).json({ message: 'Email already registered' });
    }

    const user = await User.create({
      name,
      email,
      password,
      phone,
      role: 'parent',
      emailVerified: false,
      emailVerificationCode: verificationCode,
      emailVerificationExpiry: verificationExpiry,
    });

    await _sendEmail({
      to: user.email,
      subject: 'BusTrack Email Verification Code',
      text: `Your BusTrack verification code is ${verificationCode}. It expires in 10 minutes.`,
      html: `<p>Your BusTrack verification code is <strong>${verificationCode}</strong>.</p><p>This code expires in 10 minutes.</p>`,
    }).catch(() => false);

    res.status(202).json({ message: 'Verification code sent to email. Please enter it to complete registration.' });
  } catch (e) {
    res.status(400).json({ message: e.message });
  }
});

// Verify registration code
router.post('/verify-registration', async (req, res) => {
  try {
    const { email, verificationCode } = req.body;
    const user = await User.findOne({ email });
    if (!user) return res.status(404).json({ message: 'User not found' });
    if (user.emailVerified) return res.status(400).json({ message: 'Email already verified' });
    if (user.emailVerificationCode !== verificationCode || new Date() > user.emailVerificationExpiry)
      return res.status(400).json({ message: 'Invalid or expired verification code' });

    user.emailVerified = true;
    user.emailVerificationCode = null;
    user.emailVerificationExpiry = null;
    await user.save();

    res.json({ token: sign(user), user: { id: user._id, name: user.name, role: user.role } });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// Login
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    const user = await User.findOne({ email });
    if (!user) return res.status(401).json({ message: 'Invalid credentials' });
    if (user.emailVerified === false) return res.status(401).json({ message: 'Email not verified. Please check your inbox.' });
    if (!(await user.comparePassword(password)))
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

    const resetCode = Math.floor(100000 + Math.random() * 900000).toString();
    const resetCodeExpiry = new Date(Date.now() + 10 * 60000); // 10 minutes
    await User.findByIdAndUpdate(user._id, { resetCode, resetCodeExpiry });

    const emailSent = await _sendEmail({
      to: user.email,
      subject: 'BusTrack Password Reset Code',
      text: `Your BusTrack password reset code is ${resetCode}. It expires in 10 minutes.`,
      html: `<p>Your BusTrack password reset code is <strong>${resetCode}</strong>.</p><p>This code expires in 10 minutes.</p>`,
    }).catch(() => false);

    const message = emailSent
      ? 'Reset code sent to your registered email address.'
      : 'Reset code generated. Email sending is not configured on the server.';

    const response = { message };
    if (!emailSent && process.env.NODE_ENV !== 'production' && process.env.SHOW_RESET_CODE === 'true') {
      response.resetCode = resetCode;
    }

    res.json(response);
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
