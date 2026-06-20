import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class SessionFeedbackScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  final bool startWithFeedback;

  const SessionFeedbackScreen({
    super.key,
    required this.session,
    this.startWithFeedback = false,
  });

  @override
  State<SessionFeedbackScreen> createState() => _SessionFeedbackScreenState();
}

class _SessionFeedbackScreenState extends State<SessionFeedbackScreen> {
  int _selectedRating = 0;
  final TextEditingController _feedbackController = TextEditingController();
  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color backgroundColor = const Color(0xFFFBFBF6);
  final Color textColorMain = const Color(0xFF333333);
  final Color textColorSub = const Color(0xFF888888);
  bool _isSubmitting = false;
  bool _hasExistingFeedback = false;
  bool _isReadOnly = false;

  @override
  void initState() {
    super.initState();
    if (widget.session['rating'] != null) {
      _selectedRating = widget.session['rating'] is int 
          ? widget.session['rating'] 
          : int.tryParse(widget.session['rating'].toString()) ?? 0;
      _hasExistingFeedback = _selectedRating > 0;
    }
    if (widget.session['feedback'] != null) {
      if (widget.session['feedback'] is Map) {
        _feedbackController.text = (widget.session['feedback']['comment'] ?? '').toString();
      } else {
        _feedbackController.text = widget.session['feedback'].toString();
      }
    }
    
    // Read only if they already left feedback OR if the session was missed
    _isReadOnly = _hasExistingFeedback || widget.session['isMissed'] == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF333333), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'SESSION REVIEW',
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: textColorMain,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Session Info Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: const Color(0xFFEEF3F0),
                    backgroundImage: (widget.session['counsellorImageUrl'] ?? '').toString().isNotEmpty
                      ? ((widget.session['counsellorImageUrl'] as String).startsWith('data:image')
                          ? MemoryImage(base64Decode((widget.session['counsellorImageUrl'] as String).split(',').last)) as ImageProvider
                          : NetworkImage(widget.session['counsellorImageUrl'] as String))
                      : null,
                    child: (widget.session['counsellorImageUrl'] ?? '').toString().isEmpty 
                      ? const Icon(Icons.person, color: Color(0xFF98B3A1), size: 40) 
                      : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.session['counsellorName'],
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textColorMain,
                    ),
                  ),
                  Text(
                    widget.session['counsellorSpecialty'],
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: textColorSub,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildInfoItem(Icons.calendar_today_outlined, DateFormat('MMM dd').format((widget.session['startTime'] as Timestamp).toDate())),
                      _buildInfoItem(Icons.access_time_rounded, widget.session['sessionDuration']),
                      _buildInfoItem(Icons.videocam_outlined, widget.session['type']),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // AI/Session Summary
            Text(
              'SESSION SUMMARY',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: textColorSub,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3EE),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Text(
                widget.session['summary'],
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: textColorMain,
                  height: 1.6,
                ),
              ),
            ),

            const SizedBox(height: 48),

            // Rating Section
            if (widget.session['isMissed'] == true)
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.grey, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Session Missed',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textColorMain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This session was missed, so feedback cannot be provided.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: textColorSub,
                      ),
                    ),
                  ],
                ),
              )
            else
              Center(
                child: Column(
                  children: [
                    Text(
                      'Rate your experience',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textColorMain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'How would you describe your session with ${widget.session['counsellorName']}?',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: textColorSub,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < _selectedRating ? Icons.star_rounded : Icons.star_border_rounded,
                            color: index < _selectedRating ? const Color(0xFFFFB74D) : Colors.grey[300],
                            size: 44,
                          ),
                          onPressed: _isReadOnly ? null : () => setState(() => _selectedRating = index + 1),
                        );
                      }),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 32),

            // Feedback Field
            if (widget.session['isMissed'] != true && 
                (!_hasExistingFeedback || _feedbackController.text.trim().isNotEmpty)) ...[
              Text(
                _hasExistingFeedback ? 'YOUR FEEDBACK' : 'SHARE MORE (OPTIONAL)',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: textColorSub,
                ),
              ),
              const SizedBox(height: 12),
              if (_hasExistingFeedback)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    _feedbackController.text.trim(),
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: textColorMain,
                      height: 1.5,
                    ),
                  ),
                )
              else
                TextField(
                  controller: _feedbackController,
                  maxLines: 4,
                  readOnly: _isReadOnly,
                  decoration: InputDecoration(
                    hintText: 'What did you find most helpful? Any areas for improvement?',
                    hintStyle: GoogleFonts.outfit(color: Colors.grey[400], fontSize: 14),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: Colors.grey[100]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: Colors.grey[100]!),
                    ),
                    contentPadding: const EdgeInsets.all(20),
                  ),
                ),
              const SizedBox(height: 40),
            ],
            if (_hasExistingFeedback)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle_rounded, color: primaryGreen, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Feedback Submitted',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textColorMain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Thank you for your review. It has been recorded permanently.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: textColorSub,
                      ),
                    ),
                  ],
                ),
              )
            else if (widget.session['isMissed'] != true)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: InkWell(
                    onTap: (_selectedRating > 0 && !_isSubmitting) ? () async {
                      bool? confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) {
                          return Dialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                            backgroundColor: Colors.white,
                            elevation: 0,
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF7C9C84).withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.rate_review_rounded, color: Color(0xFF7C9C84), size: 36),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Submit Review?',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.playfairDisplay(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 24,
                                      color: const Color(0xFF333333),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Once submitted, your review is permanent and cannot be changed.\nAre you sure you want to proceed?',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      height: 1.5,
                                      color: const Color(0xFF666666),
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          ),
                                          child: Text('Cancel', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[600])),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF7C9C84),
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          ),
                                          child: Text('Submit', style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );

                      if (confirm != true) return;

                      setState(() {
                        _isSubmitting = true;
                      });
                      
                      try {
                        await FirebaseFirestore.instance
                            .collection('counsellor_bookings')
                            .doc(widget.session['id'])
                            .update({
                          'rating': _selectedRating,
                          'feedback': {
                            'rating': _selectedRating,
                            'comment': _feedbackController.text.trim(),
                            'date': DateFormat('MMM dd').format(DateTime.now()),
                          },
                          'feedbackSubmittedAt': FieldValue.serverTimestamp(),
                        });
                        
                        if (!mounted) return;
                        setState(() {
                          _hasExistingFeedback = true;
                          _isReadOnly = true;
                          _isSubmitting = false;
                          // Update the local session map to reflect the change
                          widget.session['rating'] = _selectedRating;
                          widget.session['feedback'] = _feedbackController.text.trim();
                        });
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Thank you for your feedback!'), 
                            backgroundColor: Color(0xFF7C9C84)
                          ),
                        );
                      } catch (e) {
                        setState(() {
                          _isSubmitting = false;
                        });
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to submit: $e'), backgroundColor: Colors.red),
                        );
                      }
                    } : null,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: (_selectedRating > 0 && !_isSubmitting) 
                            ? [primaryGreen, const Color(0xFF6A8A72)] 
                            : [Colors.grey[400]!, Colors.grey[500]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          if (_selectedRating > 0 && !_isSubmitting)
                            BoxShadow(
                              color: primaryGreen.withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isSubmitting)
                            const SizedBox(
                              width: 24, 
                              height: 24, 
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            )
                          else ...[
                            Text(
                              'SUBMIT',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: primaryGreen, size: 24),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: textColorMain,
          ),
        ),
      ],
    );
  }
}
