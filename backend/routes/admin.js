const router = require('express').Router();
const auth = require('../middleware/auth');
const Bus = require('../models/Bus');
const Driver = require('../models/Driver');
const Notice = require('../models/Notice');
const Student = require('../models/Student');
const Registration = require('../models/Registration');

router.get('/dashboard/stats', auth, auth.adminOnly, async (req, res) => {
  try {
    const [students, buses, drivers, registrations, notices] = await Promise.all([
      Student.countDocuments(),
      Bus.find({}, 'busNumber totalSeats availableSeats status driverId').lean(),
      Driver.countDocuments(),
      Registration.find()
        .populate('studentId', 'name')
        .populate('parentId', 'name')
        .populate('busId', 'busNumber')
        .lean(),
      Notice.find().sort({ createdAt: -1 }).limit(5).select('title createdAt priority').lean(),
    ]);

    const countStatus = (status) => registrations.filter((registration) => registration.status === status).length;
    const paidPayments = registrations.filter((registration) => registration.paymentStatus === 'PAID');
    const activeBuses = buses.filter((bus) => bus.status === 'active');
    const liveBuses = req.app.get('activeBuses') || {};
    const activities = [
      ...registrations.slice().sort((a, b) => new Date(b.updatedAt || b.createdAt) - new Date(a.updatedAt || a.createdAt)).slice(0, 10).map((registration) => ({
        type: registration.status === 'active' && registration.assignmentStatus === 'ASSIGNED'
          ? 'Bus assigned'
          : registration.paymentStatus === 'PAID'
              ? 'Payment received'
              : `Registration ${registration.status}`,
        detail: registration.studentId?.name || 'Student',
        date: registration.updatedAt || registration.createdAt,
      })),
      ...notices.map((notice) => ({
        type: 'Notice published',
        detail: notice.title,
        date: notice.createdAt,
      })),
    ].sort((a, b) => new Date(b.date) - new Date(a.date)).slice(0, 8);

    res.json({
      students,
      buses: buses.length,
      drivers,
      pendingRegistrations: countStatus('pending'),
      approvedRegistrations: countStatus('approved'),
      rejectedRegistrations: countStatus('rejected'),
      activeRegistrations: countStatus('active'),
      paidPayments: paidPayments.length,
      pendingPayments: registrations.filter((registration) => registration.paymentStatus === 'PENDING' && registration.status === 'approved').length,
      totalCollected: paidPayments.reduce((sum, registration) => sum + (Number(registration.paymentAmount) || 0), 0),
      activeBuses: activeBuses.length,
      inactiveBuses: buses.filter((bus) => bus.status !== 'active').length,
      trackingBuses: Object.keys(liveBuses).filter((busId) => buses.some((bus) => bus._id.toString() === busId)).length,
      busFleet: buses.map((bus) => ({
        busNumber: bus.busNumber,
        totalSeats: bus.totalSeats,
        availableSeats: bus.availableSeats,
        status: bus.status,
      })),
      activities,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;