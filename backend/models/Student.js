const mongoose = require('mongoose');

const studentSchema = new mongoose.Schema({
  name:         { type: String, required: true },
  studentId:    { type: String, required: true, unique: true },
  department:   { type: String, required: true },
  semester:     { type: String, required: true },
  parentId:     { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  assignedBus:  { type: mongoose.Schema.Types.ObjectId, ref: 'Bus', default: null },
  seatNumber:   { type: Number, default: null },
  phone:        { type: String, default: '' }
}, { timestamps: true });

module.exports = mongoose.model('Student', studentSchema);
