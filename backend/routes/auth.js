const router = require('express').Router();
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const crypto = require('crypto');
const User = require('../models/User');
const auth = require('../middleware/auth');

const sign = (user) => jwt.sign(
  { id: user._id, role: user.role, name: user.name, sessionId: user.sessionId },
  process.env.JWT_SECRET || 'bustrack_secret',
  { expiresIn: '7d' }
);

const _sendEmail = async ({ to, subject, text, html }) => {
  if (!process.env.BREVO_API_KEY || !process.env.EMAIL_FROM) {
    return false;
  }

  const response = await fetch('https://api.brevo.com/v3/smtp/email', {
    method: 'POST',
    headers: {
      'api-key': process.env.BREVO_API_KEY,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      sender: { email: process.env.EMAIL_FROM, name: 'BusTrack' },
      to: [{ email: to }],
      subject,
      textContent: text,
      htmlContent: html,
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Brevo email failed (${response.status}): ${error}`);
  }

  return true;
};

const ensureDatabase = (res) => {
  if (mongoose.connection.readyState !== 1) {
    res.status(503).json({
      message: 'Database is not connected. Check MONGODB_URI and make sure MongoDB is running.',
    });
    return false;
  }

  return true;
};

// ✅ STEP 1: Register - Store pending OTP data ONLY (don't create user yet)
router.post('/register', async (req, res) => {
  try {
    if (!ensureDatabase(res)) return;

    const { name, email, password, phone } = req.body;
    
    // Validate input
    if (!name || !email || !password) {
      return res.status(400).json({ message: 'Name, email, and password are required' });
    }
    if (password.length < 6) {
      return res.status(400).json({ message: 'Password must be at least 6 characters' });
    }

    const normalizedEmail = email.toLowerCase().trim();

    // Check if email is already registered in User collection
    const registeredUser = await User.findOne({ email: normalizedEmail, emailVerified: true }).select('_id').lean();
    if (registeredUser) {
      return res.status(400).json({ message: 'Email already registered' });
    }

    // Replace any existing pending registration for this email
    await User.deleteOne({ email: normalizedEmail, emailVerified: false });

    // Generate verification code
    const verificationCode = Math.floor(100000 + Math.random() * 900000).toString();
    const verificationExpiry = new Date(Date.now() + 10 * 60000); // 10 minutes

    const pending = await User.create({
      name: name.trim(),
      email: normalizedEmail,
      password,
      phone: (phone || '').trim(),
      role: 'parent',
      emailVerified: false,
      verificationCode,
      verificationExpiry,
      verificationAttempts: 0,
    });

    // Send OTP email
    const emailSent = await _sendEmail({
      to: pending.email,
      subject: 'BusTrack Email Verification Code',
      text: `Your BusTrack verification code is ${verificationCode}. It expires in 10 minutes.`,
      html: `<p>Your BusTrack verification code is <strong>${verificationCode}</strong>.</p><p>This code expires in 10 minutes.</p>`,
    });

    if (!emailSent && process.env.SHOW_RESET_CODE !== 'true') {
      await User.deleteOne({ _id: pending._id });
      return res.status(503).json({
        message: 'Verification email could not be sent. Check your Brevo API key and authorized sender address.',
      });
    }

    res.status(202).json({
      message: emailSent
        ? 'Verification code sent to email. Please enter it to complete registration.'
        : 'Email delivery is disabled for development. Use the verification code shown by the backend.',
      email: normalizedEmail,
      ...(process.env.SHOW_RESET_CODE === 'true' ? { verificationCode } : {}),
    });
  } catch (e) {
    res.status(500).json({ message: e.message || 'Registration failed' });
  }
});

// ✅ STEP 2: Verify Registration - Create actual user ONLY after OTP verification
router.post('/verify-registration', async (req, res) => {
  try {
    if (!ensureDatabase(res)) return;

    const { email, verificationCode } = req.body;
    
    if (!email || !verificationCode) {
      return res.status(400).json({ message: 'Email and verification code are required' });
    }

    const normalizedEmail = email.toLowerCase().trim();

    // Find pending registration
    const pending = await User.findOne({ email: normalizedEmail, emailVerified: false });
    if (!pending) {
      return res.status(404).json({ message: 'Registration request not found. Please register again.' });
    }
    
    // Check verification code
    if (pending.verificationCode !== verificationCode) {
      // Increment attempts
      pending.verificationAttempts = (pending.verificationAttempts || 0) + 1;
      if (pending.verificationAttempts > 5) {
        await User.deleteOne({ _id: pending._id });
        return res.status(429).json({ message: 'Too many failed attempts. Please register again.' });
      }
      await pending.save();
      return res.status(400).json({ message: 'Invalid verification code' });
    }
    
    // Check expiry
    if (new Date() > pending.verificationExpiry) {
      await User.deleteOne({ _id: pending._id });
      return res.status(400).json({ message: 'Verification code has expired. Please register again.' });
    }

    // ✅ Mark the pending user as verified
    try {
      pending.emailVerified = true;
      pending.verificationCode = null;
      pending.verificationExpiry = null;
      pending.verificationAttempts = 0;
      await pending.save();

      pending.sessionId = crypto.randomUUID();
      await pending.save();

      // Return token and user info
      res.json({ 
        token: sign(pending), 
        sessionId: pending.sessionId,
        user: { id: pending._id, name: pending.name, role: pending.role, email: pending.email } 
      });
    } catch (mongoErr) {
      // Handle duplicate key error (shouldn't happen, but just in case)
      if (mongoErr.code === 11000) {
        await User.deleteOne({ _id: pending._id });
        return res.status(400).json({ message: 'Email already registered' });
      }
      throw mongoErr;
    }
  } catch (e) {
    res.status(500).json({ message: e.message || 'Verification failed' });
  }
});

// Login - User MUST be verified (emailVerified: true)
router.post('/login', async (req, res) => {
  try {
    if (!ensureDatabase(res)) return;

    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ message: 'Email and password are required' });
    }
    const normalizedEmail = email.toLowerCase().trim();
    const user = await User.findOne({ email: normalizedEmail });
    if (!user) return res.status(401).json({ message: 'Invalid credentials' });
    
    // ✅ ENFORCE: User must have verified email to login
    if (user.emailVerified !== true) {
      return res.status(401).json({ message: 'Email not verified. Please complete registration and verify your email.' });
    }
    if (!(await user.comparePassword(password)))
      return res.status(401).json({ message: 'Invalid credentials' });

    const oldSessionId = user.sessionId;
    user.sessionId = crypto.randomUUID();
    await user.save();
    const savedUser = await User.findById(user._id).select('_id sessionId').lean();
    console.log(`[AUTH SESSION SAVED] userId=${savedUser?._id} sessionId=${savedUser?.sessionId}`);

    const activeSessions = req.app.get('activeSessions');
    const io = req.app.get('io');
    const userId = user._id.toString();
    const mappedSession = activeSessions?.get(userId);
    if (mappedSession) {
      console.log(`[ACTIVE SESSION BEFORE REPLACEMENT] userId=${userId} sessionId=${mappedSession.sessionId} socketId=${mappedSession.socketId}`);
    }
    const oldSocket = mappedSession?.sessionId === oldSessionId
      ? mappedSession.socket
      : [...(io?.sockets?.sockets?.values() || [])]
        .find((socket) => socket.user?.id?.toString() === userId && socket.user?.sessionId === oldSessionId);
    console.log(`[AUTH LOGIN] userId=${userId} role=${user.role} newSessionId=${user.sessionId}`);
    if (oldSocket) {
      console.log(`[OLD SESSION FOUND] userId=${userId} oldSessionId=${oldSocket.user?.sessionId || oldSessionId} oldSocketId=${oldSocket.id}`);
    }
    if (oldSocket) {
      console.log(`[SESSION REPLACED] userId=${userId} oldSessionId=${oldSessionId} newSessionId=${user.sessionId} oldSocketId=${oldSocket.id} newSocketId=pending`);
      oldSocket.emit('session:revoked', {
        userId,
        sessionId: oldSocket.user?.sessionId || oldSessionId,
        message: 'Your account was signed in on another device.',
      });
      console.log(`[SESSION REVOKE SENT] userId=${userId} sessionId=${oldSocket.user?.sessionId || oldSessionId} socketId=${oldSocket.id}`);
      setTimeout(() => oldSocket.disconnect(true), 100);
      if (activeSessions?.get(userId)?.socketId === oldSocket.id) activeSessions.delete(userId);
    }
    if (oldSessionId) console.log(`[SESSION ROTATED] userId=${user._id}`);

    res.json({ token: sign(user), sessionId: user.sessionId, user: { id: user._id, name: user.name, role: user.role } });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

router.post('/logout', auth, async (req, res) => {
  await User.findByIdAndUpdate(req.user.id, { $set: { sessionId: null } });
  const activeSessions = req.app.get('activeSessions');
  const session = activeSessions?.get(req.user.id.toString());
  if (session) {
    session.socket.disconnect(true);
    if (activeSessions.get(req.user.id.toString())?.socketId === session.socketId) {
      activeSessions.delete(req.user.id.toString());
    }
  }
  res.json({ message: 'Logged out' });
});

// Forgot Password - Generate reset code
router.post('/forgot-password', async (req, res) => {
  try {
    if (!ensureDatabase(res)) return;

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
    if (!ensureDatabase(res)) return;

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
    if (!ensureDatabase(res)) return;

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
