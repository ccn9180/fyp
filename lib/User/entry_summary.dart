import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dart_sentiment/dart_sentiment.dart';
import 'package:fyp/app_localizations.dart';

class EntrySummaryScreen extends StatefulWidget {
  final String content;
  final String? imageUrl;
  final Function(String mood, String category, String summary, bool isCrisis, Map<String, bool> sharingTeams) onConfirm;

  const EntrySummaryScreen({
    super.key,
    required this.content,
    this.imageUrl,
    required this.onConfirm,
  });

  @override
  State<EntrySummaryScreen> createState() => _EntrySummaryScreenState();
}

class _EntrySummaryScreenState extends State<EntrySummaryScreen> {
  bool _isAnalyzing = true;
  String? _detectedMoodTitle;
  String? _summary;
  List<Map<String, dynamic>> _tags = [];
  bool _isCrisis = false;

  // Mock Sharing Data
  final Map<String, bool> _sharingStates = {
    'Mom': false,
    'Dr. Sarah': true,
    'Leo': false,
  };

  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color backgroundColor = const Color(0xFFEAE9E4);
  final Color textColorMain = const Color(0xFF333333);

  @override
  void initState() {
    super.initState();
    _performAnalysis();
  }

  Future<void> _performAnalysis() async {
    await Future.delayed(const Duration(seconds: 2));

    try {
      final String content = widget.content;
      final String lowerContent = content.toLowerCase();

      // 1. Scoring Categories
      int positiveScore = 0;
      int calmScore = 0;
      int negativeScore = 0;
      int tenseScore = 0;
      int socialScore = 0;

      // Positive Keywords
      if (RegExp(r'happy|glad|excited|great|amazing|wonderful|joy|smile|laugh|bright|love|good|best').hasMatch(lowerContent)) positiveScore += 2;
      // Calm/Reflective Keywords
      if (RegExp(r'calm|peace|relax|think|clear|mindful|nature|walk|quiet|still|breathe|slow').hasMatch(lowerContent)) calmScore += 2;
      // Negative Keywords
      if (RegExp(r'sad|unhappy|lonely|cry|lost|empty|hurt|pain|blue|miss|tears').hasMatch(lowerContent)) negativeScore += 2;
      // Tense/Anxious Keywords
      if (RegExp(r'stress|anxious|worry|fear|scared|tense|tight|panic|rapid|fast|rush|overwhelm').hasMatch(lowerContent)) tenseScore += 2;
      // Social Keywords (for summary context)
      if (RegExp(r'friend|family|mom|dad|talk|together|met|shared|group').hasMatch(lowerContent)) socialScore += 1;

      // 2. Determine Primary State
      String primaryState = 'Neutral';
      int maxScore = 0;

      if (positiveScore > maxScore) { primaryState = 'Positive'; maxScore = positiveScore; }
      if (calmScore > maxScore) { primaryState = 'Calm'; maxScore = calmScore; }
      if (negativeScore > maxScore) { primaryState = 'Negative'; maxScore = negativeScore; }
      if (tenseScore > maxScore) { primaryState = 'Tense'; maxScore = tenseScore; }

      // 3. Construct Dynamic Summary and Tags
      switch (primaryState) {
        case 'Positive':
          _detectedMoodTitle = 'Joyful & Bright';
          _summary = socialScore > 0
              ? 'It sounds like your day was brightened by meaningful connections. Sharing positive moments with others has clearly left you feeling uplifted and joyful.'
              : 'You are radiating positivity! Your writing suggests a day filled with personal wins and a vibrant energy that is wonderful to see.';
          _tags = [
            {'label': 'Cheerful', 'icon': Icons.wb_sunny_outlined, 'color': Colors.orange[50]},
            {'label': 'Grateful', 'icon': Icons.favorite_border_rounded, 'color': Colors.red[50]},
            {'label': 'Vibrant', 'icon': Icons.auto_awesome_outlined, 'color': Colors.yellow[50]},
          ];
          break;
        case 'Calm':
          _detectedMoodTitle = 'Reflective & Calm';
          _summary = lowerContent.contains('walk') || lowerContent.contains('nature')
              ? 'Finding peace in surroundings and a quiet pace has helped you gain clarity today. Your reflection shows a beautiful transition into mindful stillness.'
              : 'You have found a steady rhythm today. By leaning into calm and reflection, you have cultivated a sense of internal peace and mental clarity.';
          _tags = [
            {'label': 'Reflective', 'icon': Icons.settings_outlined, 'color': Colors.teal[50]},
            {'label': 'Mindful', 'icon': Icons.spa_outlined, 'color': Colors.green[50]},
            {'label': 'Peaceful', 'icon': Icons.sentiment_satisfied_alt_outlined, 'color': Colors.blue[50]},
          ];
          break;
        case 'Negative':
          _detectedMoodTitle = 'Pensive & Sentimental';
          _summary = socialScore > 0
              ? 'Navigating heavy emotions is easier when shared. Your writing shows you are working through some sensitive feelings involving those close to you.'
              : 'There is a gentle weight to your heart today. It is okay to sit with these pensive thoughts as you process your current emotional journey.';
          _tags = [
            {'label': 'Pensive', 'icon': Icons.search_rounded, 'color': Colors.blueGrey[50]},
            {'label': 'Sensitive', 'icon': Icons.bubble_chart_outlined, 'color': Colors.purple[50]},
            {'label': 'Quiet', 'icon': Icons.mic_off_outlined, 'color': Colors.indigo[50]},
          ];
          break;
        case 'Tense':
          _detectedMoodTitle = 'Tense & Overwhelmed';
          _summary = 'You are carrying a lot on your shoulders right now. The tension in your writing suggests you are navigating high-pressure moments that require significant energy.';
          _tags = [
            {'label': 'Intense', 'icon': Icons.warning_amber_rounded, 'color': Colors.red[50]},
            {'label': 'Stressed', 'icon': Icons.bolt_rounded, 'color': Colors.orange[50]},
            {'label': 'Determined', 'icon': Icons.trending_up_rounded, 'color': Colors.redAccent[50]},
          ];
          break;
        default:
          _detectedMoodTitle = 'Neutral & Balanced';
          _summary = 'Your entry is steady and observational. You are documenting your experiences with a grounded perspective, maintaining a balanced outlook on the day.';
          _tags = [
            {'label': 'Grounded', 'icon': Icons.filter_hdr_outlined, 'color': Colors.brown[50]},
            {'label': 'Steady', 'icon': Icons.linear_scale_rounded, 'color': Colors.grey[100]},
            {'label': 'Objective', 'icon': Icons.remove_red_eye_outlined, 'color': Colors.blueGrey[50]},
          ];
      }

      // 4. Crisis Catch-all (Highest Priority)
      final crisisKeywords = ['hurt', 'kill', 'end it', 'die', 'suicide', 'self-harm', 'give up', 'hopeless'];
      if (crisisKeywords.any((kw) => lowerContent.contains(kw))) {
        _isCrisis = true;
        _detectedMoodTitle = 'Urgent: High Distress';
        _summary = 'We noticed some very heavy words in your reflection. Your safety is the priority. Please consider reaching out to one of your trusted contacts or a professional.';
      }

    } catch (e) {
      _detectedMoodTitle = 'Reflection Captured';
      _summary = 'Your thoughts have been logged securely.';
    }

    if (mounted) {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAnalyzing) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFF7C9C84)),
              const SizedBox(height: 24),
              Text(
                'AI is analyzing your thoughts...',
                style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)!.translate('entry_summary'),
          style: GoogleFonts.outfit(
            color: textColorMain,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Color(0xFF333333)),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // AI Insights Header
            Row(
              children: [
                const Icon(Icons.auto_awesome_outlined, color: Color(0xFF7C9C84), size: 24),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.translate('ai_insights'),
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: textColorMain,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Summary Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    child: widget.imageUrl != null
                        ? Image.network(widget.imageUrl!, height: 220, width: double.infinity, fit: BoxFit.cover)
                        : Container(
                      height: 220,
                      width: double.infinity,
                      color: Colors.grey[200],
                      child: const Icon(Icons.park_outlined, size: 80, color: Colors.grey),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _detectedMoodTitle!,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: textColorMain,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _summary!,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            color: const Color(0xFF888888),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Tags Row
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _tags.map((tag) => _buildTag(tag['label'], tag['icon'], tag['color'])).toList(),
            ),

            const SizedBox(height: 48),

            // Sharing Access Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.group_outlined, color: Color(0xFF666666)),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.translate('sharing_access'),
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: textColorMain,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _sharingStates.updateAll((key, value) => false);
                    });
                  },
                  child: Text(
                    'REVOKE ALL',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Sharing Contacts List
            _buildSharingContact('Mom', 'FAMILY', Icons.person_outline, _sharingStates['Mom']!, (val) => setState(() => _sharingStates['Mom'] = val)),
            _buildSharingContact('Dr. Sarah', 'COUNSELOR', Icons.medical_services_outlined, _sharingStates['Dr. Sarah']!, (val) => setState(() => _sharingStates['Dr. Sarah'] = val)),
            _buildSharingContact('Leo', 'FRIEND', Icons.sentiment_satisfied_outlined, _sharingStates['Leo']!, (val) => setState(() => _sharingStates['Leo'] = val)),

            const SizedBox(height: 48),

            // Bottom Action Buttons
            SizedBox(
              width: double.infinity,
              height: 64,
              child: ElevatedButton.icon(
                onPressed: () {
                  String category = 'Neutral';
                  if (_detectedMoodTitle!.contains('Joyful') || _detectedMoodTitle!.contains('Positive')) category = 'Happy';
                  else if (_detectedMoodTitle!.contains('Calm')) category = 'Calm';
                  else if (_detectedMoodTitle!.contains('Tense')) category = 'Anxious';
                  else if (_detectedMoodTitle!.contains('Distress')) category = 'Anxious';

                  widget.onConfirm(_detectedMoodTitle!, category, _summary!, _isCrisis, _sharingStates);
                },
                icon: const Icon(Icons.done_all_rounded, color: Colors.white),
                label: Text(
                  AppLocalizations.of(context)!.translate('done_save'),
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.edit_outlined, color: Color(0xFF333333)),
                label: Text(
                  AppLocalizations.of(context)!.translate('edit_entry'),
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textColorMain,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String label, IconData icon, Color? color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEBEBE6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF666666)),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharingContact(String name, String relation, IconData icon, bool isSwitched, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEAE9E4),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.grey[400], size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColorMain,
                  ),
                ),
                Text(
                  relation,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[400],
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isSwitched,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: primaryGreen,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey[200],
          ),
        ],
      ),
    );
  }
}
