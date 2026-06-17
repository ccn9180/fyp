import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/gamification_service.dart';
import '../widgets/level_up_dialog.dart';
import 'package:fyp/services/backend_config.dart';
import '../services/crisis_service.dart';

class ActiveChatScreen extends StatefulWidget {
  const ActiveChatScreen({super.key});

  @override
  State<ActiveChatScreen> createState() => _ActiveChatScreenState();
}

class _ActiveChatScreenState extends State<ActiveChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [
    {
      "isAi": true,
      "text": "Hello. I'm here to support your mindfulness journey today. How are you feeling in this moment?",
    }
  ];
  bool _isLoading = false;
  bool _crisisDetected = false;
  String? _userProfileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          setState(() {
            _userProfileImageUrl = doc.data()?['profileImageUrl'];
          });
        }
      } catch (e) {
        debugPrint('Error loading user profile image: $e');
      }
    }
  }

  final Color primaryGreen = const Color(0xFF86A590);
  final Color backgroundColor = const Color(0xFFFBFBF6);
  final Color aiBubbleColor = Colors.white;
  final Color userBubbleColor = const Color(0xFF86A590);
  final Color textColorMain = const Color(0xFF333333);
  final Color textColorSub = const Color(0xFF888888);

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF86A590), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              'Eunoia AI',
              style: GoogleFonts.outfit(
                color: textColorMain,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF86A590),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'MINDFUL GUIDE',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFB0BDB5),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: GestureDetector(
                onTap: () => _showEndChatDialog(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFFCDD2)),
                  ),
                  child: Text(
                    'END',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFE57373),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          _buildDateDivider('TODAY'),
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              separatorBuilder: (context, index) => const SizedBox(height: 24),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(left: 40),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF86A590)),
                      ),
                    ),
                  );
                }
                final msg = _messages[index];
                if (msg['isAi'] == true) {
                  return _buildAiMessage(msg['text'] ?? '');
                } else {
                  return _buildUserMessage(msg['text'] ?? '');
                }
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({"isAi": false, "text": text});
      _isLoading = true;
    });
    _messageController.clear();
    _scrollToBottom();

    // Check for crisis in user's message
    if (CrisisService.containsCrisisKeyword(text)) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !_crisisDetected) {
        setState(() {
          _crisisDetected = true;
          _messages.add({
            "isAi": true,
            "text": "It sounds like you might be going through a tough time. We care about your safety and have notified your trusted contacts. Please consider reaching out to a professional."
          });
          _isLoading = false;
        });
        await CrisisService.triggerCrisisAlert(user.uid, 'chatbot');
        await CrisisService.sendLocalCrisisNotification();
        _scrollToBottom();
        return;
      }
    }

    try {
      final response = await BackendConfig.withRetry((baseUrl) => http.post(
        Uri.parse('$baseUrl/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': text}),
      ).timeout(const Duration(seconds: 8)));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['response'] ?? '';
        setState(() {
          _messages.add({"isAi": true, "text": reply});
        });
        
        // Scan for completion indicators
        _checkChatbotCompletion(reply);
      } else {
        setState(() {
          _messages.add({"isAi": true, "text": "Sorry, I received an error from the server."});
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({"isAi": true, "text": "Error connecting to server. Make sure the python backend is running."});
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _checkChatbotCompletion(String replyText) async {
    final lower = replyText.toLowerCase();
    
    // Check for breathing exercise completion
    bool isBreathing = lower.contains('breathing') && (lower.contains('complete') || lower.contains('finish') || lower.contains('done'));
    // Check for grounding exercise completion
    bool isGrounding = lower.contains('grounding') && (lower.contains('complete') || lower.contains('finish') || lower.contains('done'));
    // Fallback general mental exercise completion
    bool isGeneralChat = lower.contains('exercise') && (lower.contains('complete') || lower.contains('finish') || lower.contains('done'));

    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    String? taskId;
    if (isBreathing) {
      taskId = 'breathing_exercise';
    } else if (isGrounding) {
      taskId = 'grounding_exercise';
    } else if (isGeneralChat) {
      taskId = 'chatbot_chat';
    }

    if (taskId != null) {
      final res = await GamificationService.completeTask(currentUid, taskId);
      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.stars_rounded, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text('Quest Completed: +${res['xp']} XP & +${res['coins']} Coins!'),
                ],
              ),
              backgroundColor: const Color(0xFF7C9C84),
              duration: const Duration(seconds: 4),
            ),
          );
          if (res['levelled_up'] == true) {
            _showLevelUpDialog();
          }
        }
      }
    }
  }

  void _showLevelUpDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const LevelUpDialog(),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildDateDivider(String label) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFEBEBE4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: const Color(0xFF909088),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildAiMessage(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: Color(0xFF86A590),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.eco, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EUNOIA AI',
                style: GoogleFonts.outfit(
                  color: const Color(0xFFB0BDB5),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: aiBubbleColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border.all(color: const Color(0xFFEBEBE4), width: 1),
                ),
                child: Text(
                  text,
                  style: GoogleFonts.outfit(
                    color: textColorMain,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 40), // Space on the right for AI messages
      ],
    );
  }

  Widget _buildUserMessage(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const SizedBox(width: 40), // Space on the left for User messages
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'YOU',
                style: GoogleFonts.outfit(
                  color: const Color(0xFFB0BDB5),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: userBubbleColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  text,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        CircleAvatar(
          radius: 16,
          backgroundColor: const Color(0xFFF1F3EE),
          backgroundImage: _getAvatarProvider(_userProfileImageUrl),
          child: (_userProfileImageUrl == null || _userProfileImageUrl!.isEmpty)
              ? Text('U', style: GoogleFonts.outfit(color: const Color(0xFF86A590), fontWeight: FontWeight.bold))
              : null,
        ),
      ],
    );
  }

  ImageProvider? _getAvatarProvider(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('data:image')) {
      try {
        final bytes = base64Decode(url.split(',').last);
        return MemoryImage(bytes);
      } catch (_) {
        return null;
      }
    }
    return NetworkImage(url);
  }

  Widget _buildExerciseChip({required IconData icon, required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F2),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE0E6E1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF86A590), size: 24),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  color: textColorMain,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.outfit(
                  color: textColorSub,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      color: Colors.transparent,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF98B0A4).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_rounded, color: Color(0xFF86A590), size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFFEBEBE4)),
              ),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: GoogleFonts.outfit(color: const Color(0xFFB0B0B0), fontSize: 15),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _isLoading ? null : _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isLoading ? const Color(0xFFB0BDB5) : const Color(0xFF86A590),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveChatSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Simple keyword detection for tag/subTag/title
    String tag = 'FOCUSED';
    String subTag = 'Mindfulness';
    String title = 'Mindful Reflection Session';
    
    final fullText = _messages.map((m) => m['text']?.toString().toLowerCase() ?? '').join(' ');
    if (fullText.contains('anxiety') || fullText.contains('stress') || fullText.contains('overwhelm') || fullText.contains('worry') || fullText.contains('calm')) {
      tag = 'CALM';
      subTag = 'Anxiety';
      title = 'Managing Stress & Anxiety';
    } else if (fullText.contains('grateful') || fullText.contains('thankful') || fullText.contains('gratitude') || fullText.contains('bless')) {
      tag = 'GRATEFUL';
      subTag = 'Gratitude';
      title = 'Gratitude & Joy Journal';
    } else if (fullText.contains('sleep') || fullText.contains('night') || fullText.contains('insomnia') || fullText.contains('tired') || fullText.contains('rest')) {
      tag = 'SLEEPY';
      subTag = 'Sleep';
      title = 'Night Wind-down Guide';
    }

    // Generate preview: last user message or last message in general
    String preview = 'Mindfulness chat session.';
    if (_messages.isNotEmpty) {
      preview = _messages.last['text'] ?? '';
      if (preview.length > 100) {
        preview = '${preview.substring(0, 97)}...';
      }
    }

    // Get user name
    String userName = 'User';
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      userName = userDoc.data()?['fullName'] ?? user.displayName ?? 'User';
    } catch (_) {}

    final formattedMessages = _messages.map((m) => {
      'role': m['isAi'] ? 'assistant' : 'user',
      'text': m['text'],
    }).toList();

    String aiSummary = preview;
    try {
      final response = await BackendConfig.withRetry((baseUrl) => http.post(
        Uri.parse('$baseUrl/summarize_chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'messages': formattedMessages}),
      ).timeout(const Duration(seconds: 8)));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['summary'] != null && data['summary'].toString().isNotEmpty) {
          aiSummary = data['summary'];
        }
      }
    } catch (e) {
      debugPrint('Error generating chat summary: $e');
    }

    try {
      await FirebaseFirestore.instance.collection('chat_sessions').add({
        'userId': user.uid,
        'userName': userName,
        'title': title,
        'tag': tag,
        'subTag': subTag,
        'preview': preview,
        'aiSummary': aiSummary,
        'createdAt': Timestamp.now(),
        'messages': formattedMessages,
        'sharingAccess': {}, // initially not shared with anyone
        'crisisDetected': _crisisDetected,
        'crisisKeyword': _crisisDetected ? 'detected' : '',
        'status': 'Normal',
      });
    } catch (e) {
      print('Error saving chat session: $e');
    }
  }

  void _showEndChatDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEBEE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Color(0xFFE57373),
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'End Session?',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: textColorMain,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you ready to finalize this conversation? A summary will be saved to your journal.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  color: textColorSub,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        // Show loading indicator
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF86A590))),
                        );
                        await _saveChatSession();
                        if (context.mounted) {
                          Navigator.pop(context); // Pop loading
                          Navigator.pop(ctx); // Close dialog
                          Navigator.pop(context); // Close chat
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE57373),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        'END CONVERSATION',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        'CONTINUE CHATTING',
                        style: GoogleFonts.outfit(
                          color: textColorSub,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
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
}
