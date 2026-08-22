const router = require('express').Router();
const ExcelJS = require('exceljs');
const Registration = require('../models/Registration');
const MonthlyPayment = require('../models/MonthlyPayment');
const auth = require('../middleware/auth');

const csvValue = (value) => {
  const text = value == null ? '' : String(value);
  return `"${text.replace(/"/g, '""')}"`;
};

const getRegistrations = () => Registration.find()
      .sort({ requestDate: -1 })
      .populate('studentId', 'name studentId class')
      .populate('parentId', 'name email')
      .populate('busId', 'busNumber')
      .populate('routeId', 'name');

const reportHeaders = [
  'Request Date', 'Student ID', 'Student Name', 'Class', 'Parent Name',
  'Parent Email', 'Bus Number', 'Route', 'Stop', 'Status', 'Reviewed At', 'Remarks',
  'Payment Status', 'Payment Amount', 'Payment ID', 'Paid At', 'Assignment Status',
];

const reportRows = (registrations) => registrations.map((registration) => [
  registration.requestDate?.toISOString(),
  registration.studentId?.studentId,
  registration.studentId?.name,
  registration.studentId?.class,
  registration.parentId?.name,
  registration.parentId?.email,
  registration.busId?.busNumber,
  registration.routeId?.name,
  registration.stop?.name,
  registration.status,
  registration.reviewedAt?.toISOString(),
  registration.remarks,
  registration.paymentStatus,
  registration.paymentAmount,
  registration.paymentId,
  registration.paidAt?.toISOString(),
  registration.assignmentStatus,
]);

const getPaymentReportData = async () => {
  const registrations = await Registration.find({
    paymentStatus: { $in: ['PENDING', 'PAID'] },
  })
    .sort({ paidAt: -1, requestDate: -1 })
    .populate('studentId', 'name')
    .populate('parentId', 'name email')
    .populate('busId', 'busNumber')
    .populate('routeId', 'routeName');
  const headers = [
    'Student Name', 'Parent Name', 'Parent Email', 'Bus Number', 'Route',
    'Payment Amount', 'Payment Status', 'Razorpay Payment ID', 'Razorpay Order ID',
    'Payment Date/Time', 'Registration Status',
  ];
  const rows = registrations.map((registration) => [
    registration.studentId?.name,
    registration.parentId?.name,
    registration.parentId?.email,
    registration.busId?.busNumber,
    registration.routeId?.routeName,
    registration.paymentAmount,
    registration.paymentStatus,
    registration.razorpayPaymentId || registration.paymentId,
    registration.razorpayOrderId,
    registration.paidAt?.toISOString(),
    registration.status,
  ]);
  const monthlyPayments = await MonthlyPayment.find()
    .sort({ paidAt: -1, billingMonth: -1 })
    .populate('parentId', 'name email')
    .populate({ path: 'registrationId', populate: [{ path: 'studentId', select: 'name' }, { path: 'busId', select: 'busNumber' }, { path: 'routeId', select: 'routeName' }] });
  rows.push(...monthlyPayments.map((payment) => [
    payment.registrationId?.studentId?.name,
    payment.parentId?.name,
    payment.parentId?.email,
    payment.registrationId?.busId?.busNumber,
    payment.registrationId?.routeId?.routeName,
    payment.amount,
    payment.status,
    payment.razorpayPaymentId,
    payment.razorpayOrderId,
    payment.paidAt?.toISOString(),
    `Monthly ${payment.billingMonth}`,
  ]));
  const paidRows = rows.filter((row) => row[6] === 'PAID');
  return {
    headers,
    rows,
    summary: [
      ['Total payment records', rows.length],
      ['Successful / PAID payments', paidRows.length],
      ['Outstanding payments', rows.filter((row) => row[6] === 'PENDING' || row[6] === 'DUE' || row[6] === 'OVERDUE').length],
      ['Overdue payments', rows.filter((row) => row[6] === 'OVERDUE').length],
      ['Total amount collected', paidRows.reduce((total, row) => total + (Number(row[5]) || 0), 0)],
    ],
  };
};

