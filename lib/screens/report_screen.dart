import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/health_store.dart';
import '../models/self_exam.dart';
import '../services/report_service.dart';
import '../theme/app_theme.dart';

/// One-tap professional health report: preview, save, print or share as a PDF.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  bool _sample = false;
  Uint8List? _sampleImage;

  Future<void> _useSample(bool on) async {
    if (on && _sampleImage == null) {
      try {
        _sampleImage = (await rootBundle.load('assets/images/breast_sample_benign.png')).buffer.asUint8List();
      } catch (_) {}
    }
    if (mounted) setState(() => _sample = on);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HealthStore>();
    final exam = context.watch<SelfExamState>();
    final empty = !store.hasAnyResult && store.logs.isEmpty;
    final data = _sample ? ReportData.sample(scanImage: _sampleImage) : ReportData.fromStore(store, lastSelfExam: exam.lastExam);
    final stamp = DateFormat('yyyy-MM-dd').format(data.generated);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textDark,
        title: const Text('Health report', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(16), boxShadow: AppTheme.softShadow),
            child: SwitchListTile(
              key: const Key('sample_switch'),
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.primaryBerry,
              title: const Text('Preview with sample data', style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text(
                empty && !_sample
                    ? 'You have no results yet, so the report is mostly empty. Turn this on to see a full example (clearly watermarked).'
                    : 'Shows demo data with a "SAMPLE DATA" watermark instead of your own results.',
                style: const TextStyle(fontFamily: 'Inter', fontSize: 12, height: 1.3),
              ),
              value: _sample,
              onChanged: _useSample,
            ),
          ),
          Expanded(
            child: PdfPreview(
              key: ValueKey('${_sample}_${store.hashCode}_${store.pcos?.date}_${store.scan?.date}_${store.breastRisk?.date}_${store.logs.length}'),
              build: (format) => buildReport(data),
              pdfFileName: 'Femora-Health-Report-$stamp.pdf',
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              allowPrinting: true,
              allowSharing: true,
              maxPageWidth: 640,
              loadingWidget: const CircularProgressIndicator(color: AppColors.primaryBerry),
            ),
          ),
        ],
      ),
    );
  }
}
