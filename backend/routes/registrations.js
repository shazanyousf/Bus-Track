const router = require('express').Router();
const Registration = require('../models/Registration');
const Student = require('../models/Student');
const Bus = require('../models/Bus');
const auth = require('../middleware/auth');
const crypto = require('crypto');
const Razorpay = require('razorpay');

const PAYMENT_AMOUNT = 150000;
const razorpay = new Razorpay({
  key_id: process.env.RAZORPAY_KEY_ID,
  key_secret: process.env.RAZORPAY_KEY_SECRET,
});

// Get registrations
router.get('/', auth, async (req, res) => {
  try {
    const filter = req.user.role === 'parent' ? { parentId: req.user.id } : {};
    const regs = await Registration.find(filter)
      .populate('studentId')
      .populate({
        path: 'busId',
        populate: [{ path: 'driverId' }, { path: 'routeId' }],
      })
      .populate('routeId')
      .populate('parentId', 'name email');
    res.json(regs);
  } catch (e) { res.status(500).json({ message: e.message }); }
});

// Submit registration request
router.post('/', auth, async (req, res) => {
  try {
    const bus = await Bus.findById(req.body.busId);
    if (!bus) return res.status(404).json({ message: 'Bus not found' });
    if (bus.availableSeats <= 0) return res.status(400).json({ message: 'No seats available' });
    
    // Create or update the student record first
    const studentData = {
      name: req.body.studentData.name,
      studentId: req.body.studentData.studentId,
      class: req.body.studentData.class,
      phone: req.body.studentData.phone,
      parentId: req.user.id
    };

    let student = await Student.findOne({
      studentId: req.body.studentData.studentId,
      parentId: req.user.id
    });

    if (student) {
      student.name = studentData.name;
      student.class = studentData.class;
      student.phone = studentData.phone;
      await student.save();
    } else {
      student = await Student.create(studentData);
    }

    // Create registration with the student ID and optional selected stop
    const regData = {
      studentId: student._id,
      busId: null,
      routeId: req.body.routeId,
      parentId: req.user.id,
    };
    if (req.body.stop) {
      regData.stop = {
        name: req.body.stop.name,
        order: req.body.stop.order,
        latitude: req.body.stop.latitude,
        longitude: req.body.stop.longitude,
      };
    }

    const reg = await Registration.create(regData);
    
    // Populate the response
    const populated = await Registration.findById(reg._id)
  .populate('studentId')
  .populate({
    path: 'busId',
    populate: [{ path: 'driverId' }, { path: 'routeId' }],
  })
  .populate('routeId');
    res.status(201).json(populated);
  } catch (e) { res.status(400).json({ message: e.message }); }
});

// Approve / Reject (admin only)
router.put('/:id/status', auth, auth.adminOnly, async (req, res) => {
  try {
    const { status, remarks } = req.body;
    const reg = await Registration.findById(req.params.id)
      .populate('busId')
      .populate('studentId');
    if (!reg) return res.status(404).json({ message: 'Registration not found' });

    const previousStatus = reg.status;
    const assignedBus = reg.busId;
    if (status === 'cancelled' && assignedBus && previousStatus === 'active') {
      await Bus.findOneAndUpdate(
        { _id: assignedBus._id, availableSeats: { $lt: assignedBus.totalSeats } },
        { $inc: { availableSeats: 1 } },
      );
      reg.busId = null;
      reg.assignmentStatus = 'PENDING';
    }

    reg.status = status;
    if (status === 'approved') {
      reg.paymentStatus = 'PENDING';
      reg.assignmentStatus = 'PENDING';
      reg.paymentId = null;
      reg.paidAt = null;
      reg.busId = null;
    }
    reg.remarks = remarks || reg.remarks;
    reg.reviewedBy = req.user.id;
    reg.reviewedAt = new Date();
    await reg.save();

    req.app.get('io')?.emit('registration:updated', {
      registrationId: reg._id.toString(),
      parentId: reg.parentId.toString(),
      status: reg.status,
      studentName: reg.studentId?.name || 'Student',
    });

    const populated = await Registration.findById(reg._id)
      .populate('studentId')
      .populate({
        path: 'busId',
        populate: [{ path: 'driverId' }, { path: 'routeId' }],
      })
      .populate('routeId')
      .populate('parentId', 'name email');

    res.json(populated);
  } catch (e) { res.status(400).json({ message: e.message }); }
});

