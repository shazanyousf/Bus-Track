const mongoose = require('mongoose');

const registrationSchema = new mongoose.Schema({
  studentId:    { type: mongoose.Schema.Types.ObjectId, ref: 'Student', required: true },
  parentId:     { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  busId:        { type: mongoose.Schema.Types.ObjectId, ref: 'Bus', required: true },
  routeId:      { type: mongoose.Schema.Types.ObjectId, ref: 'Route', required: true },
  stop: {
    name: { type: String, default: '' },
    order: { type: Number, default: 0 },
    latitude: { type: Number, default: 0 },
    longitude: { type: Number, default: 0 },
  },
  status:       { type: String, enum: ['pending','approved','rejected','cancelled'], default: 'pending' },
  requestDate:  { type: Date, default: Date.now },
  reviewedBy:   { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
  reviewedAt:   { type: Date, default: null },
  remarks:      { type: String, default: '' }
}, { timestamps: true });

module.exports = mongoose.model('Registration', registrationSchema);
