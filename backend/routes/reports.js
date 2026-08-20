const router = require('express').Router();
const ExcelJS = require('exceljs');
const Registration = require('../models/Registration');
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
]);

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
    worksheet.autoFilter = { from: 'A1', to: 'L1' };
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

module.exports = router;