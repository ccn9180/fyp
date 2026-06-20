import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'active_chat.dart';
import 'chat_detail.dart';

class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  String _selectedFilter = 'All';
  DateTime? _selectedDate;
  final List<String> _filters = ['All', 'Anxiety', 'Gratitude', 'Sleep', 'Focus'];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final GlobalKey _exportKey = GlobalKey();
  bool _isExporting = false;
  Map<String, dynamic>? _exportData;

  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color backgroundColor = const Color(0xFFFBFBF6);
  final Color textColorMain = const Color(0xFF333333);
  final Color textColorSub = const Color(0xFF888888);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryGreen,
              onPrimary: Colors.white,
              onSurface: textColorMain,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showExportSheet(BuildContext context, Map<String, dynamic> chatData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 32),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'EXPORT CONVERSATION',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
                color: const Color(0xFFB0B0B0),
              ),
            ),
            const SizedBox(height: 32),
            _buildExportOption(
              context,
              Icons.picture_as_pdf_rounded,
              'Export as PDF',
              'Save this chat as a readable document',
              const Color(0xFF7C9C84),
              () {
                Navigator.pop(context);
                _exportAsPdf(chatData);
              },
            ),
            const SizedBox(height: 16),
            _buildExportOption(
              context,
              Icons.image_outlined,
              'Export as Image',
              'Save a snapshot of the conversation',
              const Color(0xFF8BA882),
              () {
                Navigator.pop(context);
                _exportAsImage(chatData);
              },
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(
                  color: Colors.grey[400],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportOption(BuildContext context, IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFBF9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColorMain,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: textColorSub,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[300]),
        ],
      ),
    ));
  }

  // ── PDF Export ────────────────────────────────────────────────
  Future<void> _exportAsPdf(Map<String, dynamic> data) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final String title = data['title'] ?? 'AI Chat Session';
      final String tag = data['tag'] ?? 'FOCUSED';
      final List<dynamic> messages = data['messages'] ?? [];
      final String aiSummary = data['aiSummary'] ?? data['preview'] ?? '';
      
      String dateStr = '';
      if (data['createdAt'] != null) {
        final DateTime dt = (data['createdAt'] as Timestamp).toDate();
        dateStr = DateFormat('MMMM d, yyyy  •  h:mm a').format(dt);
      } else {
        dateStr = DateFormat('MMMM d, yyyy').format(DateTime.now());
      }

      final doc = pw.Document();

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 56),
          build: (pw.Context ctx) => [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 20),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFF7C9C84), width: 1.5)),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('EUNOIA', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, letterSpacing: 2.0, color: const PdfColor.fromInt(0xFF7C9C84))),
                      pw.SizedBox(height: 4),
                      pw.Text('WELLNESS CHAT', style: const pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF9E9E9E), letterSpacing: 1.5)),
                    ],
                  ),
                  pw.Text(dateStr, style: const pw.TextStyle(fontSize: 11, color: PdfColor.fromInt(0xFF757575))),
                ],
              ),
            ),
            pw.SizedBox(height: 32),
            
            // Title & Emotion
            pw.Text(title, style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF333333))),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: pw.BoxDecoration(color: const PdfColor.fromInt(0xFFE8F5E9), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
              child: pw.Text('Tag: $tag', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF43A047))),
            ),
            pw.SizedBox(height: 32),

            // AI Summary
            if (aiSummary.isNotEmpty) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(color: const PdfColor.fromInt(0xFFF1F3EE), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12))),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('AI INSIGHTS', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF5D6D66), letterSpacing: 1.5)),
                    pw.SizedBox(height: 8),
                    pw.Text(aiSummary, style: const pw.TextStyle(fontSize: 12, color: PdfColor.fromInt(0xFF4A4A4A), lineSpacing: 4)),
                  ],
                ),
              ),
              pw.SizedBox(height: 32),
            ],

            // Transcript
            pw.Text('TRANSCRIPT', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFFB0B0B0), letterSpacing: 2.0)),
            pw.SizedBox(height: 16),
            ...messages.map((m) {
              final isAI = m['role'] == 'assistant';
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 16),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(isAI ? 'EUNOIA AI' : 'YOU', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: isAI ? const PdfColor.fromInt(0xFF7C9C84) : const PdfColor.fromInt(0xFFB0B0B0))),
                    pw.SizedBox(height: 4),
                    pw.Text(m['text'] ?? '', style: const pw.TextStyle(fontSize: 12, color: PdfColor.fromInt(0xFF333333), lineSpacing: 3)),
                  ],
                ),
              );
            }).toList(),
            
            pw.SizedBox(height: 48),
            pw.Center(
              child: pw.Text('Exported from Eunoia · Your personal wellness guide', style: const pw.TextStyle(fontSize: 10, color: PdfColor.fromInt(0xFFBDBDBD))),
            ),
          ],
        ),
      );

      final output = await getTemporaryDirectory();
      final safeTitle = title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final file = File('${output.path}/Chat_$safeTitle.pdf');
      await file.writeAsBytes(await doc.save());

      if (mounted) {
        await Share.shareXFiles([XFile(file.path)], text: 'My Wellness Chat: $title');
      }
    } catch (e) {
      debugPrint('PDF export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ── Image Export ──────────────────────────────────────────────
  Future<void> _exportAsImage(Map<String, dynamic> data) async {
    if (_isExporting) return;
    setState(() {
      _exportData = data;
      _isExporting = true;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    try {
      if (_exportKey.currentContext == null) throw Exception("Export context not found");
      
      final RenderRepaintBoundary boundary = _exportKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      final output = await getTemporaryDirectory();
      final safeTitle = (data['title'] ?? 'Chat').replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final file = File('${output.path}/Chat_$safeTitle.png');
      await file.writeAsBytes(pngBytes);

      if (mounted) {
        await Share.shareXFiles([XFile(file.path)], text: 'My Wellness Chat: ${data['title']}');
      }
    } catch (e) {
      debugPrint('Image export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() {
        _exportData = null;
        _isExporting = false;
      });
    }
  }

  Widget _buildExportCard(Map<String, dynamic> data) {
    final String title = data['title'] ?? 'AI Chat Session';
    final String tag = data['tag'] ?? 'FOCUSED';
    final String summary = data['aiSummary'] ?? data['preview'] ?? '';
    String dateStr = '';
    if (data['createdAt'] != null) {
      final DateTime dt = (data['createdAt'] as Timestamp).toDate();
      dateStr = DateFormat('MMMM d, yyyy').format(dt);
    } else {
      dateStr = DateFormat('MMMM d, yyyy').format(DateTime.now());
    }

    return Container(
      width: 600,
      color: const Color(0xFFFBFBF6),
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('EUNOIA', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2.0, color: const Color(0xFF7C9C84))),
                  Text('WELLNESS CHAT', style: GoogleFonts.outfit(fontSize: 10, color: const Color(0xFF9E9E9E), letterSpacing: 1.5)),
                ],
              ),
              Text(dateStr, style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF757575))),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: Color(0xFFEBEBE4), thickness: 1.5),
          const SizedBox(height: 32),
          Text(title, style: GoogleFonts.playfairDisplay(fontSize: 40, fontWeight: FontWeight.w600, color: const Color(0xFF333333))),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)),
            child: Text('Tag: $tag', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF43A047))),
          ),
          const SizedBox(height: 40),
          if (summary.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: const Color(0xFFF1F3EE), borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI INSIGHTS', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF5D6D66), letterSpacing: 1.5)),
                  const SizedBox(height: 12),
                  Text(summary, style: GoogleFonts.outfit(fontSize: 16, color: const Color(0xFF4A4A4A), height: 1.5)),
                ],
              ),
            ),
            const SizedBox(height: 48),
          ],
          Center(
            child: Text('✨ Exported from Eunoia Wellness Chat', style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFFB0B0B0))),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 0,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE57373), size: 32),
              ),
              const SizedBox(height: 24),
              Text(
                'Delete Chat?',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColorMain,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to remove this conversation from your history? This action cannot be undone.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: textColorSub,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        'Keep it',
                        style: GoogleFonts.outfit(
                          color: textColorSub,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await FirebaseFirestore.instance.collection('chat_sessions').doc(docId).delete();
                        } catch (e) {
                          print('Error deleting chat: $e');
                        }
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE57373),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        'Delete',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Chat History',
          style: GoogleFonts.playfairDisplay(
            color: textColorMain,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: const [],
      ),
      body: Stack(
        children: [
          if (_exportData != null)
            Positioned(
              left: -2000,
              child: RepaintBoundary(
                key: _exportKey,
                child: Material(
                  color: Colors.transparent,
                  child: _buildExportCard(_exportData!),
                ),
              ),
            ),
          Column(
            children: [
          const SizedBox(height: 16),
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search conversations...',
                  hintStyle: GoogleFonts.outfit(color: const Color(0xFFB0B0B0), fontSize: 15),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFFB0B0B0)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 24),
            child: Row(
              children: _filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedFilter = filter),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? primaryGreen : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          if (!isSelected)
                            BoxShadow(
                              color: Colors.black.withOpacity(0.01),
                              blurRadius: 5,
                            ),
                        ],
                      ),
                      child: Text(
                        filter,
                        style: GoogleFonts.outfit(
                          color: isSelected ? Colors.white : textColorSub,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 32),
          // Date Filter Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedDate == null 
                    ? 'RECENT CHATS' 
                    : 'CHATS FOR ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: textColorSub,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    if (_selectedDate == null) {
                      _selectDate(context);
                    } else {
                      setState(() => _selectedDate = null);
                    }
                  },
                  child: Row(
                    children: [
                      Icon(
                        _selectedDate == null ? Icons.calendar_today_outlined : Icons.close_rounded,
                        size: 14,
                        color: primaryGreen,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _selectedDate == null ? 'View Calendar' : 'Clear Date',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // List of chats
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chat_sessions')
                  .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF7C9C84)));
                }
                
                final documents = snapshot.data?.docs ?? [];
                final List<Map<String, dynamic>> sessions = [];
                
                for (var doc in documents) {
                  final data = doc.data() as Map<String, dynamic>;
                  data['id'] = doc.id;
                  sessions.add(data);
                }

                // Filter locally by search query and category/filter if selected
                final List<Map<String, dynamic>> filteredSessions = [];
                for (var session in sessions) {
                  final title = (session['title'] ?? '').toString().toLowerCase();
                  final tag = (session['tag'] ?? '').toString().toLowerCase();
                  final subTag = (session['subTag'] ?? '').toString().toLowerCase();
                  
                  // Filter by _selectedFilter (category)
                  bool matchesFilter = _selectedFilter == 'All';
                  if (!matchesFilter) {
                    matchesFilter = tag.contains(_selectedFilter.toLowerCase()) || subTag.contains(_selectedFilter.toLowerCase());
                  }

                  // Filter by search query
                  final matchesSearch = title.contains(_searchQuery);

                  // Filter by date if selected
                  bool matchesDate = true;
                  if (_selectedDate != null && session['createdAt'] != null) {
                    final DateTime dt = (session['createdAt'] as Timestamp).toDate();
                    matchesDate = dt.year == _selectedDate!.year &&
                        dt.month == _selectedDate!.month &&
                        dt.day == _selectedDate!.day;
                  }

                  if (matchesFilter && matchesSearch && matchesDate) {
                    filteredSessions.add(session);
                  }
                }

                if (filteredSessions.isEmpty) {
                  final bool isSearching = _searchQuery.isNotEmpty;
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: primaryGreen.withOpacity(0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isSearching ? Icons.search_off_rounded : Icons.forum_outlined,
                                      color: primaryGreen,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    isSearching ? "No results found" : "No conversations found",
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: textColorMain,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    isSearching ? 'Try adjusting your search terms or filters.' : 'Start your wellness conversation with Eunoia.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      color: textColorSub,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: filteredSessions.length,
                  itemBuilder: (context, index) {
                    final session = filteredSessions[index];
                    final String docId = session['id'];
                    final String title = session['title'] ?? 'AI Chat Session';
                    final String tag = session['tag'] ?? 'FOCUSED';
                    final String subTag = session['subTag'] ?? 'Mindfulness';
                    final String preview = session['preview'] ?? '';
                    
                    // Formatting date
                    String dateStr = '';
                    if (session['createdAt'] != null) {
                      final DateTime dt = (session['createdAt'] as Timestamp).toDate();
                      dateStr = DateFormat('MMM dd').format(dt);
                    } else {
                      dateStr = 'Just now';
                    }

                    // Assign colors & icon based on tag
                    IconData icon = Icons.wb_sunny_outlined;
                    Color iconColor = Colors.yellow[700]!;
                    Color tagBgColor = Colors.yellow[50]!;
                    Color tagTextColor = Colors.yellow[800]!;

                    if (tag == 'CALM') {
                      icon = Icons.cloud_outlined;
                      iconColor = const Color(0xFF7C8D84);
                      tagBgColor = const Color(0xFFE8F5E9);
                      tagTextColor = const Color(0xFF43A047);
                    } else if (tag == 'GRATEFUL') {
                      icon = Icons.favorite_rounded;
                      iconColor = Colors.orange[400]!;
                      tagBgColor = Colors.orange[50]!;
                      tagTextColor = Colors.orange[700]!;
                    } else if (tag == 'SLEEPY') {
                      icon = Icons.nightlight_round;
                      iconColor = Colors.blue[400]!;
                      tagBgColor = Colors.blue[50]!;
                      tagTextColor = Colors.blue[700]!;
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildChatCard(
                        context: context,
                        docId: docId,
                        chatData: session,
                        title: title,
                        date: dateStr,
                        tag: tag,
                        subTag: subTag,
                        preview: preview,
                        icon: icon,
                        iconColor: iconColor,
                        tagColor: tagBgColor,
                        tagTextColor: tagTextColor,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ],
  ),
  floatingActionButton: _isExporting
          ? null
          : FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ActiveChatScreen()),
          );
        },
        backgroundColor: primaryGreen,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildChatCard({
    required BuildContext context,
    required String docId,
    required Map<String, dynamic> chatData,
    required String title,
    required String date,
    required String tag,
    required String subTag,
    required String preview,
    required IconData icon,
    required Color iconColor,
    required Color tagColor,
    required Color tagTextColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatDetailScreen(
                docId: docId,
                chatData: chatData,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: GoogleFonts.outfit(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: textColorMain,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _showChatActionSheet(context, docId, chatData),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFBFBF6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.more_horiz_rounded, color: Color(0xFFC0C0C0), size: 18),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: tagColor,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      tag,
                                      style: GoogleFonts.outfit(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: tagTextColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      subTag,
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: const Color(0xFFB0B0B0),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              date,
                              style: GoogleFonts.outfit(
                                // Format date safely
                                fontSize: 13,
                                color: const Color(0xFFA0A0A0),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                preview,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: const Color(0xFF666666),
                  height: 1.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChatActionSheet(BuildContext context, String docId, Map<String, dynamic> chatData) {
    String chatTitle = chatData['title'] ?? 'AI Chat Session';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        decoration: const BoxDecoration(
          color: Color(0xFFFBFBF6),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 32),
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(2)),
            ),
            Text(
              'CONVERSATION OPTIONS',
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2.0, color: const Color(0xFFB0B0B0)),
            ),
            const SizedBox(height: 24),
            _buildChatActionItem(
              title: "View Transcript",
              subtitle: "Read the full history of this chat",
              icon: Icons.article_outlined,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatDetailScreen(
                      docId: docId,
                      chatData: chatData,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildChatActionItem(
              title: "Export Conversation",
              subtitle: "Save as PDF or Image document",
              icon: Icons.ios_share_rounded,
              onTap: () {
                Navigator.pop(context);
                _showExportSheet(context, chatData);
              },
            ),
            const SizedBox(height: 12),
            _buildChatActionItem(
              title: "Delete Chat",
              subtitle: "Permanently remove from history",
              icon: Icons.delete_outline_rounded,
              isDestructive: true,
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(context, docId);
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: GoogleFonts.outfit(color: textColorSub, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatActionItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDestructive ? const Color(0xFFFFEBEE) : const Color(0xFFF1F3EE),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isDestructive ? const Color(0xFFE57373) : primaryGreen, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: isDestructive ? const Color(0xFFE57373) : textColorMain)),
                  Text(subtitle, style: GoogleFonts.outfit(fontSize: 12, color: textColorSub)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[300], size: 20),
          ],
        ),
      ),
    );
  }
}
