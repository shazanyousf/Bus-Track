const mongoose = require('mongoose');

const busSchema = new mongoose.Schema({
  busNumber:     { type: String, required: true, unique: true },
  routeId:       { type: mongoose.Schema.Types.ObjectId, ref: 'Route' },
  driverId:      { type: mongoose.Schema.Types.ObjectId, ref: 'Driver' },
  totalSeats:    { type: Number, required: true },
  availableSeats:{ type: Number, required: true },
  status:        { type: String, enum: ['active','inactive','maintenance'], default: 'active' },
  currentLocation: {
    latitude:  { type: Number, default: 0 },
    longitude: { type: Number, default: 0 }
  }
}, { timestamps: true });

module.exports = mongoose.model('Bus', busSchema);
