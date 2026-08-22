const router = require('express').Router();
const Registration = require('../models/Registration');
const Student = require('../models/Student');
const Bus = require('../models/Bus');
const Route = require('../models/Route');
const auth = require('../middleware/auth');
const crypto = require('crypto');
const Razorpay = require('razorpay');
const MonthlyPayment = require('../models/MonthlyPayment');

const razorpay = new Razorpay({
  key_id: process.env.RAZORPAY_KEY_ID,
  key_secret: process.env.RAZORPAY_KEY_SECRET,
});

const monthKey = (date = new Date()) => `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
const nextMonth = (month) => {
  const [year, value] = month.split('-').map(Number);
  return monthKey(new Date(year, value, 1));
};

const ensureMonthlyPayment = async (registration, billingMonth) => {
  const amount = Number(registration.stop?.monthlyFee || registration.paymentAmount || 0);
  if (amount <= 0) return null;
  return MonthlyPayment.findOneAndUpdate(
    { registrationId: registration._id, billingMonth },
    {
      $setOnInsert: {
        registrationId: registration._id,
        parentId: registration.parentId,
        billingMonth,
        amount,
        dueAt: new Date(`${billingMonth}-10T23:59:59.999Z`),
        status: 'DUE',
      },
    },
    { upsert: true, new: true },
  );
};

const getBillingMonth = async () => {
  const Setting = require('../models/Setting');
  const currentMonth = monthKey();
  if (process.env.NODE_ENV === 'production') return currentMonth;
  const setting = await Setting.findOneAndUpdate({}, { $setOnInsert: { billingMonth: monthKey() } }, { upsert: true, new: true });
  if (!setting.billingMonth || setting.billingMonth < currentMonth) {
    setting.billingMonth = currentMonth;
    await setting.save();
  }
  return setting.billingMonth;
};

const syncMonthlyPayments = async (billingMonth) => {
  const registrations = await Registration.find({ status: 'active', assignmentStatus: 'ASSIGNED' }).lean();
  await Promise.all(registrations.map(async (registration) => {
    const payment = await ensureMonthlyPayment(registration, billingMonth);
    if (payment && registration.paymentStatus === 'PAID' && registration.paidAt &&
        monthKey(new Date(registration.paidAt)) === billingMonth && payment.status !== 'PAID') {
      await MonthlyPayment.updateOne(
        { _id: payment._id, status: { $in: ['DUE', 'OVERDUE'] } },
        { $set: { status: 'PAID', paidAt: registration.paidAt, razorpayPaymentId: registration.razorpayPaymentId || registration.paymentId } },
      );
    }
  }));
  await MonthlyPayment.updateMany({ billingMonth, status: 'DUE', dueAt: { $lt: new Date() } }, { $set: { status: 'OVERDUE' } });
  await MonthlyPayment.updateMany({ billingMonth: { $lt: billingMonth }, status: 'DUE' }, { $set: { status: 'OVERDUE' } });
};

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

router.get('/monthly-payments', auth, async (req, res) => {
  try {
    const billingMonth = await getBillingMonth();
    await syncMonthlyPayments(billingMonth);
    const filter = req.user.role === 'parent' ? { parentId: req.user.id } : {};
    res.json(await MonthlyPayment.find(filter).populate({ path: 'registrationId', populate: [{ path: 'busId', populate: { path: 'routeId' } }, { path: 'routeId' }] }).sort({ billingMonth: -1 }));
  } catch (e) { res.status(500).json({ message: e.message }); }
});

router.post('/monthly-payments/advance', auth, auth.adminOnly, async (req, res) => {
  if (process.env.NODE_ENV === 'production') return res.status(404).json({ message: 'Not available in production' });
  try {
    const Setting = require('../models/Setting');
    const current = await getBillingMonth();
    const billingMonth = nextMonth(current);
    await Setting.findOneAndUpdate({}, { billingMonth }, { upsert: true, new: true });
    await syncMonthlyPayments(billingMonth);
    res.json({ billingMonth });
  } catch (e) { res.status(400).json({ message: e.message }); }
});

router.post('/:id/monthly-payment/reset', auth, auth.adminOnly, async (req, res) => {
  if (process.env.NODE_ENV === 'production') return res.status(404).json({ message: 'Not available in production' });
  try {
    const registration = await Registration.findById(req.params.id).lean();
    if (!registration) return res.status(404).json({ message: 'Registration not found' });
    const billingMonth = req.body.billingMonth || await getBillingMonth();
    const amount = Number(registration.stop?.monthlyFee || registration.paymentAmount || 0);
    if (amount <= 0) return res.status(400).json({ message: 'Registration has no configured stop fee' });
    const payment = await MonthlyPayment.findOneAndUpdate(
      { registrationId: registration._id, billingMonth },
      {
        $set: {
          parentId: registration.parentId,
          amount,
          status: 'DUE',
          dueAt: new Date(`${nextMonth(billingMonth)}-10T23:59:59.999Z`),
          razorpayOrderId: null,
          razorpayPaymentId: null,
          razorpaySignature: null,
          paidAt: null,
        },
        $setOnInsert: { registrationId: registration._id, billingMonth },
      },
      { upsert: true, new: true, runValidators: true },
    );
    res.json({ registrationId: registration._id, billingMonth, status: payment.status, amount: payment.amount });
  } catch (e) { res.status(400).json({ message: e.message }); }
});

// Submit registration request
router.post('/', auth, async (req, res) => {
  let reservedBusId = null;
  try {
    const bus = await Bus.findById(req.body.busId);
    if (!bus) return res.status(404).json({ message: 'Bus not found' });
    if (bus.availableSeats <= 0) return res.status(400).json({ message: 'This bus is full. Please select another bus.' });
    const route = await Route.findById(req.body.routeId).lean();
    if (!route) return res.status(404).json({ message: 'Route not found' });
    const requestedStop = req.body.stop;
    const selectedStop = route.stops.find((stop) =>
      requestedStop && ((requestedStop.order != null && stop.order === requestedStop.order) ||
        (requestedStop.name && stop.name === requestedStop.name)));
    if (!selectedStop) return res.status(400).json({ message: 'Please select a valid pickup stop' });
    
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

    const existingRegistration = await Registration.findOne({
      studentId: student._id,
      parentId: req.user.id,
      status: { $in: ['pending', 'approved', 'active'] },
    }).select('_id status');
    if (existingRegistration) {
      return res.status(409).json({ message: 'This student already has an active registration request' });
    }

    const reservedBus = await Bus.findOneAndUpdate(
      { _id: bus._id, availableSeats: { $gt: 0 } },
      { $inc: { availableSeats: -1 } },
      { new: true },
    );
    if (!reservedBus) return res.status(400).json({ message: 'This bus is full. Please select another bus.' });
    reservedBusId = reservedBus._id;

    // Create registration with the student ID and optional selected stop
    const regData = {
      studentId: student._id,
      busId: reservedBus._id,
      routeId: req.body.routeId,
      parentId: req.user.id,
    };
    regData.stop = { name: selectedStop.name, order: selectedStop.order, monthlyFee: selectedStop.monthlyFee };
    regData.paymentAmount = selectedStop.monthlyFee;
    regData.seatReserved = true;

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
  } catch (e) {
    if (reservedBusId) await Bus.findByIdAndUpdate(reservedBusId, { $inc: { availableSeats: 1 } }).catch(() => null);
    res.status(400).json({ message: e.message });
  }
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
    if ((status === 'rejected' || status === 'cancelled') && reg.seatReserved && assignedBus) {
      await Bus.findByIdAndUpdate(assignedBus._id, { $inc: { availableSeats: 1 } });
      reg.seatReserved = false;
    }
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

router.put('/:id/remove-bus', auth, auth.adminOnly, async (req, res) => {
  try {
    const registration = await Registration.findOne({ _id: req.params.id, status: 'active', assignmentStatus: 'ASSIGNED' });
    if (!registration || !registration.busId) return res.status(400).json({ message: 'No active bus assignment found' });
    const busId = registration.busId;
    const bus = await Bus.findOneAndUpdate(
      { _id: busId, $expr: { $lt: ['$availableSeats', '$totalSeats'] } },
      { $inc: { availableSeats: 1 } },
      { new: true },
    );
    if (!bus) return res.status(404).json({ message: 'Assigned bus not found' });
    registration.busId = null;
    registration.assignmentStatus = 'PENDING';
    registration.status = 'approved';
    registration.seatReserved = false;
    await registration.save();
    req.app.get('io')?.emit('registration:updated', {
      registrationId: registration._id.toString(),
      parentId: registration.parentId.toString(),
      status: registration.status,
      event: 'bus-removed',
    });
    res.json({ registration, busAvailableSeats: bus.availableSeats });
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
      return res.json({ orderId: registration.razorpayOrderId, amount: Math.round(registration.paymentAmount * 100), keyId: process.env.RAZORPAY_KEY_ID });
    }
    if (!Number.isFinite(registration.paymentAmount) || registration.paymentAmount <= 0) {
      return res.status(400).json({ message: 'Registration has no configured stop fee' });
    }
    const order = await razorpay.orders.create({
      amount: Math.round(registration.paymentAmount * 100),
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
    registration.paymentId = paymentId;
    registration.paidAt = new Date();
    registration.razorpayPaymentId = paymentId;
    registration.razorpaySignature = signature;
    if (!registration.busId) return res.status(400).json({ message: 'No bus is associated with this registration' });
    if (!registration.seatReserved) {
      const assignedBus = await Bus.findOneAndUpdate(
        { _id: registration.busId, availableSeats: { $gt: 0 } },
        { $inc: { availableSeats: -1 } },
        { new: true },
      );
      if (!assignedBus) return res.status(400).json({ message: 'This bus is full. Please contact the school.' });
    }
    registration.seatReserved = false;
    registration.assignmentStatus = 'ASSIGNED';
    registration.status = 'active';
    await registration.save();
    const billingMonth = await getBillingMonth();
    await MonthlyPayment.findOneAndUpdate(
      { registrationId: registration._id, billingMonth },
      { $set: { amount: registration.stop.monthlyFee, status: 'PAID', paidAt: registration.paidAt, razorpayPaymentId: paymentId, razorpaySignature: signature } },
      { upsert: true, new: true, setDefaultsOnInsert: true },
    );
    const payload = { registrationId: registration._id.toString(), parentId: registration.parentId.toString(), paymentStatus: 'PAID', paymentId };
    req.app.get('io')?.emit('payment:received', payload);
    req.app.get('io')?.emit('registration:updated', { ...payload, status: registration.status, event: 'payment' });
    res.json(registration);
  } catch (e) { res.status(400).json({ message: e.message }); }
});

router.post('/monthly-payments/:paymentId/order', auth, async (req, res) => {
  try {
    if (!process.env.RAZORPAY_KEY_ID || !process.env.RAZORPAY_KEY_SECRET) return res.status(503).json({ message: 'Razorpay test keys are not configured' });
    const payment = await MonthlyPayment.findOne({ _id: req.params.paymentId, parentId: req.user.id, status: { $in: ['DUE', 'OVERDUE'] } });
    if (!payment) return res.status(400).json({ message: 'Monthly payment is not available' });
    if (payment.razorpayOrderId) return res.json({ orderId: payment.razorpayOrderId, amount: Math.round(payment.amount * 100), keyId: process.env.RAZORPAY_KEY_ID });
    const order = await razorpay.orders.create({ amount: Math.round(payment.amount * 100), currency: 'INR', receipt: `bustrack-monthly-${payment._id}`, notes: { paymentId: payment._id.toString(), billingMonth: payment.billingMonth } });
    payment.razorpayOrderId = order.id;
    await payment.save();
    res.json({ orderId: order.id, amount: order.amount, keyId: process.env.RAZORPAY_KEY_ID });
  } catch (e) { res.status(400).json({ message: e.message }); }
});

router.post('/monthly-payments/:paymentId/verify', auth, async (req, res) => {
  try {
    const { razorpay_payment_id: paymentId, razorpay_order_id: orderId, razorpay_signature: signature } = req.body;
    const payment = await MonthlyPayment.findOne({ _id: req.params.paymentId, parentId: req.user.id, status: { $in: ['DUE', 'OVERDUE'] }, razorpayOrderId: orderId });
    if (!payment) return res.status(400).json({ message: 'Monthly payment order is invalid' });
    const expected = crypto.createHmac('sha256', process.env.RAZORPAY_KEY_SECRET).update(`${orderId}|${paymentId}`).digest('hex');
    if (expected.length !== (signature || '').length || !crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(signature || ''))) return res.status(400).json({ message: 'Payment signature verification failed' });
    payment.status = 'PAID';
    payment.paidAt = new Date();
    payment.razorpayPaymentId = paymentId;
    payment.razorpaySignature = signature;
    await payment.save();
    req.app.get('io')?.emit('payment:received', { paymentId: payment._id.toString(), registrationId: payment.registrationId.toString(), parentId: payment.parentId.toString(), paymentStatus: 'PAID', billingMonth: payment.billingMonth });
    res.json(payment);
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

    if (registration.seatReserved && registration.busId?.toString() !== busId) {
      return res.status(400).json({ message: 'This registration already has a reserved bus' });
    }
    const bus = registration.seatReserved
      ? await Bus.findById(busId)
      : await Bus.findOneAndUpdate(
        { _id: busId, availableSeats: { $gt: 0 } },
        { $inc: { availableSeats: -1 } },
        { new: true },
      );
    if (!bus) return res.status(400).json({ message: 'Bus not found or no seats available' });
    registration.busId = bus._id;
    if (routeId) registration.routeId = routeId;
    registration.assignmentStatus = 'ASSIGNED';
    registration.seatReserved = false;
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
