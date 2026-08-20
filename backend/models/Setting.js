const mongoose = require('mongoose');

const settingSchema = new mongoose.Schema({
  classes: [{ type: String }],
}, { timestamps: true });

module.exports = mongoose.model('Setting', settingSchema);
