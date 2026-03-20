
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CounsellorAnalyticsScreen extends StatelessWidget {
  const CounsellorAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Color primaryGreen = const Color(0xFF7C9C84);
    final Color backgroundColor = const Color(0xFFEAE9E4);
    final Color textColorMain = const Color(0xFF333333);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Performance Analytics',
          style: GoogleFonts.playfairDisplay(color: textColorMain, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildChartPlaceholder('Session Trends (Past 30 Days)', primaryGreen),
            const SizedBox(height: 24),
            Row(
              children: [
                _buildStatBox('Total Sessions', '142', Icons.event_available_rounded, Colors.blue),
                const SizedBox(width: 16),
                _buildStatBox('Avg. Rating', '4.92', Icons.star_rounded, Colors.amber),
              ],
            ),
            const SizedBox(height: 24),
            _buildChartPlaceholder('Client Retention Rate', Colors.purple),
            const SizedBox(height: 40),
            Text(
              'DETAILED METRICS',
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey[400]),
            ),
            const SizedBox(height: 16),
            _buildMetricRow('Patient Growth', '+12%', true),
            _buildMetricRow('No-show Rate', '2%', false),
            _buildMetricRow('Avg. Session Duration', '48m', null),
          ],
        ),
      ),
    );
  }

  Widget _buildChartPlaceholder(String title, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 40),
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.1)),
            ),
            child: Center(
              child: Icon(Icons.bar_chart_rounded, size: 48, color: color.withOpacity(0.3)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 12),
            Text(value, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(label, style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, bool? isPositive) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF333333))),
          Row(
            children: [
              if (isPositive != null)
                Icon(
                  isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  size: 16,
                  color: isPositive ? Colors.green : Colors.red,
                ),
              const SizedBox(width: 8),
              Text(
                value,
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: isPositive == null ? const Color(0xFF333333) : (isPositive ? Colors.green : Colors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
