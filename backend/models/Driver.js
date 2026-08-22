const mongoose = require('mongoose');

const driverSchema = new mongoose.Schema({
  userId:      { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null, unique: true, sparse: true, index: true },
  name:        { type: String, required: true },
  phone:       { type: String, required: true },
  email:       { type: String, default: '' },
  licenseNo:   { type: String, default: null, unique: true, sparse: true },
  experience:  { type: Number, default: 0 },
  rating:      { type: Number, default: 5.0 },
  photo:       { type: String, default: '' },
  status:      { type: String, enum: ['active','inactive'], default: 'active' }
}, { timestamps: true });

module.exports = mongoose.model('Driver', driverSchema);
