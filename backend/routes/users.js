const router = require('express').Router();
const User = require('../models/User');
const Driver = require('../models/Driver');
const auth = require('../middleware/auth');

const syncDriverForUser = async (user, previousRole) => {
  const wasDriver = previousRole === 'driver';
  if (user.role === 'driver') {
    let driver = await Driver.findOne({ userId: user._id });
    if (!driver && user.phone) driver = await Driver.findOne({ phone: user.phone, userId: null });
    if (driver) {
      driver.userId = user._id;
      driver.name = user.name;
      driver.phone = user.phone;
      driver.email = user.email;
      driver.status = 'active';
      await driver.save();
    } else {
      await Driver.create({
        userId: user._id,
        name: user.name,
        phone: user.phone,
        email: user.email,
        licenseNo: null,
        status: 'active',
      });
    }
  } else if (wasDriver) {
    const driver = await Driver.findOne({ userId: user._id });
    if (driver) {
      driver.status = 'inactive';
      await driver.save();
    }
  }
};

// List all users (admin only)
router.get('/', auth, auth.adminOnly, async (req, res) => {
  try {
    const users = await User.find().select('-password -verificationCode -resetCode');
    res.json(users);
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// Update user (admin only)
router.put('/:id([0-9a-fA-F]{24})', auth, auth.adminOnly, async (req, res) => {
  try {
    const allowed = ['name', 'email', 'phone', 'role', 'busId', 'emailVerified'];
    const update = {};
    for (const k of allowed) if (k in req.body) update[k] = req.body[k];
    const previousUser = await User.findById(req.params.id).select('name phone role');
    const user = await User.findByIdAndUpdate(req.params.id, update, { new: true }).select('-password -verificationCode -resetCode');
    if (!user) return res.status(404).json({ message: 'User not found' });
    await syncDriverForUser(user, previousUser?.role);
    req.app.get('io')?.emit('profile:updated', { userId: user._id.toString(), role: user.role });
    res.json(user);
  } catch (e) {
    res.status(400).json({ message: e.message });
  }
});

// Delete user (admin only)
router.delete('/:id([0-9a-fA-F]{24})', auth, auth.adminOnly, async (req, res) => {
  try {
    await User.findByIdAndDelete(req.params.id);
    res.json({ message: 'User deleted' });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// === Self-service endpoints ===
// Get current user's profile
router.get('/me', auth, async (req, res) => {
  try {
    const user = await User.findById(req.user.id).select('-password -verificationCode -resetCode');
    if (!user) return res.status(404).json({ message: 'User not found' });
    res.json(user);
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// Update current user (allow changing name, phone, email)
router.put('/me', auth, async (req, res) => {
  try {
    const allowed = ['name', 'email', 'phone'];
    const update = {};
    for (const k of allowed) if (k in req.body) update[k] = req.body[k];
    const previousUser = await User.findById(req.user.id).select('name phone role');
    const user = await User.findByIdAndUpdate(req.user.id, update, { new: true }).select('-password -verificationCode -resetCode');
    if (user?.role === 'driver' && previousUser?.phone) {
      await Driver.findOneAndUpdate(
        { $or: [{ userId: user._id }, { phone: previousUser.phone }] },
        { userId: user._id, name: user.name, phone: user.phone, email: user.email },
      );
    }
    req.app.get('io')?.emit('profile:updated', { userId: user._id.toString(), role: user.role });
    res.json(user);
  } catch (e) {
    res.status(400).json({ message: e.message });
  }
});

// Delete current user (self-delete)
router.delete('/me', auth, async (req, res) => {
  try {
    await User.findByIdAndDelete(req.user.id);
    res.json({ message: 'Account deleted' });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// Current user endpoints (authenticated)
// Note: kept here to reuse auth middleware; these routes allow users to manage their own account

module.exports = router;
