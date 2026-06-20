import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:fyp/services/backend_config.dart';
import 'package:fyp/services/friends_service.dart';


// ── Backend URL ──────────────────────────────────────────────
// Android emulator → 10.0.2.2  |  iOS simulator / Desktop → 127.0.0.1
String get _kBackendBase {
  if (!kIsWeb) {
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:5000';
      }
    } catch (_) {}
  }
  return 'http://127.0.0.1:5000';
}

class EntrySummaryScreen extends StatefulWidget {
  final String entryTitle;
  final String content;
  final String? imageUrl;
  final Future<void> Function(String mood, String category, String summary, bool isCrisis,
      Map<String, bool> sharingTeams, String? secondaryCategory, List<dynamic>? emotionPercentages, List<String>? keywords) onConfirm;

  const EntrySummaryScreen({
    super.key,
    required this.entryTitle,
    required this.content,
    this.imageUrl,
    required this.onConfirm,
  });

  @override
  State<EntrySummaryScreen> createState() => _EntrySummaryScreenState();
}

class _EntrySummaryScreenState extends State<EntrySummaryScreen> {
  bool _isAnalyzing = true;
  bool _apiError = false;
  bool _isSaving = false;

  String _detectedMoodTitle = 'Reflection Captured';
  String _summary = 'Your thoughts have been securely logged.';
  String _emotion = 'neutral';
  String? _secondaryEmotion;
  double _confidence = 0.0;
  bool _isCrisis = false;
  List<dynamic> _emotionPercentages = [];

  List<Map<String, dynamic>> _tags = [];

  final User? _currentUser = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>> _trustedContacts = [];
  final Map<String, bool> _sharingStates = {};
  bool _loadingContacts = true;

  final Color primaryGreen = const Color(0xFF7C9C84);
  final Color backgroundColor = const Color(0xFFF2F1EC);
  final Color textColorMain = const Color(0xFF333333);
  final Color textColorSub = const Color(0xFF888888);

  IconData _getRelationshipIcon(String? relationship) {
    final rel = relationship?.toUpperCase() ?? 'OTHER';
    if (rel == 'FAMILY') return Icons.person_outline;
    if (rel == 'COUNSELOR' || rel == 'DOCTOR') return Icons.medical_services_outlined;
    if (rel == 'FRIEND') return Icons.sentiment_satisfied_outlined;
    return Icons.people_outline;
  }

  // ── Emotion → tags mapping ───────────────────────────────
  static const Map<String, List<Map<String, dynamic>>> _emotionTags = {
    'joy': [
      {'label': 'Cheerful',  'icon': Icons.wb_sunny_outlined,          'color': Color(0xFFFFF9E6)},
      {'label': 'Grateful',  'icon': Icons.favorite_border_rounded,    'color': Color(0xFFFFEBEE)},
      {'label': 'Vibrant',   'icon': Icons.auto_awesome_outlined,      'color': Color(0xFFFFFDE7)},
    ],
    'calm': [
      {'label': 'Reflective','icon': Icons.self_improvement_outlined,  'color': Color(0xFFE0F2F1)},
      {'label': 'Mindful',   'icon': Icons.spa_outlined,               'color': Color(0xFFE8F5E9)},
      {'label': 'Peaceful',  'icon': Icons.sentiment_satisfied_alt_outlined, 'color': Color(0xFFE3F2FD)},
    ],
    'sadness': [
      {'label': 'Pensive',   'icon': Icons.search_rounded,             'color': Color(0xFFECEFF1)},
      {'label': 'Sensitive', 'icon': Icons.bubble_chart_outlined,      'color': Color(0xFFEDE7F6)},
      {'label': 'Quiet',     'icon': Icons.mic_off_outlined,           'color': Color(0xFFE8EAF6)},
    ],
    'anxiety': [
      {'label': 'Stressed',  'icon': Icons.bolt_rounded,               'color': Color(0xFFFFF3E0)},
      {'label': 'Intense',   'icon': Icons.warning_amber_rounded,      'color': Color(0xFFFFEBEE)},
      {'label': 'Determined','icon': Icons.trending_up_rounded,        'color': Color(0xFFFCE4EC)},
    ],
    'anger': [
      {'label': 'Frustrated','icon': Icons.flash_on_outlined,          'color': Color(0xFFFFEBEE)},
      {'label': 'Unsettled', 'icon': Icons.cloud_outlined,             'color': Color(0xFFFFF3E0)},
      {'label': 'Processing','icon': Icons.psychology_outlined,        'color': Color(0xFFFCE4EC)},
    ],
    'neutral': [
      {'label': 'Grounded',  'icon': Icons.filter_hdr_outlined,        'color': Color(0xFFF5F5F0)},
      {'label': 'Steady',    'icon': Icons.linear_scale_rounded,       'color': Color(0xFFF5F5F5)},
      {'label': 'Objective', 'icon': Icons.remove_red_eye_outlined,    'color': Color(0xFFECEFF1)},
    ],
  };