router.get('/registrations.csv', auth, auth.adminOnly, async (req, res) => {
  try {
    const registrations = await getRegistrations();
    const rows = reportRows(registrations);
    const csv = [reportHeaders, ...rows]
      .map((row) => row.map(csvValue).join(','))
      .join('\n');

    res.set({
      'Content-Type': 'text/csv; charset=utf-8',
      'Content-Disposition': `attachment; filename="bustrack-registrations-${new Date().toISOString().slice(0, 10)}.csv"`,
    });
    res.send(`\ufeff${csv}\n`);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/registrations.xlsx', auth, auth.adminOnly, async (req, res) => {
  try {
    const registrations = await getRegistrations();
    const workbook = new ExcelJS.Workbook();
    const worksheet = workbook.addWorksheet('Registrations');
    worksheet.addRow(reportHeaders);
    reportRows(registrations).forEach((row) => worksheet.addRow(row));
    worksheet.getRow(1).font = { bold: true, color: { argb: 'FFFFFFFF' } };
    worksheet.getRow(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF16213E' } };
    worksheet.views = [{ state: 'frozen', ySplit: 1 }];
    worksheet.autoFilter = { from: 'A1', to: 'Q1' };
    worksheet.columns.forEach((column) => { column.width = 18; });
    worksheet.getColumn(3).width = 24;
    worksheet.getColumn(5).width = 24;
    worksheet.getColumn(6).width = 30;
    worksheet.getColumn(12).width = 32;

    res.set({
      'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'Content-Disposition': `attachment; filename="bustrack-registrations-${new Date().toISOString().slice(0, 10)}.xlsx"`,
    });
    await workbook.xlsx.write(res);
    res.end();
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/payments.csv', auth, auth.adminOnly, async (req, res) => {
  try {
    const report = await getPaymentReportData();
    const csv = [
      ['Payment Report'],
      ...report.summary,
      [],
      report.headers,
      ...report.rows,
    ].map((row) => row.map(csvValue).join(',')).join('\n');
    res.set({
      'Content-Type': 'text/csv; charset=utf-8',
      'Content-Disposition': `attachment; filename="bustrack-payments-${new Date().toISOString().slice(0, 10)}.csv"`,
    });
    res.send(`\ufeff${csv}\n`);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

router.get('/payments.xlsx', auth, auth.adminOnly, async (req, res) => {
  try {
    const report = await getPaymentReportData();
    const workbook = new ExcelJS.Workbook();
    const worksheet = workbook.addWorksheet('Payments');
    worksheet.addRow(['Payment Report']);
    report.summary.forEach((row) => worksheet.addRow(row));
    worksheet.addRow([]);
    worksheet.addRow(report.headers);
    report.rows.forEach((row) => worksheet.addRow(row));
    worksheet.mergeCells('A1:K1');
    worksheet.getCell('A1').font = { bold: true, size: 14, color: { argb: 'FFFFFFFF' } };
    worksheet.getCell('A1').fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF16213E' } };
    worksheet.getRow(7).font = { bold: true, color: { argb: 'FFFFFFFF' } };
    worksheet.getRow(7).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF16213E' } };
    worksheet.views = [{ state: 'frozen', ySplit: 7 }];
    worksheet.autoFilter = { from: 'A7', to: 'K7' };
    worksheet.columns.forEach((column) => { column.width = 20; });
    worksheet.getColumn(1).width = 24;
    worksheet.getColumn(2).width = 24;
    worksheet.getColumn(3).width = 30;
    worksheet.getColumn(8).width = 28;
    worksheet.getColumn(9).width = 28;
    worksheet.getColumn(10).width = 24;

    res.set({
      'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'Content-Disposition': `attachment; filename="bustrack-payments-${new Date().toISOString().slice(0, 10)}.xlsx"`,
    });
    await workbook.xlsx.write(res);
    res.end();
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;