// Create a Razorpay test-mode order for an approved parent registration.
router.post('/:id/payment/order', auth, async (req, res) => {
  try {
    if (!process.env.RAZORPAY_KEY_ID || !process.env.RAZORPAY_KEY_SECRET) {
      return res.status(503).json({ message: 'Razorpay test keys are not configured' });
    }
    const registration = await Registration.findOne({
      _id: req.params.id, parentId: req.user.id, status: 'approved', paymentStatus: 'PENDING',
    });
    if (!registration) return res.status(400).json({ message: 'Registration is not ready for payment' });
    if (registration.razorpayOrderId) {
      return res.json({ orderId: registration.razorpayOrderId, amount: PAYMENT_AMOUNT, keyId: process.env.RAZORPAY_KEY_ID });
    }
    const order = await razorpay.orders.create({
      amount: PAYMENT_AMOUNT,
      currency: 'INR',
      receipt: `bustrack-${registration._id}`,
      notes: { registrationId: registration._id.toString() },
    });
    registration.razorpayOrderId = order.id;
    await registration.save();
    res.json({ orderId: order.id, amount: order.amount, keyId: process.env.RAZORPAY_KEY_ID });
  } catch (e) { res.status(400).json({ message: e.message }); }
});

// Verify Razorpay checkout output; only verified payments become PAID.
router.post('/:id/payment/verify', auth, async (req, res) => {
  try {
    const { razorpay_payment_id: paymentId, razorpay_order_id: orderId, razorpay_signature: signature } = req.body;
    const registration = await Registration.findOne({
      _id: req.params.id, parentId: req.user.id, status: 'approved', paymentStatus: 'PENDING', razorpayOrderId: orderId,
    });
    if (!registration) return res.status(400).json({ message: 'Payment order is invalid or already completed' });
    const expectedSignature = crypto
      .createHmac('sha256', process.env.RAZORPAY_KEY_SECRET)
      .update(`${orderId}|${paymentId}`)
      .digest('hex');
    const expectedBuffer = Buffer.from(expectedSignature);
    const actualBuffer = Buffer.from(signature || '');
    if (expectedBuffer.length !== actualBuffer.length || !crypto.timingSafeEqual(expectedBuffer, actualBuffer)) {
      return res.status(400).json({ message: 'Payment signature verification failed' });
    }
    registration.paymentStatus = 'PAID';
    registration.paymentAmount = PAYMENT_AMOUNT / 100;
    registration.paymentId = paymentId;
    registration.paidAt = new Date();
    registration.razorpayPaymentId = paymentId;
    registration.razorpaySignature = signature;
    await registration.save();
    const payload = { registrationId: registration._id.toString(), parentId: registration.parentId.toString(), paymentStatus: 'PAID', paymentId };
    req.app.get('io')?.emit('payment:received', payload);
    req.app.get('io')?.emit('registration:updated', { ...payload, status: registration.status, event: 'payment' });
    res.json(registration);
  } catch (e) { res.status(400).json({ message: e.message }); }
});

// Assign a bus after payment (admin only).
router.put('/:id/assignment', auth, auth.adminOnly, async (req, res) => {
  try {
    const { busId, routeId } = req.body;
    if (!busId) return res.status(400).json({ message: 'Bus is required' });
    const registration = await Registration.findById(req.params.id);
    if (!registration) return res.status(404).json({ message: 'Registration not found' });
    if (registration.paymentStatus !== 'PAID') {
      return res.status(400).json({ message: 'Payment is required before bus assignment' });
    }
    if (registration.assignmentStatus === 'ASSIGNED') {
      return res.status(409).json({ message: 'Bus is already assigned' });
    }

    const bus = await Bus.findOneAndUpdate(
      { _id: busId, availableSeats: { $gt: 0 } },
      { $inc: { availableSeats: -1 } },
      { new: true },
    );
    if (!bus) return res.status(400).json({ message: 'Bus not found or no seats available' });
    registration.busId = bus._id;
    if (routeId) registration.routeId = routeId;
    registration.assignmentStatus = 'ASSIGNED';
    registration.status = 'active';
    await registration.save();

    req.app.get('io')?.emit('registration:updated', {
      registrationId: registration._id.toString(),
      parentId: registration.parentId.toString(),
      status: registration.status,
      event: 'assignment',
    });
    const populated = await Registration.findById(registration._id)
      .populate('studentId')
      .populate({ path: 'busId', populate: [{ path: 'driverId' }, { path: 'routeId' }] })
      .populate('routeId')
      .populate('parentId', 'name email');
    res.json(populated);
  } catch (e) { res.status(400).json({ message: e.message }); }
});

module.exports = router;
