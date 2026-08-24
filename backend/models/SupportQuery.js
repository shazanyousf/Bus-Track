const mongoose = require('mongoose');

const supportQuerySchema = new mongoose.Schema({
  parentId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  subject: { type: String, required: true, trim: true, maxlength: 120 },
  message: { type: String, required: true, trim: true, maxlength: 5000 },
  attachmentUrl: { type: String, default: '' },
  status: { type: String, enum: ['open', 'resolved'], default: 'open', index: true },
  adminResponse: { type: String, default: '', trim: true, maxlength: 5000 },
  respondedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
  respondedAt: { type: Date, default: null },
}, { timestamps: true });

module.exports = mongoose.model('SupportQuery', supportQuerySchema);