  @override
  void initState() {
    super.initState();
    _performAnalysis();
    _fetchTrustedContacts();
  }

  Future<void> _fetchTrustedContacts() async {
    if (_currentUser == null) {
      if (mounted) setState(() => _loadingContacts = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_currentUser.uid).get();
      if (doc.exists && doc.data()?['trustedContacts'] != null) {
        final rawList = doc.data()?['trustedContacts'] as List<dynamic>? ?? [];
        final list = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        
        bool needsUpdateInDb = false;
        final updatedList = <Map<String, dynamic>>[];
        for (var contact in list) {
          final Map<String, dynamic> mutableContact = Map<String, dynamic>.from(contact);
          if (mutableContact['uid'] == null && mutableContact['email'] != null) {
            final email = mutableContact['email'].toString().toLowerCase().trim();
            try {
              final querySnapshot = await FirebaseFirestore.instance
                  .collection('users')
                  .where('email', isEqualTo: email)
                  .limit(1)
                  .get();
              if (querySnapshot.docs.isNotEmpty) {
                mutableContact['uid'] = querySnapshot.docs.first.id;
                needsUpdateInDb = true;
              }
            } catch (e) {
              debugPrint('Error resolving missing UID for contact $email: $e');
            }
          }
          updatedList.add(mutableContact);
        }

        if (needsUpdateInDb) {
          final List<String> trustedContactUids = updatedList
              .map((c) => c['uid'] as String?)
              .where((uid) => uid != null)
              .cast<String>()
              .toList();

          await FirebaseFirestore.instance.collection('users').doc(_currentUser.uid).update({
            'trustedContacts': updatedList,
            'trustedContactUids': trustedContactUids,
          });
        }
        
        // Fetch profile pictures for contacts that have UIDs
        final List<String> validUids = updatedList
            .map((c) => c['uid'] as String?)
            .where((uid) => uid != null && uid.isNotEmpty)
            .cast<String>()
            .toList();
            
        if (validUids.isNotEmpty) {
          final profiles = await FriendsService.getProfiles(validUids);
          final profileMap = {for (var p in profiles) p.uid: p.profileImageUrl};
          for (var contact in updatedList) {
            if (contact['uid'] != null && profileMap[contact['uid']] != null) {
              contact['profileImageUrl'] = profileMap[contact['uid']];
            }
          }
        }

        if (mounted) {
          setState(() {
            _trustedContacts = updatedList;
            for (var contact in _trustedContacts) {
              final shareKey = contact['uid'] ?? contact['email'] ?? contact['name'] ?? '';
              if (shareKey.isNotEmpty) {
                _sharingStates[shareKey] = false;
              }
            }
            _loadingContacts = false;
          });
        }
      } else {
        if (mounted) setState(() => _loadingContacts = false);
      }
    } catch (e) {
      debugPrint('Error fetching trusted contacts: $e');
      if (mounted) setState(() => _loadingContacts = false);
    }
  }

