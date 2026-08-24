const router = require('express').Router();
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const SupportQuery = require('../models/SupportQuery');
const auth = require('../middleware/auth');

const uploadDir = path.join(__dirname, '..', 'uploads', 'support');
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });

const upload = multer({
  storage: multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, uploadDir),
    filename: (_req, file, cb) => {
      const safeName = file.originalname.replace(/[^a-zA-Z0-9._-]/g, '_');
      cb(null, `${Date.now()}-${safeName}`);
    },
  }),
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

const uploadAttachment = (req, res, next) => upload.single('attachment')(req, res, (error) => {
  if (!error) return next();
  if (error instanceof multer.MulterError && error.code === 'LIMIT_FILE_SIZE') {
    return res.status(400).json({ message: 'Attachment size must be <= 10MB' });
  }
  return res.status(400).json({ message: error.message || 'Attachment upload failed' });
});

const attachmentUrl = (req, file) => file
  ? `${req.protocol}://${req.get('host')}/uploads/support/${file.filename}`
  : '';

const populateQuery = (query) => query
  .populate('parentId', 'name email')
  .populate('respondedBy', 'name')
  .sort({ createdAt: -1 });

router.get('/', auth, async (req, res) => {
  try {
    const filter = req.user.role === 'admin' ? {} : { parentId: req.user.id };
    res.json(await populateQuery(SupportQuery.find(filter)));
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.post('/', auth, uploadAttachment, async (req, res) => {
  try {
    if (req.user.role !== 'parent') return res.status(403).json({ message: 'Only parents can raise queries' });
    const subject = req.body.subject?.trim();
    const message = req.body.message?.trim();
    if (!subject || !message) return res.status(400).json({ message: 'Subject and message are required' });

    const query = await SupportQuery.create({
      parentId: req.user.id,
      subject,
      message,
      attachmentUrl: attachmentUrl(req, req.file),
    });
    res.status(201).json(await populateQuery(SupportQuery.findById(query._id)));
  } catch (error) {
    res.status(400).json({ message: error.message });
  }
});

router.put('/:id/reply', auth, async (req, res) => {
  try {
    if (req.user.role !== 'admin') return res.status(403).json({ message: 'Admin access required' });
    const response = req.body.response?.trim();
    if (!response) return res.status(400).json({ message: 'Response is required' });
    const query = await SupportQuery.findByIdAndUpdate(req.params.id, {
      adminResponse: response,
      status: req.body.status === 'open' ? 'open' : 'resolved',
      respondedBy: req.user.id,
      respondedAt: new Date(),
    }, { new: true, runValidators: true });
    if (!query) return res.status(404).json({ message: 'Query not found' });
    res.json(await populateQuery(SupportQuery.findById(query._id)));
  } catch (error) {
    res.status(400).json({ message: error.message });
  }
});

module.exports = router;