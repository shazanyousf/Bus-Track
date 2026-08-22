const mongoose = require('mongoose');

const routeSchema = new mongoose.Schema({
  routeName: { type: String, required: true },
  routeCode: { type: String, required: true, unique: true },
  stops: [{ name: { type: String, required: true }, order: Number, monthlyFee: { type: Number, required: true, min: 0 } }],
  description: { type: String, default: '' }
}, { timestamps: true });

module.exports = mongoose.model('Route', routeSchema);