  // Helper methods to get emotion details
  String _getEmotionEmoji(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'joy': return '😊';
      case 'calm': return '😌';
      case 'sadness': case 'sad': return '😢';
      case 'anxiety': case 'anxious': return '😰';
      case 'anger': case 'angry': return '😠';
      default: return '😐';
    }
  }

  String _getEmotionDisplayName(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'joy': return 'Happy';
      case 'calm': return 'Calm';
      case 'sadness': case 'sad': return 'Sad';
      case 'anxiety': case 'anxious': return 'Anxious';
      case 'anger': case 'angry': return 'Angry';
      default: return 'Neutral';
    }
  }

  Color _getEmotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'joy': return const Color(0xFF4CAF50);
      case 'calm': return const Color(0xFF2196F3);
      case 'sadness': case 'sad': return const Color(0xFF9C27B0);
      case 'anxiety': case 'anxious': return const Color(0xFFFF9800);
      case 'anger': case 'angry': return const Color(0xFFF44336);
      default: return const Color(0xFF9E9E9E);
    }
  }

  Color _getEmotionBgColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'joy': return const Color(0xFFE8F5E9);
      case 'calm': return const Color(0xFFE3F2FD);
      case 'sadness': case 'sad': return const Color(0xFFF3E5F5);
      case 'anxiety': case 'anxious': return const Color(0xFFFFF3E0);
      case 'anger': case 'angry': return const Color(0xFFFFEBEE);
      default: return const Color(0xFFF5F5F5);
    }
  }

  // ── Call the trained model via API ───────────────────────
  Future<void> _performAnalysis() async {
    // Small artificial delay so the "analyzing" animation shows
    await Future.delayed(const Duration(seconds: 2));

    bool success = false;
    try {
      final response = await BackendConfig.withRetry((baseUrl) => http
          .post(
            Uri.parse('$baseUrl/predict_emotion'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': widget.content}),
          )
          .timeout(const Duration(seconds: 4)));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        _emotion           = data['emotion']    ?? 'neutral';
        _secondaryEmotion  = data['secondary_emotion'];
        _detectedMoodTitle = widget.entryTitle;
        _summary           = data['summary']    ?? 'Your thoughts have been securely logged.';
        _confidence        = (data['confidence'] as num?)?.toDouble() ?? 0.0;
        _isCrisis          = data['is_crisis']  ?? false;
        // Deduplicate by display name (what the user sees) — keeps highest
        // confidence entry when multiple raw labels map to the same display name
        // (e.g. "neutral", "hopeful", "disgust" all render as "Neutral").
        final rawPercentages = (data['emotion_percentages'] as List?) ?? [];
        final Map<String, dynamic> seenByDisplay = {};
        for (final ep in rawPercentages) {
          final eName = (ep['emotion'] ?? 'neutral').toString();
          final displayName = _getEmotionDisplayName(eName);
          final conf = (ep['confidence'] as num?)?.toDouble() ?? 0.0;
          final existingConf = (seenByDisplay[displayName]?['confidence'] as num?)?.toDouble() ?? -1.0;
          if (conf > existingConf) {
            seenByDisplay[displayName] = ep;
          }
        }
        _emotionPercentages = seenByDisplay.values.toList()
          ..sort((a, b) => ((b['confidence'] as num?) ?? 0).compareTo((a['confidence'] as num?) ?? 0));
        
        final List<dynamic> hashtags = data['hashtags'] ?? [];
        if (hashtags.isNotEmpty) {
          _tags = hashtags.map((h) => {
            'label': h.toString(),
            'icon': Icons.label_outline,
            'color': const Color(0xFFE8F5E9), // Gentle green pastel background
          }).toList();
        } else {
          _tags = [];
        }
        
        _apiError = false;
        success = true;
      }
    } catch (e) {
      debugPrint('Failed to connect to backend: $e');
    }

    if (!success) {
      _fallbackToRules();
    }

    if (mounted) {
      setState(() => _isAnalyzing = false);
    }
  }

  Map<String, String> _getFallbackMeta(String emotion) {
    switch (emotion) {
      case 'joy':
        return {
          'title': 'Joyful & Bright',
          'summary': 'You are radiating positivity! Your writing suggests a day filled with personal wins.',
        };
      case 'calm':
        return {
          'title': 'Reflective & Calm',
          'summary': 'You have found a steady rhythm today. By leaning into calm and reflection, you have cultivated internal peace.',
        };
      case 'sadness':
        return {
          'title': 'Pensive & Melancholic',
          'summary': 'There is a gentle weight to your heart today. It is okay to sit with these pensive thoughts.',
        };
      case 'anxiety':
      default:
        return {
          'title': 'Tense & Overwhelmed',
          'summary': 'You are carrying a lot on your shoulders right now. The tension in your writing suggests high-pressure moments.',
        };
    }
  }

  // ── Fallback: original keyword rule logic ────────────────
  void _fallbackToRules() {
    _apiError = true;
    final lowerContent = widget.content.toLowerCase();

    int positiveScore = 0, calmScore = 0, negativeScore = 0, tenseScore = 0, socialScore = 0;

    if (RegExp(r'\b(happy|glad|excited|great|amazing|wonderful|joy|smile|laugh|bright|love|delighted)\b').hasMatch(lowerContent)) positiveScore += 2;
    if (RegExp(r'\b(calm|peace|relax|think|clear|mindful|nature|walk|quiet|breathe|slow|serene)\b').hasMatch(lowerContent)) calmScore += 2;
    if (RegExp(r'\b(sad|unhappy|lonely|cry|lost|empty|hurt|pain|blue|miss|tears|grief)\b').hasMatch(lowerContent)) negativeScore += 2;
    if (RegExp(r'\b(stress|anxious|worry|fear|scared|tense|tight|panic|rapid|fast|rush|overwhelm|frustrated|deadline|pressure)\b').hasMatch(lowerContent)) tenseScore += 2;
    if (RegExp(r'\b(friend|family|mom|dad|talk|together|met|shared|group|support)\b').hasMatch(lowerContent)) socialScore += 1;

    final List<Map<String, dynamic>> scores = [
      {'emotion': 'joy', 'score': positiveScore},
      {'emotion': 'calm', 'score': calmScore},
      {'emotion': 'sadness', 'score': negativeScore},
      {'emotion': 'anxiety', 'score': tenseScore},
    ];

    scores.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

    final String primary = scores[0]['emotion'];
    final int primaryScore = scores[0]['score'];

    final String secondary = scores[1]['emotion'];
    final int secondaryScore = scores[1]['score'];

    _emotion = primary;
    _secondaryEmotion = null;

    if (primaryScore >= 2 && secondaryScore >= 2 && (primaryScore - secondaryScore) <= 1) {
      _secondaryEmotion = secondary;
    }

    if (_secondaryEmotion != null) {
      final pair = [_emotion, _secondaryEmotion!];
      pair.sort();
      final pKey = pair.join('_');
      
      String mixedTitle = 'Mixed Reflections';
      if (pKey == 'calm_joy') mixedTitle = 'Peaceful Happiness';
      if (pKey == 'anxiety_joy') mixedTitle = 'Nervous Excitement';
      if (pKey == 'joy_sadness') mixedTitle = 'Bittersweet Reflections';
      if (pKey == 'calm_sadness') mixedTitle = 'Pensive Melancholy';
      if (pKey == 'anxiety_calm') mixedTitle = 'Quiet Concern';
      if (pKey == 'anxiety_sadness') mixedTitle = 'Heavy and Anxious';

      _detectedMoodTitle = mixedTitle;

      final primaryMeta = _getFallbackMeta(primary);
      final secDisplay = {
        'joy': 'happiness',
        'calm': 'calmness',
        'sadness': 'melancholy',
        'anxiety': 'worry or tension',
      }[secondary] ?? secondary;

      _summary = 'You are navigating a blend of emotions today. ' + primaryMeta['summary']! + ' Alongside this, your reflections carry underlying tones of $secDisplay.';
    } else {
      final meta = _getFallbackMeta(primary);
      _detectedMoodTitle = meta['title']!;
      _summary = meta['summary']!;
    }

    // Very basic offline hashtag extraction fallback
    final words = lowerContent.split(RegExp(r'\W+'))
      .where((w) => w.length > 3 && !['this', 'that', 'with', 'from', 'have'].contains(w))
      .toList();
    final uniqueWords = words.toSet().toList();
    final topWords = uniqueWords.take(3).toList();
    
    if (topWords.isNotEmpty) {
      _tags = topWords.map((w) => {
        'label': w[0].toUpperCase() + w.substring(1),
        'icon': Icons.label_outline,
        'color': const Color(0xFFE8F5E9),
      }).toList();
    } else {
      _tags = [];
    }

    final crisisKeywords = ['hurt', 'kill', 'end it', 'die', 'suicide', 'self-harm', 'give up', 'hopeless'];
    if (crisisKeywords.any((kw) => lowerContent.contains(kw))) {
      _isCrisis = true;
      _detectedMoodTitle = 'Urgent: High Distress';
      _summary = 'We noticed some very heavy words in your reflection. Your safety is the priority. Please consider reaching out to a trusted contact or professional.';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAnalyzing || _isSaving) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFF7C9C84)),
              const SizedBox(height: 24),
              Text(
                _isSaving ? 'Saving your reflection...' : 'AI is analyzing your thoughts...',
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
        actions: const [SizedBox(width: 48)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // API fallback notice (dev aid, subtle)
            if (_apiError)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Color(0xFFF9A825)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Using offline analysis — emotion model server not reachable.',
                        style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF795548)),
                      ),
                    ),
                  ],
                ),
              ),

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

            // ── Crisis Banner ────────────────────────────────────
            if (_isCrisis)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFEF9A9A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFE53935), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'We care about your safety. Please reach out to a trusted person or professional.',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: const Color(0xFFB71C1C),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Summary Card ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFEBEBE6)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  
                  if (_secondaryEmotion != null) ...[
                    // Secondary Emotion Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getEmotionBgColor(_secondaryEmotion!),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _getEmotionColor(_secondaryEmotion!).withOpacity(0.15),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getEmotionEmoji(_secondaryEmotion!),
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Secondary: ${_getEmotionDisplayName(_secondaryEmotion!)}",
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _getEmotionColor(_secondaryEmotion!),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // Summary Quoted Block
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF0F0F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        Expanded(
                          child: Text(
                            _summary,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              color: const Color(0xFF555555),
                              height: 1.6,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_emotionPercentages.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    Text(
                      'EMOTION BREAKDOWN',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: const Color(0xFF999999),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._emotionPercentages.map((ep) {
                      final eName = ep['emotion'] ?? 'neutral';
                      final conf = (ep['confidence'] as num?)?.toDouble() ?? 0.0;
                      final cLabel = _getEmotionDisplayName(eName);
                      final cColor = _getEmotionColor(eName);
                      final emoji = _getEmotionEmoji(eName);
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          children: [
                            SizedBox(width: 24, child: Text(emoji, style: const TextStyle(fontSize: 14))),
                            SizedBox(
                              width: 70, 
                              child: Text(
                                cLabel, 
                                style: GoogleFonts.outfit(fontSize: 13, color: textColorMain, fontWeight: FontWeight.w500)
                              )
                            ),
                            Expanded(
                              child: Stack(
                                children: [
                                  Container(
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: cColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: (conf / 100).clamp(0.0, 1.0),
                                    child: Container(
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: cColor,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            SizedBox(
                              width: 40,
                              child: Text(
                                '${conf.toStringAsFixed(0)}%',
                                style: GoogleFonts.outfit(fontSize: 12, color: textColorSub, fontWeight: FontWeight.w600),
                                textAlign: TextAlign.right,
                              )
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],

                  if (_tags.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Divider(color: Color(0xFFF0F0F0)),
                    const SizedBox(height: 20),
                    Text(
                      'THEMES',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: const Color(0xFF999999),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _tags
                          .map((tag) => _buildTag(tag['label'], tag['icon'], tag['color']))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 48),

            // Sharing Access Header
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

            const SizedBox(height: 16),

            if (_loadingContacts)
              const Center(child: CircularProgressIndicator(color: Color(0xFF7C9C84)))
            else if (_trustedContacts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No trusted contacts added yet. Add them in your Profile.',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: const Color(0xFF888888),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              ..._trustedContacts.map((contact) {
                final name = contact['name'] ?? contact['label'] ?? 'Unknown';
                final shareKey = contact['uid'] ?? contact['email'] ?? contact['name'] ?? '';
                final relation = contact['relationship'] ?? 'OTHER';
                final profileImg = contact['profileImageUrl'];
                final icon = _getRelationshipIcon(relation);
                return _buildSharingContact(
                  name,
                  relation,
                  icon,
                  _sharingStates[shareKey] ?? false,
                  (val) => setState(() => _sharingStates[shareKey] = val),
                  profileImageUrl: profileImg,
                );
              }).toList(),

            const SizedBox(height: 24),

            // Confirm Button
            SizedBox(
              width: double.infinity,
              height: 64,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : () async {
                  String category = 'Neutral';
                  if (_emotion == 'joy')     category = 'Happy';
                  if (_emotion == 'calm')    category = 'Calm';
                  if (_emotion == 'anxiety') category = 'Anxious';
                  if (_emotion == 'anger')   category = 'Angry';
                  if (_emotion == 'sadness') category = 'Sad';

                  String? secondaryCategory;
                  if (_secondaryEmotion != null) {
                    if (_secondaryEmotion == 'joy')     secondaryCategory = 'Happy';
                    if (_secondaryEmotion == 'calm')    secondaryCategory = 'Calm';
                    if (_secondaryEmotion == 'anxiety') secondaryCategory = 'Anxious';
                    if (_secondaryEmotion == 'anger')   secondaryCategory = 'Angry';
                    if (_secondaryEmotion == 'sadness') secondaryCategory = 'Sad';
                    if (_secondaryEmotion == 'neutral') secondaryCategory = 'Neutral';
                  }

                  setState(() {
                    _isSaving = true;
                  });

                  try {
                    await widget.onConfirm(
                      _detectedMoodTitle,
                      category,
                      _summary,
                      _isCrisis,
                      _sharingStates,
                      secondaryCategory,
                      _emotionPercentages,
                      _tags.map((t) => t['label'].toString()).toList(),
                    );
                  } catch (e) {
                    debugPrint('Error saving diary: $e');
                    if (mounted) {
                      setState(() {
                        _isSaving = false;
                      });
                    }
                  }
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

  Widget _buildTag(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color,
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

  Widget _buildSharingContact(
    String name,
    String relation,
    IconData icon,
    bool isSwitched,
    Function(bool) onChanged,
    {String? profileImageUrl}
  ) {
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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F1EC),
              shape: BoxShape.circle,
            ),
            child: profileImageUrl != null && profileImageUrl.isNotEmpty
                ? CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFFE3E8E4),
                    backgroundImage: profileImageUrl.startsWith('data:image')
                        ? MemoryImage(base64Decode(profileImageUrl.split(',').last)) as ImageProvider
                        : NetworkImage(profileImageUrl),
                    onBackgroundImageError: (error, stackTrace) {},
                  )
                : Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: GoogleFonts.outfit(fontSize: 18, color: primaryGreen, fontWeight: FontWeight.bold),
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: GoogleFonts.outfit(
                        fontSize: 16, fontWeight: FontWeight.w600, color: textColorMain)),
                Text(relation,
                    style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[400],
                        letterSpacing: 0.5)),
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
