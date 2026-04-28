const router = require('express').Router();
const mongoose = require('mongoose');
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const Notice = require('../models/Notice');
const Registration = require('../models/Registration');
const User = require('../models/User');
const Bus = require('../models/Bus');
const auth = require('../middleware/auth');

const uploadDir = path.join(__dirname, '..', 'uploads', 'notices');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadDir),
  filename: (_req, file, cb) => {
    const safeName = file.originalname.replace(/[^a-zA-Z0-9._-]/g, '_');
    cb(null, `${Date.now()}-${safeName}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    const allowedMime = ['application/pdf', 'image/png', 'image/jpeg', 'image/jpg', 'image/webp', 'application/octet-stream'];
    const allowedExt = ['.pdf', '.png', '.jpg', '.jpeg', '.webp'];
    const ext = path.extname(file.originalname || '').toLowerCase();

    if (allowedMime.includes(file.mimetype) && allowedExt.includes(ext)) return cb(null, true);
    if (allowedExt.includes(ext)) return cb(null, true);

    cb(new Error('Only PDF, PNG, JPG, JPEG, and WEBP files are allowed'));
  },
});

const uploadSingleAttachment = (req, res, next) => {
  upload.single('attachment')(req, res, (err) => {
    if (!err) return next();

    if (err instanceof multer.MulterError) {
      if (err.code === 'LIMIT_FILE_SIZE') {
        return res.status(400).json({ message: 'Attachment size must be <= 10MB' });
      }
      return res.status(400).json({ message: err.message });
    }

    return res.status(400).json({ message: err.message || 'Attachment upload failed' });
  });
};

const isValidObjectId = (id) => mongoose.Types.ObjectId.isValid(id);

const normalizeRouteIds = (routeIds = []) => {
  if (!Array.isArray(routeIds)) return [];
  return routeIds.filter((id) => isValidObjectId(id));
};

const parseRouteIds = (value) => {
  if (!value) return [];
  if (Array.isArray(value)) return normalizeRouteIds(value);

  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (!trimmed) return [];

    try {
      const parsed = JSON.parse(trimmed);
      if (Array.isArray(parsed)) return normalizeRouteIds(parsed);
    } catch (_) {
      return normalizeRouteIds(trimmed.split(',').map((v) => v.trim()).filter(Boolean));
    }
  }

  return [];
};

const parseExpiresAt = (expiresAt) => {
  if (!expiresAt) return null;

  if (typeof expiresAt === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(expiresAt.trim())) {
    const [year, month, day] = expiresAt.split('-').map(Number);
    return new Date(year, month - 1, day, 23, 59, 59, 999);
  }

  const parsed = new Date(expiresAt);
  if (Number.isNaN(parsed.getTime())) return null;
  return parsed;
};

const buildAttachmentUrl = (req, file) => {
  if (!file) return '';
  return `${req.protocol}://${req.get('host')}/uploads/notices/${file.filename}`;
};

const getRoleAudienceFilter = (role) => {
  if (role === 'parent') return { $in: ['all', 'parents'] };
  if (role === 'driver') return { $in: ['all', 'drivers'] };
  return { $in: ['all', 'parents', 'drivers'] };
};

const getParentRouteIds = async (parentId) => {
  return Registration.distinct('routeId', {
    parentId,
    status: 'approved',
    routeId: { $ne: null },
  });
};

const getDriverRouteIds = async (driverUserId) => {
  const user = await User.findById(driverUserId).select('busId');
  if (!user?.busId) return [];

  const bus = await Bus.findById(user.busId).select('routeId');
  if (!bus?.routeId) return [];

  return [bus.routeId];
};

// List notices based on role and route assignment.
router.get('/', auth, async (req, res) => {
  try {
    const includeExpired = req.query.includeExpired === 'true';
    const now = new Date();

    const filter = {
      isActive: true,
      audience: getRoleAudienceFilter(req.user.role),
    };

    if (!includeExpired) {
      filter.$or = [{ expiresAt: null }, { expiresAt: { $gte: now } }];
    }

    let notices = await Notice.find(filter)
      .populate('publishedBy', 'name role')
      .populate('routeIds', 'routeName routeCode')
      .sort({ createdAt: -1 });

    if (req.user.role === 'parent' || req.user.role === 'driver') {
      const routeIds = req.user.role === 'parent'
        ? await getParentRouteIds(req.user.id)
        : await getDriverRouteIds(req.user.id);

      const allowedRouteIds = routeIds.map((id) => id.toString());

      notices = notices.filter((notice) => {
        if (!notice.routeIds || notice.routeIds.length === 0) return true;
        return notice.routeIds.some((route) => allowedRouteIds.includes(route._id.toString()));
      });
    }

    res.json(notices);
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

// Create notice (admin only).
router.post('/', auth, auth.adminOnly, uploadSingleAttachment, async (req, res) => {
  try {
    const {
      title,
      message,
      audience = 'all',
      priority = 'normal',
      attachmentUrl = '',
      expiresAt = null,
    } = req.body;

    if (!title?.trim() || !message?.trim()) {
      return res.status(400).json({ message: 'Title and message are required' });
    }

    const payload = {
      title: title.trim(),
      message: message.trim(),
      audience,
      priority,
      attachmentUrl: buildAttachmentUrl(req, req.file) || attachmentUrl?.trim?.() || '',
      routeIds: parseRouteIds(req.body.routeIds),
      publishedBy: req.user.id,
      isActive: true,
    };

    if (expiresAt) {
      const parsed = parseExpiresAt(expiresAt);
      if (!parsed) {
        return res.status(400).json({ message: 'Invalid expiry date' });
      }
      payload.expiresAt = parsed;
    }

    const notice = await Notice.create(payload);
    const populated = await Notice.findById(notice._id)
      .populate('publishedBy', 'name role')
      .populate('routeIds', 'routeName routeCode');

    res.status(201).json(populated);
  } catch (e) {
    res.status(400).json({ message: e.message });
  }
});

// Update notice (admin only).
router.put('/:id', auth, auth.adminOnly, uploadSingleAttachment, async (req, res) => {
  try {
    const {
      title,
      message,
      audience,
      priority,
      attachmentUrl,
      expiresAt,
      isActive,
    } = req.body;

    const update = {};

    if (typeof title === 'string') update.title = title.trim();
    if (typeof message === 'string') update.message = message.trim();
    if (typeof audience === 'string') update.audience = audience;
    if (typeof priority === 'string') update.priority = priority;
    if (req.file) update.attachmentUrl = buildAttachmentUrl(req, req.file);
    if (!req.file && typeof attachmentUrl === 'string') update.attachmentUrl = attachmentUrl.trim();
    if (typeof req.body.routeIds !== 'undefined') update.routeIds = parseRouteIds(req.body.routeIds);
    if (typeof isActive === 'boolean') update.isActive = isActive;

    if (typeof expiresAt !== 'undefined') {
      if (!expiresAt) {
        update.expiresAt = null;
      } else {
        const parsed = parseExpiresAt(expiresAt);
        if (!parsed) {
          return res.status(400).json({ message: 'Invalid expiry date' });
        }
        update.expiresAt = parsed;
      }
    }

    const notice = await Notice.findByIdAndUpdate(req.params.id, update, { new: true })
      .populate('publishedBy', 'name role')
      .populate('routeIds', 'routeName routeCode');

    if (!notice) return res.status(404).json({ message: 'Notice not found' });
    res.json(notice);
  } catch (e) {
    res.status(400).json({ message: e.message });
  }
});

// Delete notice (admin only).
router.delete('/:id', auth, auth.adminOnly, async (req, res) => {
  try {
    const deleted = await Notice.findByIdAndDelete(req.params.id);
    if (!deleted) return res.status(404).json({ message: 'Notice not found' });
    res.json({ message: 'Notice deleted' });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

module.exports = router;
