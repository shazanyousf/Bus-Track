const mongoose = require('mongoose');

const routeSchema = new mongoose.Schema({
  routeName: { type: String, required: true },
  routeCode: { type: String, required: true, unique: true },
  stops: [{ name: String, order: Number, latitude: Number, longitude: Number }],
  description: { type: String, default: '' }
}, { timestamps: true });

module.exports = mongoose.model('Route', routeSchema);
