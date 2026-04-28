const mongoose = require('mongoose');

const noticeSchema = new mongoose.Schema({
  title: {
    type: String,
    required: true,
    trim: true,
    maxlength: 120,
  },
  message: {
    type: String,
    required: true,
    trim: true,
    maxlength: 2000,
  },
  audience: {
    type: String,
    enum: ['all', 'parents', 'drivers'],
    default: 'all',
    index: true,
  },
  priority: {
    type: String,
    enum: ['normal', 'important'],
    default: 'normal',
  },
  attachmentUrl: {
    type: String,
    default: '',
    trim: true,
  },
  routeIds: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Route',
  }],
  expiresAt: {
    type: Date,
    default: null,
  },
  isActive: {
    type: Boolean,
    default: true,
    index: true,
  },
  publishedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
}, { timestamps: true });

module.exports = mongoose.model('Notice', noticeSchema);
