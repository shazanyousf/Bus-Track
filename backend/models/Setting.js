const mongoose = require('mongoose');

const settingSchema = new mongoose.Schema({
  departments: [{ type: String }],
  semesters:   [{ type: String }],
}, { timestamps: true });

module.exports = mongoose.model('Setting', settingSchema);
