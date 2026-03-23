const router = require('express').Router();
const Registration = require('../models/Registration');
const Student = require('../models/Student');
const Bus = require('../models/Bus');
const auth = require('../middleware/auth');

// Get registrations
router.get('/', auth, async (req, res) => {
  try {
    const filter = req.user.role === 'parent' ? { parentId: req.user.id } : {};
    const regs = await Registration.find(filter)
      .populate('studentId').populate('busId').populate('routeId').populate('parentId', 'name email');
    res.json(regs);
  } catch (e) { res.status(500).json({ message: e.message }); }
});

// Submit registration request
router.post('/', auth, async (req, res) => {
  try {
    const bus = await Bus.findById(req.body.busId);
    if (!bus) return res.status(404).json({ message: 'Bus not found' });
    if (bus.availableSeats <= 0) return res.status(400).json({ message: 'No seats available' });
    
    // Create student first
    const student = await Student.create({
      name: req.body.studentData.name,
      studentId: req.body.studentData.studentId,
      department: req.body.studentData.department,
      semester: req.body.studentData.semester,
      phone: req.body.studentData.phone,
      parentId: req.user.id
    });
    
    // Create registration with the student ID
    const reg = await Registration.create({
      studentId: student._id,
      busId: req.body.busId,
      routeId: req.body.routeId,
      parentId: req.user.id
    });
    
    // Populate the response
    const populated = await reg.populate('studentId').populate('busId').populate('routeId');
    res.status(201).json(populated);
  } catch (e) { res.status(400).json({ message: e.message }); }
});

// Approve / Reject (admin only)
router.put('/:id/status', auth, auth.adminOnly, async (req, res) => {
  try {
    const { status, remarks } = req.body;
    const reg = await Registration.findByIdAndUpdate(
      req.params.id,
      { status, remarks, reviewedBy: req.user.id, reviewedAt: new Date() },
      { new: true }
    ).populate('busId');

    // Decrease available seats on approval
    if (status === 'approved' && reg.busId) {
      await Bus.findByIdAndUpdate(reg.busId._id, { $inc: { availableSeats: -1 } });
    }
    res.json(reg);
  } catch (e) { res.status(400).json({ message: e.message }); }
});

module.exports = router;
