const mongoose = require('mongoose');

const registrationSchema = new mongoose.Schema({
  studentId:    { type: mongoose.Schema.Types.ObjectId, ref: 'Student', required: true },
  parentId:     { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  busId:        { type: mongoose.Schema.Types.ObjectId, ref: 'Bus', default: null },
  routeId:      { type: mongoose.Schema.Types.ObjectId, ref: 'Route', required: true },
  stop: {
    name: { type: String, default: '' },
    order: { type: Number, default: 0 },
    latitude: { type: Number, default: 0 },
    longitude: { type: Number, default: 0 },
  },
  status:       { type: String, enum: ['pending','approved','active','rejected','cancelled'], default: 'pending' },
  assignmentStatus: { type: String, enum: ['PENDING', 'ASSIGNED'], default: 'PENDING' },
  paymentStatus: { type: String, enum: ['PENDING', 'PAID'], default: 'PENDING' },
  paymentAmount: { type: Number, default: 1500 },
  paymentId:    { type: String, default: null },
  paidAt:       { type: Date, default: null },
  razorpayOrderId: { type: String, default: null },
  razorpayPaymentId: { type: String, default: null },
  razorpaySignature: { type: String, default: null },
  requestDate:  { type: Date, default: Date.now },
  reviewedBy:   { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
  reviewedAt:   { type: Date, default: null },
  remarks:      { type: String, default: '' }
}, { timestamps: true });

module.exports = mongoose.model('Registration', registrationSchema);
