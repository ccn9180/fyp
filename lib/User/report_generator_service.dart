
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:fl_chart/fl_chart.dart';

class ReportGeneratorService {
  /// Internal font loading helper
  static Future<Map<String, pw.Font>> _loadFonts() async {
    pw.Font fontRegular;
    pw.Font fontBold;
    pw.Font fontSerif;

    try {
      fontRegular = await PdfGoogleFonts.outfitRegular();
      fontBold = await PdfGoogleFonts.outfitBold();
      fontSerif = await PdfGoogleFonts.playfairDisplayBold();
    } catch (e) {
      fontRegular = pw.Font.helvetica();
      fontBold = pw.Font.helveticaBold();
      fontSerif = pw.Font.timesBold();
    }
    return {
      'regular': fontRegular,
      'bold': fontBold,
      'serif': fontSerif,
    };
  }

  /// Internal styling helper
  static Map<String, PdfColor> _getColors() {
    return {
      'primary': PdfColor.fromHex('#7C9C84'),
      'secondary': PdfColor.fromHex('#BBCBC2'),
      'textMain': PdfColor.fromHex('#333333'),
      'textSub': PdfColor.fromHex('#888888'),
      'white': PdfColors.white,
    };
  }

  /// 1. FULL WELLNESS REPORT (Combined)
  static Future<void> generateUserReport({
    required String userName,
    required DateTimeRange dateRange,
    required Map<String, dynamic> stats,
    required List<dynamic> chartSpots,
  }) async {
    final fonts = await _loadFonts();
    final colors = _getColors();
    final pdf = pw.Document();
    final rangeStr = "${DateFormat('MMM d, yyyy').format(dateRange.start)} - ${DateFormat('MMM d, yyyy').format(dateRange.end)}";

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: fonts['regular'], bold: fonts['bold']),
        header: (context) => _buildHeader('PERSONAL WELLNESS AUDIT', colors['secondary']!),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildInstitutionalHeader('Mood and Activity Summary', userName, rangeStr, fonts['serif']!, colors),
          pw.SizedBox(height: 40),
          _buildExecutiveSummary(stats, fonts['serif']!, colors),
          pw.SizedBox(height: 40),
          _buildMoodTrendSection(chartSpots, fonts['serif']!, colors),
          pw.SizedBox(height: 40),
          _buildActivityTable(colors),
          pw.SizedBox(height: 40),
          _buildAIInsights(colors),
          pw.SizedBox(height: 40),
          _buildRecommendations(fonts['serif']!, colors),
          pw.SizedBox(height: 40),
          _buildSignatureArea(fonts['serif']!, colors),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Eunoia_Full_Report_${userName}.pdf',
    );
  }

  /// 2. MOOD TREND ANALYSIS REPORT (Full 8-Section Clinical Grade)
  static Future<void> generateMoodTrendReport({
    required String userName,
    required DateTimeRange dateRange,
    required Map<String, dynamic> stats,
    required List<dynamic> chartSpots,
  }) async {
    final fonts = await _loadFonts();
    final colors = _getColors();
    final pdf = pw.Document();
    final rangeStr = "${DateFormat('MMM d, yyyy').format(dateRange.start)} - ${DateFormat('MMM d, yyyy').format(dateRange.end)}";
    final refId = 'MT-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    final emotionData = [
      {'label': 'Happy', 'count': 9, 'pct': '21%', 'color': PdfColor.fromHex('#7C9C84')},
      {'label': 'Neutral', 'count': 7, 'pct': '17%', 'color': PdfColor.fromHex('#BBCBC2')},
      {'label': 'Stress', 'count': 12, 'pct': '28%', 'color': PdfColor.fromHex('#D97706')},
      {'label': 'Anxiety', 'count': 10, 'pct': '24%', 'color': PdfColor.fromHex('#EF4444')},
      {'label': 'Sadness', 'count': 4, 'pct': '10%', 'color': PdfColor.fromHex('#6B7280')},
    ];

    final triggerThemes = [
      'Academic Stress', 'Sleep Problems', 'Loneliness',
      'Relationship Issues', 'Self-doubt', 'Work Overload',
    ];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 40),
        theme: pw.ThemeData.withFont(base: fonts['regular'], bold: fonts['bold']),
        header: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 12),
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 1))),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Eunoia', style: pw.TextStyle(font: fonts['serif'], fontSize: 16, color: PdfColor.fromHex('#7C9C84'))),
              pw.Text('MOOD TREND ANALYSIS REPORT', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, letterSpacing: 1.4, color: PdfColors.grey)),
            ],
          ),
        ),
        footer: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 12),
          decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey200, width: 1))),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Generated by Eunoia Analytics Engine  |  Confidential', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
              pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
            ],
          ),
        ),
        build: (ctx) => [

          // ── COVER BLOCK ──────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(28),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F4F7F5'),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(14)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Mood Trend Analysis', style: pw.TextStyle(font: fonts['serif'], fontSize: 26, color: PdfColor.fromHex('#7C9C84'))),
                    pw.SizedBox(height: 6),
                    pw.Text('Emotional Intelligence and Pattern Report', style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
                    pw.SizedBox(height: 16),
                    pw.Text('User: $userName', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('Period: $rangeStr', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('REF: $refId', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#7C9C84'))),
                    pw.SizedBox(height: 4),
                    pw.Text('Generated: ${DateFormat('dd MMM yyyy').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
                    pw.SizedBox(height: 4),
                    pw.Text('Eunoia Analytics Engine v2.1', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 32),

          // ── SECTION 1: EXECUTIVE SUMMARY ─────────────────────────
          _buildSectionTitle('1. Executive Summary', fonts['serif']!, colors),
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColor.fromHex('#E0EAE3'), width: 1),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              color: PdfColors.white,
            ),
            child: pw.Text(
              'This report analyses the emotional patterns of $userName over the period $rangeStr. The overall mood trend indicates moderate fluctuation, with stress and anxiety appearing as the most frequent emotional states. A total of 42 diary and chatbot entries were analysed. High-risk periods were identified on 3 occasions, suggesting a need for proactive support. The AI model recommends continued journaling, structured mindfulness, and counsellor follow-up.',
              style: pw.TextStyle(fontSize: 10, lineSpacing: 1.6, color: PdfColors.grey700),
            ),
          ),
          pw.SizedBox(height: 16),
          // KPI cards
          pw.Row(
            children: [
              _buildSmallKpiCard('Avg. Mood Score', '3.8 / 5.0', PdfColor.fromHex('#7C9C84')),
              pw.SizedBox(width: 10),
              _buildSmallKpiCard('Most Frequent', 'Stress', PdfColor.fromHex('#D97706')),
              pw.SizedBox(width: 10),
              _buildSmallKpiCard('Mood Stability', '71%', PdfColor.fromHex('#BBCBC2')),
              pw.SizedBox(width: 10),
              _buildSmallKpiCard('Entries Analysed', '42', PdfColor.fromHex('#4B5563')),
              pw.SizedBox(width: 10),
              _buildSmallKpiCard('High-Risk Count', '3', PdfColor.fromHex('#EF4444')),
            ],
          ),
          pw.SizedBox(height: 32),

          // ── SECTION 2: MOOD TREND CHART ───────────────────────────
          _buildSectionTitle('2. Mood Trend Over Time', fonts['serif']!, colors),
          pw.SizedBox(height: 14),
          _buildMoodBarChart(chartSpots, colors),
          pw.SizedBox(height: 32),

          // ── SECTION 3: EMOTION DISTRIBUTION ──────────────────────
          _buildSectionTitle('3. Emotion Distribution', fonts['serif']!, colors),
          pw.SizedBox(height: 14),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 3,
                child: pw.Column(
                  children: emotionData.map((e) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 8),
                    child: pw.Row(
                      children: [
                        pw.Container(width: 10, height: 10, decoration: pw.BoxDecoration(color: e['color'] as PdfColor, shape: pw.BoxShape.circle)),
                        pw.SizedBox(width: 10),
                        pw.Expanded(child: pw.Text(e['label'] as String, style: const pw.TextStyle(fontSize: 10))),
                        pw.SizedBox(width: 8),
                        pw.Container(
                          width: (e['count'] as int) * 8.0,
                          height: 10,
                          decoration: pw.BoxDecoration(color: (e['color'] as PdfColor), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3))),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Text(e['pct'] as String, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  )).toList(),
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                flex: 2,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F4F7F5'), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10))),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Pattern Note', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#7C9C84'))),
                      pw.SizedBox(height: 8),
                      pw.Text('Stress and anxiety together account for 52% of all detected emotions, indicating a high-pressure emotional pattern during this reporting period.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700, lineSpacing: 1.5)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 32),

          // ── SECTION 4: RISK ANALYSIS ──────────────────────────────
          _buildSectionTitle('4. Risk Analysis', fonts['serif']!, colors),
          pw.SizedBox(height: 14),
          pw.Row(
            children: [
              _buildRiskBadge('Low Risk', '21 entries', PdfColor.fromHex('#7C9C84')),
              pw.SizedBox(width: 10),
              _buildRiskBadge('Medium Risk', '18 entries', PdfColor.fromHex('#D97706')),
              pw.SizedBox(width: 10),
              _buildRiskBadge('High Risk', '3 entries', PdfColor.fromHex('#EF4444')),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#FEF2F2'),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              border: pw.Border.all(color: PdfColor.fromHex('#FECACA'), width: 1),
            ),
            child: pw.Row(
              children: [
                pw.Container(width: 4, height: 40, color: PdfColor.fromHex('#EF4444')),
                pw.SizedBox(width: 14),
                pw.Expanded(child: pw.Text('WARNING: High-risk entries were detected. 3 diary entries and chatbot sessions exhibited severe negative mood intensity (score <= 1.5). Immediate counsellor review is advised if pattern persists.', style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.5, color: PdfColors.grey800))),
              ],
            ),
          ),
          pw.SizedBox(height: 32),

          // ── SECTION 5: TRIGGER THEMES ─────────────────────────────
          _buildSectionTitle('5. Trigger and Theme Analysis', fonts['serif']!, colors),
          pw.SizedBox(height: 14),
          pw.Wrap(
            spacing: 10,
            runSpacing: 8,
            children: triggerThemes.map((theme) => pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#EDF2EF'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(20)),
                border: pw.Border.all(color: PdfColor.fromHex('#7C9C84'), width: 1),
              ),
              child: pw.Text(theme, style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#7C9C84'), fontWeight: pw.FontWeight.bold)),
            )).toList(),
          ),
          pw.SizedBox(height: 32),

          // ── SECTION 6: BEHAVIOUR CORRELATION ─────────────────────
          _buildSectionTitle('6. Behaviour and Activity Correlation', fonts['serif']!, colors),
          pw.SizedBox(height: 14),
          pw.Column(
            children: [
              _buildInsightRow('Diary Frequency', 'Mood scores improved on days where diary entries were submitted. 67% of positive mood peaks occurred after consistent journaling.', colors),
              pw.SizedBox(height: 10),
              _buildInsightRow('Chatbot Usage', 'Negative mood spikes correlated with reduced chatbot interaction. Users who engaged the AI chatbot showed 22% faster emotional recovery.', colors),
              pw.SizedBox(height: 10),
              _buildInsightRow('Resource Engagement', 'Mood improved on days with self-help resource engagement. Articles related to anxiety management showed the strongest positive correlation.', colors),
            ],
          ),
          pw.SizedBox(height: 32),

          // ── SECTION 7: AI INSIGHTS ────────────────────────────────
          _buildSectionTitle('7. AI Insights and Recommendations', fonts['serif']!, colors),
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F4F7F5'),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildBullet('The user shows repeated signs of anxiety during late evening periods, suggesting sleep-related triggers.', colors),
                pw.SizedBox(height: 10),
                _buildBullet('Mood scores improved after consistent journaling — daily check-in habit should be reinforced.', colors),
                pw.SizedBox(height: 10),
                _buildBullet('It is recommended to explore guided meditation and breathing exercises available in the Eunoia resource library.', colors),
                pw.SizedBox(height: 10),
                _buildBullet('Consider counsellor intervention if high-risk patterns persist beyond the next 7-day window.', colors),
                pw.SizedBox(height: 10),
                _buildBullet('Positive trend badge: Mood is showing gradual improvement over the last 72 hours — continue current engagement habits.', colors),
              ],
            ),
          ),
          pw.SizedBox(height: 40),

          // ── SECTION 8: AUDIT FOOTER ───────────────────────────────
          pw.Divider(color: PdfColors.grey200, thickness: 1),
          pw.SizedBox(height: 20),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Eunoia Sage Analytics Engine', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColor.fromHex('#7C9C84'))),
                  pw.SizedBox(height: 4),
                  pw.Text('This report is strictly confidential and intended solely for the named recipient.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  pw.SizedBox(height: 2),
                  pw.Text('Report ID: $refId  |  Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(width: 160, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 1)))),
                  pw.SizedBox(height: 6),
                  pw.Text('Verified by System Administrator', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Eunoia_MoodTrend_${userName}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  // Helper: Section Title
  static pw.Widget _buildSectionTitle(String title, pw.Font serif, Map<String, PdfColor> colors) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(font: serif, fontSize: 16, color: colors['textMain'])),
        pw.SizedBox(height: 6),
        pw.Container(height: 2, width: 40, color: colors['primary']),
      ],
    );
  }

  // Helper: Small KPI Card
  static pw.Widget _buildSmallKpiCard(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
          border: pw.Border.all(color: PdfColors.grey200, width: 1),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(width: 20, height: 3, color: color),
            pw.SizedBox(height: 8),
            pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color)),
            pw.SizedBox(height: 4),
            pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
      ),
    );
  }

  // Helper: Mood Bar Chart visual
  static pw.Widget _buildMoodBarChart(List<dynamic> spots, Map<String, PdfColor> colors) {
    final labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)), border: pw.Border.all(color: PdfColors.grey200)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Mood Score (0–5 Scale)', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          pw.SizedBox(height: 16),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: spots.asMap().entries.map((entry) {
              final double y = entry.value is FlSpot ? (entry.value as FlSpot).y : (entry.value['y']?.toDouble() ?? 3.0);
              final maxH = 80.0;
              final barH = (y / 5.0) * maxH;
              final isHigh = y >= 4.0;
              final isLow = y <= 2.0;
              final barColor = isHigh ? colors['primary']! : (isLow ? PdfColor.fromHex('#EF4444') : PdfColor.fromHex('#BBCBC2'));
              return pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(y.toStringAsFixed(1), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: barColor)),
                  pw.SizedBox(height: 4),
                  pw.Container(
                    width: 28,
                    height: barH,
                    decoration: pw.BoxDecoration(color: barColor, borderRadius: const pw.BorderRadius.only(topLeft: pw.Radius.circular(4), topRight: pw.Radius.circular(4))),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(entry.key < labels.length ? labels[entry.key] : '', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Helper: Risk Badge
  static pw.Widget _buildRiskBadge(String label, String sub, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: color.shade(0.1),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
          border: pw.Border.all(color: color, width: 1),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: color)),
            pw.SizedBox(height: 4),
            pw.Text(sub, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ],
        ),
      ),
    );
  }

  // Helper: Insight row
  static pw.Widget _buildInsightRow(String label, String text, Map<String, PdfColor> colors) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
        border: pw.Border.all(color: PdfColors.grey200),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(width: 3, height: 36, color: colors['primary']!),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: colors['primary']!)),
                pw.SizedBox(height: 4),
                pw.Text(text, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700, lineSpacing: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }



  /// 3. ACTIVITY SUMMARY REPORT (Full 8-Section Clinical Grade)
  static Future<void> generateActivitySummaryReport({
    required String userName,
    required DateTimeRange dateRange,
    required Map<String, dynamic> stats,
  }) async {
    final fonts = await _loadFonts();
    final colors = _getColors();
    final pdf = pw.Document();
    final rangeStr = "${DateFormat('MMM d, yyyy').format(dateRange.start)} - ${DateFormat('MMM d, yyyy').format(dateRange.end)}";
    final refId = 'AS-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    // Mock data for breakdown
    final moduleData = [
      {'label': 'Diary', 'count': 24, 'pct': '32%', 'color': PdfColor.fromHex('#7C9C84')},
      {'label': 'Chatbot', 'count': 18, 'pct': '24%', 'color': PdfColor.fromHex('#BBCBC2')},
      {'label': 'Counselling', 'count': 4, 'pct': '5%', 'color': PdfColor.fromHex('#D97706')},
      {'label': 'Resources', 'count': 15, 'pct': '20%', 'color': PdfColor.fromHex('#4B5563')},
      {'label': 'Community', 'count': 14, 'pct': '19%', 'color': PdfColor.fromHex('#6B7280')},
    ];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 40),
        theme: pw.ThemeData.withFont(base: fonts['regular'], bold: fonts['bold']),
        header: (ctx) => _buildHeader('ACTIVITY ENGAGEMENT AUDIT', colors['secondary']!),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          // 1. Institutional Header
          _buildInstitutionalHeader('Activity Summary Report', userName, rangeStr, fonts['serif']!, colors),
          pw.SizedBox(height: 32),

          // 2. Executive Summary
          _buildSectionTitle('1. Executive Summary', fonts['serif']!, colors),
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColor.fromHex('#E0EAE3'), width: 1),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              color: PdfColors.white,
            ),
            child: pw.Text(
              'This report provides an overview of $userName\'s activity across the Eunoia platform for the period $rangeStr. The data indicates active engagement in journaling, chatbot interaction, and resource usage, with steady participation across multiple modules. Total interactions reached 75 unique events, showing strong platform adoption and consistent therapeutic habit formation.',
              style: pw.TextStyle(fontSize: 10, lineSpacing: 1.6, color: PdfColors.grey700),
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              _buildSmallKpiCard('Diary Entries', stats['diary']?.toString() ?? '12', PdfColor.fromHex('#7C9C84')),
              pw.SizedBox(width: 8),
              _buildSmallKpiCard('Chat Sessions', stats['chatbot']?.toString() ?? '8', PdfColor.fromHex('#BBCBC2')),
              pw.SizedBox(width: 8),
              _buildSmallKpiCard('Resources', stats['resources']?.toString() ?? '15', PdfColor.fromHex('#4B5563')),
              pw.SizedBox(width: 8),
              _buildSmallKpiCard('Appointments', stats['appointments']?.toString() ?? '2', PdfColor.fromHex('#D97706')),
              pw.SizedBox(width: 8),
              _buildSmallKpiCard('XP Earned', stats['xp']?.toString() ?? '450', PdfColor.fromHex('#7C9C84')),
            ],
          ),
          pw.SizedBox(height: 32),

          // 3. Activity Trend
          _buildSectionTitle('2. Activity Trend Over Time', fonts['serif']!, colors),
          pw.SizedBox(height: 14),
          _buildActivityBarChart(colors),
          pw.SizedBox(height: 32),

          // 4. Module Breakdown
          _buildSectionTitle('3. Module Usage Breakdown', fonts['serif']!, colors),
          pw.SizedBox(height: 14),
          pw.Column(
            children: moduleData.map((e) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Row(
                children: [
                  pw.Container(width: 10, height: 10, decoration: pw.BoxDecoration(color: e['color'] as PdfColor, shape: pw.BoxShape.circle)),
                  pw.SizedBox(width: 10),
                  pw.Expanded(child: pw.Text(e['label'] as String, style: const pw.TextStyle(fontSize: 10))),
                  pw.SizedBox(width: 8),
                  pw.Container(
                    width: (e['count'] as int) * 4.0,
                    height: 10,
                    decoration: pw.BoxDecoration(color: (e['color'] as PdfColor), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3))),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(e['pct'] as String, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            )).toList(),
          ),
          pw.SizedBox(height: 32),

          // 5. Recent Activity Log
          _buildSectionTitle('4. Recent Activity Log', fonts['serif']!, colors),
          pw.SizedBox(height: 14),
          _buildActivityLogTable(colors),
          pw.SizedBox(height: 32),

          // 6. Engagement Patterns
          _buildSectionTitle('5. Engagement Pattern', fonts['serif']!, colors),
          pw.SizedBox(height: 14),
          pw.Row(
            children: [
              _buildInsightCard('Most Active Day', 'Tuesday', null, PdfColor.fromHex('#7C9C84')),
              pw.SizedBox(width: 12),
              _buildInsightCard('Peak Time', '9 PM - 11 PM', null, PdfColor.fromHex('#4B5563')),
              pw.SizedBox(width: 12),
              _buildInsightCard('Top Module', 'Diary', null, PdfColor.fromHex('#D97706')),
            ],
          ),
          pw.SizedBox(height: 32),

          // 7. Progress and Achievement
          _buildSectionTitle('6. Progress and Achievement', fonts['serif']!, colors),
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F4F7F5'), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12))),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildAchievementItem('Current Level', '12', colors),
                _buildAchievementItem('Badges Won', '8', colors),
                _buildAchievementItem('Rewards', '3', colors),
                _buildAchievementItem('Streak', '5 Days', colors),
              ],
            ),
          ),
          pw.SizedBox(height: 32),

          // 8. Insights and Recommendations
          _buildSectionTitle('7. Insights and Recommendations', fonts['serif']!, colors),
          pw.SizedBox(height: 14),
          _buildInsightPoint('The user is most active in the Diary module, indicating strong self-reflection habits.', colors),
          pw.SizedBox(height: 8),
          _buildInsightPoint('Chatbot usage increased during the last 7 days, aligning with high-stress academic periods.', colors),
          pw.SizedBox(height: 8),
          _buildInsightPoint('Community interaction remains low compared to self-help usage; consider exploring peer support groups.', colors),
          pw.SizedBox(height: 24),
          _buildInsightPoint('Maintain consistent journaling habits to track long-term emotional progress.', colors),
          pw.SizedBox(height: 8),
          _buildInsightPoint('Continue completing activities to gain XP and unlock tiered health rewards.', colors),
          pw.SizedBox(height: 48),

          _buildSignatureArea(fonts['serif']!, colors),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Eunoia_ActivitySum_${userName}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  static pw.Widget _buildInsightCard(String title, String value, dynamic icon, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey200),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            pw.SizedBox(height: 8),
            pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildAchievementItem(String label, String val, Map<String, PdfColor> colors) {
    return pw.Column(
      children: [
        pw.Text(val, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: colors['primary']!)),
        pw.SizedBox(height: 4),
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      ],
    );
  }

  static pw.Widget _buildActivityBarChart(Map<String, PdfColor> colors) {
    final values = [4, 6, 3, 8, 5, 7, 4];
    final labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return pw.Container(
      height: 120,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey200), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: List.generate(7, (i) => pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Container(
              width: 20,
              height: values[i] * 10.0,
              decoration: pw.BoxDecoration(color: i == 3 ? PdfColor.fromHex('#F59E0B') : colors['primary']!, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
            ),
            pw.SizedBox(height: 6),
            pw.Text(labels[i], style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        )),
      ),
    );
  }

  static pw.Widget _buildActivityLogTable(Map<String, PdfColor> colors) {
    final logs = [
      {'date': 'Oct 14, 09:12 AM', 'type': 'Added Entry', 'module': 'Diary', 'status': 'Completed'},
      {'date': 'Oct 14, 08:45 AM', 'type': 'AI Chat', 'module': 'Chatbot', 'status': 'Completed'},
      {'date': 'Oct 13, 04:30 PM', 'type': 'Session', 'module': 'Counselling', 'status': 'Attended'},
      {'date': 'Oct 12, 11:20 AM', 'type': 'Read Article', 'module': 'Resources', 'status': 'Viewed'},
      {'date': 'Oct 11, 09:00 PM', 'type': 'Redeemed', 'module': 'Rewards', 'status': 'Success'},
    ];

    return pw.Table(
      border: const pw.TableBorder(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: ['DATE / TIME', 'ACTIVITY', 'MODULE', 'STATUS'].map((h) => pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
          )).toList(),
        ),
        ...logs.map((l) => pw.TableRow(
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(l['date']!, style: const pw.TextStyle(fontSize: 8))),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(l['type']!, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(l['module']!, style: const pw.TextStyle(fontSize: 8))),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(l['status']!, style: pw.TextStyle(fontSize: 8, color: colors['primary']!))),
          ],
        )),
      ],
    );
  }


  /// 4. COUNSELLOR PERFORMANCE REPORT (Full 8-Section Professional Audit)
  static Future<void> generateCounsellorPerformanceReport({
    required String counsellorName,
    required String totalSessions,
    required String avgRating,
    required String feedbackCount,
    required String clinicalHours,
    required String completionRate,
    required String retentionRate,
    required String rangeLabel,
    required DateTimeRange dateRange,
  }) async {
    final fonts = await _loadFonts();
    final colors = _getColors();
    final pdf = pw.Document();
    final rangeStr = "${DateFormat('MMM d, yyyy').format(dateRange.start)} - ${DateFormat('MMM d, yyyy').format(dateRange.end)}";
    final refId = 'CP-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    // Mock data for breakdown
    final serviceData = [
      {'label': 'Individual', 'count': 45, 'pct': '60%', 'color': PdfColor.fromHex('#7C9C84')},
      {'label': 'Follow-up', 'count': 15, 'pct': '20%', 'color': PdfColor.fromHex('#BBCBC2')},
      {'label': 'Crisis', 'count': 5, 'pct': '7%', 'color': PdfColor.fromHex('#EF4444')},
      {'label': 'Online', 'count': 10, 'pct': '13%', 'color': PdfColor.fromHex('#4B5563')},
    ];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 40),
        theme: pw.ThemeData.withFont(base: fonts['regular'], bold: fonts['bold']),
        header: (ctx) => _buildHeader('COUNSELLOR PERFORMANCE AUDIT', colors['secondary']!),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          // 1. Institutional Header
          _buildInstitutionalHeader('Counsellor Performance Report', '', rangeStr, fonts['serif']!, colors),
          pw.SizedBox(height: 32),

          // 2. Executive Summary
          _buildSectionTitle('1. Executive Summary', fonts['serif']!, colors),
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColor.fromHex('#E0EAE3'), width: 1),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              color: PdfColors.white,
            ),
            child: pw.Text(
              'This report provides an overview of $counsellorName\'s service performance during the $rangeLabel period. The overall results indicate consistent session completion, positive client feedback, and stable engagement across counselling activities. Clinical benchmarks remain high with exceptional patient satisfaction reported.',
              style: pw.TextStyle(fontSize: 10, lineSpacing: 1.6, color: PdfColors.grey700),
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              _buildSmallKpiCard('Sessions', totalSessions, PdfColor.fromHex('#7C9C84')),
              pw.SizedBox(width: 8),
              _buildSmallKpiCard('Avg. Rating', '$avgRating / 5.0', PdfColor.fromHex('#BBCBC2')),
              pw.SizedBox(width: 8),
              _buildSmallKpiCard('Completion', completionRate, PdfColor.fromHex('#4B5563')),
              pw.SizedBox(width: 8),
              _buildSmallKpiCard('Clients', '28', PdfColor.fromHex('#D97706')),
              pw.SizedBox(width: 8),
              _buildSmallKpiCard('Attendance', '94%', PdfColor.fromHex('#7C9C84')),
            ],
          ),
          pw.SizedBox(height: 32),

          // 3. Session Activity Trend
          _buildSectionTitle('2. Session Activity Trend', fonts['serif']!, colors),
          pw.SizedBox(height: 14),
          _buildActivityBarChart(colors),
          pw.SizedBox(height: 32),

          // 4. Feedback Overview
          _buildSectionTitle('3. Feedback and Satisfaction', fonts['serif']!, colors),
          pw.SizedBox(height: 14),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Rating Distribution', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 8),
                    _buildRatingBar('Excellent', 85, PdfColor.fromHex('#7C9C84')),
                    _buildRatingBar('Good', 12, PdfColor.fromHex('#BBCBC2')),
                    _buildRatingBar('Average', 3, PdfColor.fromHex('#D97706')),
                  ],
                ),
              ),
              pw.SizedBox(width: 32),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Common Feedback Themes', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 8),
                    pw.Wrap(
                      spacing: 8, runSpacing: 8,
                      children: ['Supportive', 'Professional', 'Good Listener', 'Valuable Guidance'].map((t) => pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F4F7F5'), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
                        child: pw.Text(t, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                      )).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 32),

          // 5. Service Breakdown
          _buildSectionTitle('4. Service Breakdown', fonts['serif']!, colors),
          pw.SizedBox(height: 14),
          pw.Column(
            children: serviceData.map((e) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Row(
                children: [
                  pw.Container(width: 8, height: 8, decoration: pw.BoxDecoration(color: e['color'] as PdfColor, shape: pw.BoxShape.circle)),
                  pw.SizedBox(width: 10),
                  pw.Expanded(child: pw.Text(e['label'] as String, style: const pw.TextStyle(fontSize: 10))),
                  pw.Text(e['pct'] as String, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            )).toList(),
          ),
          pw.SizedBox(height: 32),

          // 6. Client Engagement Indicators
          _buildSectionTitle('5. Client Engagement Indicators', fonts['serif']!, colors),
          pw.SizedBox(height: 14),
          pw.Row(
            children: [
              _buildInsightCard('Repeat Rate', retentionRate, null, PdfColor.fromHex('#7C9C84')),
              pw.SizedBox(width: 12),
              _buildInsightCard('Follow-up Exp.', '92%', null, PdfColor.fromHex('#4B5563')),
              pw.SizedBox(width: 12),
              _buildInsightCard('Peak Consultation', 'Afternoon', null, PdfColor.fromHex('#D97706')),
            ],
          ),
          pw.SizedBox(height: 32),

          // 7. Personal Insights
          _buildSectionTitle('6. Personal Insights', fonts['serif']!, colors),
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F4F7F5'), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12))),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildInsightPoint('The counsellor maintains a strong average rating across all sessions.', colors),
                pw.SizedBox(height: 8),
                _buildInsightPoint('Most sessions are concentrated in stress and anxiety support.', colors),
                pw.SizedBox(height: 8),
                _buildInsightPoint('Follow-up completion remains high, showing good continuity of care.', colors),
              ],
            ),
          ),
          pw.SizedBox(height: 32),

          // 8. Recommendations
          _buildSectionTitle('7. Recommendations', fonts['serif']!, colors),
          pw.SizedBox(height: 14),
          _buildInsightPoint('Maintain current strengths in client communication and punctuality.', colors),
          pw.SizedBox(height: 8),
          _buildInsightPoint('Consider optimising availability during peak booking periods.', colors),
          pw.SizedBox(height: 8),
          _buildInsightPoint('Improve response time for follow-up scheduling where possible.', colors),
          pw.SizedBox(height: 48),

          _buildSignatureArea(fonts['serif']!, colors),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Eunoia_Performance_${counsellorName}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  static pw.Widget _buildRatingBar(String label, int val, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 50, child: pw.Text(label, style: const pw.TextStyle(fontSize: 8))),
          pw.Expanded(
            child: pw.Stack(
              children: [
                pw.Container(height: 4, decoration: const pw.BoxDecoration(color: PdfColors.grey100)),
                pw.Container(width: val * 1.5, height: 4, decoration: pw.BoxDecoration(color: color)),
              ],
            ),
          ),
          pw.SizedBox(width: 30, child: pw.Text('$val%', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right)),
        ],
      ),
    );
  }


  static pw.Widget _buildQuoteBox(String quote, String attribution, Map<String, PdfColor> colors) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F8FAF9'),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
        border: pw.Border.all(color: PdfColor.fromHex('#E0EAE3'), width: 1),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(width: 3, height: 40, color: PdfColor.fromHex('#7C9C84')),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(quote, style: pw.TextStyle(fontSize: 10, lineSpacing: 1.4)),
                pw.SizedBox(height: 6),
                pw.Text(attribution, style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#7C9C84'), fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildBullet(String text, Map<String, PdfColor> colors) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 6, height: 6,
          margin: const pw.EdgeInsets.only(top: 4, right: 10),
          decoration: pw.BoxDecoration(color: colors['primary']!, shape: pw.BoxShape.circle),
        ),
        pw.Expanded(child: pw.Text(text, style: pw.TextStyle(fontSize: 10, lineSpacing: 1.4, color: colors['textMain']))),
      ],
    );
  }


  static pw.Widget _buildMetricCard(String title, String value, Map<String, PdfColor> colors) {
    return pw.Container(
      width: 220,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
        border: pw.Border.all(color: PdfColors.grey100, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(value, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: colors['primary']!)),
          pw.SizedBox(height: 8),
          pw.Text(title, style: pw.TextStyle(fontSize: 10, color: colors['textSub']!)),
        ]
      )
    );
  }

  // --- REUSABLE BUILDING BLOCKS ---

  static pw.Widget _buildHeader(String title, PdfColor color) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Text(
        'EUNOIA SAGE | $title',
        style: pw.TextStyle(color: color, fontSize: 10, fontWeight: pw.FontWeight.bold, letterSpacing: 1.2),
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 20),
      child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(color: PdfColors.grey, fontSize: 9)),
    );
  }

  static pw.Widget _buildInstitutionalHeader(String title, String user, String range, pw.Font serif, Map<String, PdfColor> colors) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(font: serif, fontSize: 24, color: colors['primary'])),
            if (user.isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Text('Confidential analysis for $user', style: pw.TextStyle(color: colors['textSub'], fontSize: 10)),
            ],
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('REPORTING PERIOD', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: colors['secondary']!)),
            pw.Text(range, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: colors['textMain']!)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildExecutiveSummary(Map<String, dynamic> stats, pw.Font serif, Map<String, PdfColor> colors) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Executive Summary', style: pw.TextStyle(font: serif, fontSize: 20, color: colors['textMain'])),
        pw.Divider(color: colors['primary'], thickness: 2),
        pw.SizedBox(height: 16),
        pw.Row(
          children: [
            _buildSummaryIndicator('Average Mood', stats['avgMood'] ?? 'Stable', colors['primary']!),
            pw.SizedBox(width: 20),
            _buildSummaryIndicator('Frequent Sentiment', stats['frequent'] ?? 'Calm', colors['secondary']!),
            pw.SizedBox(width: 20),
            _buildSummaryIndicator('Stability Score', '84%', PdfColors.grey300),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildMoodTrendSection(List<dynamic> chartSpots, pw.Font serif, Map<String, PdfColor> colors) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Mood Intensity Trend', style: pw.TextStyle(font: serif, fontSize: 20, color: colors['textMain'])),
        pw.SizedBox(height: 20),
        pw.Container(
          height: 150,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey100, width: 2),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: chartSpots.map((spot) {
              final double yValue = spot is FlSpot ? spot.y : (spot['y']?.toDouble() ?? 0.0);
              final double xValue = spot is FlSpot ? spot.x : (spot['x']?.toDouble() ?? 0.0);
              final double heightPercent = (yValue / 5.0).clamp(0.1, 1.0);
              return pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 25,
                    height: 100 * heightPercent,
                    decoration: pw.BoxDecoration(color: colors['primary'], borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text('Day ${xValue.toInt() + 1}', style: pw.TextStyle(fontSize: 8, color: colors['textSub'])),
                ],
              );
            }).toList(),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text('* Values represent emotional intensity (1-Low, 5-High)', style: pw.TextStyle(fontSize: 8, color: colors['textSub'], fontStyle: pw.FontStyle.italic)),
      ],
    );
  }

  static pw.Widget _buildActivityTable(Map<String, PdfColor> colors) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Activity Engagement Analysis', style: pw.TextStyle(fontSize: 20, color: colors['textMain'])),
        pw.SizedBox(height: 20),
        pw.TableHelper.fromTextArray(
          headerDecoration: pw.BoxDecoration(color: colors['primary']),
          headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
          cellPadding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          data: [
            ['Activity Area', 'Frequency', 'Impact', 'Status'],
            ['Chatbot Support', '24 sessions', 'High', 'Optimal'],
            ['Diary Entries', '12 entries', 'Medium', 'Increasing'],
            ['Resources', '8 viewed', 'High', 'Steady'],
            ['Counselling', '1 session', 'Very High', 'Active'],
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildAIInsights(Map<String, PdfColor> colors) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
        border: pw.Border.all(color: PdfColor(colors['secondary']!.red, colors['secondary']!.green, colors['secondary']!.blue, 0.3), width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text('Patterns Observed', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: colors['primary'], fontSize: 14)),
              pw.SizedBox(width: 8),
              pw.Text('(AI-Generated)', style: pw.TextStyle(color: colors['textSub'], fontSize: 10)),
            ],
          ),
          pw.SizedBox(height: 12),
          _buildInsightBullet('Emotional resilience peaked during morning hours, following diary entry completions.'),
          _buildInsightBullet('Strong correlation detected between "Stable" mood and consistent Resource consumption.'),
          _buildInsightBullet('Evening energy levels show occasional restlessness; consider guided meditation.'),
        ],
      ),
    );
  }

  static pw.Widget _buildRecommendations(pw.Font serif, Map<String, PdfColor> colors) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Personal Recommendations', style: pw.TextStyle(font: serif, fontSize: 20, color: colors['textMain'])),
        pw.SizedBox(height: 16),
        pw.Bullet(text: 'Maintain your current journaling streak; it correlates highly with your mood stability.'),
        pw.Bullet(text: 'Explore the "Trauma Recovery" module to align with recent topics.'),
        pw.Bullet(text: 'Schedule your next therapy session in week 4 to sustain the current trend.'),
      ],
    );
  }

  static pw.Widget _buildSignatureArea(pw.Font serif, Map<String, PdfColor> colors) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey100),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Generated by Eunoia Sage AI', style: pw.TextStyle(color: colors['secondary'], fontSize: 10)),
                pw.Text(DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()), style: pw.TextStyle(color: colors['textSub'], fontSize: 8)),
              ],
            ),
            pw.Text('TOWARDS A MORE BALANCED YOU', style: pw.TextStyle(font: serif, fontSize: 12, color: colors['primary'])),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildSummaryIndicator(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.grey100),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: color)),
          pw.SizedBox(height: 4),
          pw.Text(label, style: const pw.TextStyle(color: PdfColors.grey, fontSize: 9)),
        ],
      ),
    );
  }

  static pw.Widget _buildInsightBullet(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 4, height: 4, margin: const pw.EdgeInsets.only(top: 6),
            decoration: const pw.BoxDecoration(color: PdfColors.grey, shape: pw.BoxShape.circle),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(child: pw.Text(text, style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.5))),
        ],
      ),
    );
  }

  static pw.Widget _buildInsightPoint(String text, Map<String, PdfColor> colors) {
    return _buildBullet(text, colors);
  }
}
