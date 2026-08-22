const mongoose = require('mongoose');

const monthlyPaymentSchema = new mongoose.Schema({
  registrationId: { type: mongoose.Schema.Types.ObjectId, ref: 'Registration', required: true },
  parentId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  billingMonth: { type: String, required: true, match: /^\d{4}-\d{2}$/ },
  amount: { type: Number, required: true, min: 0 },
  status: { type: String, enum: ['DUE', 'PAID', 'OVERDUE'], default: 'DUE' },
  razorpayOrderId: { type: String, default: null },
  razorpayPaymentId: { type: String, default: null },
  razorpaySignature: { type: String, default: null },
  paidAt: { type: Date, default: null },
  dueAt: { type: Date, required: true },
}, { timestamps: true });

monthlyPaymentSchema.index({ registrationId: 1, billingMonth: 1 }, { unique: true });

module.exports = mongoose.model('MonthlyPayment', monthlyPaymentSchema);
