const mongoose = require('mongoose');
const bcrypt   = require('bcryptjs');

const userSchema = new mongoose.Schema({
  name:     { type: String, required: true },
  email:    { type: String, required: true, unique: true, index: true },
  password: { type: String, required: true },
  role:     { type: String, enum: ['parent', 'admin', 'driver'], default: 'parent', index: true },
  phone:    { type: String, default: '' },
  busId:    { type: mongoose.Schema.Types.ObjectId, ref: 'Bus', default: null },
  emailVerified: { type: Boolean, default: false },
  emailVerificationCode: { type: String, default: null },
  emailVerificationExpiry: { type: Date, default: null },
  resetCode: { type: String, default: null },
  resetCodeExpiry: { type: Date, default: null }
}, { timestamps: true });

userSchema.pre('save', async function (next) {
  if (!this.isModified('password')) return next();
  this.password = await bcrypt.hash(this.password, 10);
  next();
});

userSchema.methods.comparePassword = function (password) {
  return bcrypt.compare(password, this.password);
};

module.exports = mongoose.model('User', userSchema);
