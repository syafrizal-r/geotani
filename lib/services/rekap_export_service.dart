import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/models/absensi.dart';
import '../data/models/rekap_row.dart';

/// Menghasilkan file rekap absensi dalam bentuk PDF atau Excel (.xlsx) untuk
/// dibagikan oleh Koordinator Penyuluh / Kepala Dinas.
///
/// Tidak ada paket `excel` yang dipakai di sini: versi terbaru paket itu
/// terkunci ke `archive` versi 3.x, sedangkan paket `image` (dipakai untuk
/// face recognition) butuh `archive` versi 4.x. Karena kebutuhan tabelnya
/// sederhana (tanpa formula/style), file .xlsx dibangun manual sebagai
/// beberapa bagian XML minimal yang di-zip pakai `archive`.
class RekapExportService {
  static const _headers = [
    'No',
    'Nama PPL',
    'Agenda SPT',
    'Tipe',
    'Waktu',
    'Jarak (m)',
    'Kecocokan Wajah',
    'Status Validasi',
    'Approval',
  ];

  static final _fileStamp = DateFormat('yyyyMMdd_HHmmss');
  static final _fileDateFormat = DateFormat('d MMM yyyy HH:mm', 'id_ID');
  static final _headingDateFormat = DateFormat('d MMM yyyy', 'id_ID');

  List<List<String>> _rowsAsText(List<RekapRow> rows) {
    return [
      for (var i = 0; i < rows.length; i++)
        _rowAsText(rows[i], i + 1),
    ];
  }

  List<String> _rowAsText(RekapRow row, int number) {
    final a = row.absensi;
    return [
      '$number',
      row.pegawai.nama,
      row.spt.agenda,
      a.tipe.label,
      _fileDateFormat.format(a.waktu),
      a.jarakMeter.toStringAsFixed(1),
      '${(a.faceSimilarity * 100).toStringAsFixed(1)}%',
      a.status.label,
      a.approvalStatus.label,
    ];
  }

  String _periodLabel(DateTimeRange? range) {
    if (range == null) return 'Seluruh periode';
    return '${_headingDateFormat.format(range.start)} - ${_headingDateFormat.format(range.end)}';
  }

  Future<Directory> _outputDir() async {
    final dir = await getTemporaryDirectory();
    final exportDir = Directory('${dir.path}/rekap_export');
    if (!exportDir.existsSync()) {
      exportDir.createSync(recursive: true);
    }
    return exportDir;
  }

  Future<File> exportToPdf(List<RekapRow> rows, {DateTimeRange? range}) async {
    final doc = pw.Document();
    final generatedAt = _fileDateFormat.format(DateTime.now());
    final periodLabel = _periodLabel(range);
    final data = _rowsAsText(rows);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Rekap Absensi - GeoTani',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text('Periode: $periodLabel', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Dicetak: $generatedAt', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 10),
          ],
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: _headers,
            data: data,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignments: {0: pw.Alignment.center},
            columnWidths: {
              0: const pw.FixedColumnWidth(24),
              2: const pw.FlexColumnWidth(1.6),
            },
          ),
        ],
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Halaman ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
      ),
    );

    final dir = await _outputDir();
    final file = File('${dir.path}/rekap_absensi_${_fileStamp.format(DateTime.now())}.pdf');
    await file.writeAsBytes(await doc.save());
    return file;
  }

  Future<File> exportToExcel(List<RekapRow> rows, {DateTimeRange? range}) async {
    final sheetRows = <List<String>>[
      _headers,
      ..._rowsAsText(rows),
    ];

    final archive = Archive()
      ..addFile(ArchiveFile.string('[Content_Types].xml', _contentTypesXml))
      ..addFile(ArchiveFile.string('_rels/.rels', _rootRelsXml))
      ..addFile(ArchiveFile.string('xl/workbook.xml', _workbookXml))
      ..addFile(ArchiveFile.string('xl/_rels/workbook.xml.rels', _workbookRelsXml))
      ..addFile(ArchiveFile.string('xl/worksheets/sheet1.xml', _sheetXml(sheetRows)));

    final bytes = ZipEncoder().encode(archive);

    final dir = await _outputDir();
    final file = File('${dir.path}/rekap_absensi_${_fileStamp.format(DateTime.now())}.xlsx');
    await file.writeAsBytes(bytes);
    return file;
  }

  static const _contentTypesXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
</Types>''';

  static const _rootRelsXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''';

  static const _workbookXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="Rekap Absensi" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>''';

  static const _workbookRelsXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
</Relationships>''';

  static String _sheetXml(List<List<String>> rows) {
    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..writeln(
          '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>');

    for (var r = 0; r < rows.length; r++) {
      final rowNumber = r + 1;
      buffer.writeln('<row r="$rowNumber">');
      final cols = rows[r];
      for (var c = 0; c < cols.length; c++) {
        final cellRef = '${_columnLetter(c)}$rowNumber';
        final value = _escapeXml(cols[c]);
        buffer.writeln('<c r="$cellRef" t="inlineStr"><is><t xml:space="preserve">$value</t></is></c>');
      }
      buffer.writeln('</row>');
    }

    buffer.writeln('</sheetData></worksheet>');
    return buffer.toString();
  }

  /// Konversi indeks kolom 0-based ke huruf kolom Excel (0 -> A, 25 -> Z,
  /// 26 -> AA). Rekap ini hanya punya 9 kolom, tapi ditulis generik.
  static String _columnLetter(int index) {
    var n = index;
    var letters = '';
    do {
      letters = String.fromCharCode(65 + (n % 26)) + letters;
      n = (n ~/ 26) - 1;
    } while (n >= 0);
    return letters;
  }

  static String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
