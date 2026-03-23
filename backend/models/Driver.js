const mongoose = require('mongoose');

const driverSchema = new mongoose.Schema({
  name:        { type: String, required: true },
  phone:       { type: String, required: true },
  licenseNo:   { type: String, required: true, unique: true },
  experience:  { type: Number, default: 0 },
  rating:      { type: Number, default: 5.0 },
  photo:       { type: String, default: '' },
  status:      { type: String, enum: ['active','inactive'], default: 'active' }
}, { timestamps: true });

module.exports = mongoose.model('Driver', driverSchema);
