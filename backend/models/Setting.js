const mongoose = require('mongoose');

const settingSchema = new mongoose.Schema({
  classes: [{ type: String }],
  billingMonth: { type: String, default: null },
}, { timestamps: true });

module.exports = mongoose.model('Setting', settingSchema);
