import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'login.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _bgController;
  late AnimationController _particleController;
  late AnimationController _pulseController;

  Offset _pointerPos = Offset.zero;
  bool _isHolding = false;
  List<Particle> _particles = [];
  final math.Random _random = math.Random();

  // Unified App Colors
  final Color primaryGreen = const Color(0xFF7C9C84); // The Sage Green from your Home/Profile
  final Color textColorMain = const Color(0xFF333333);
  final Color backgroundColor = const Color(0xFFF2F1EC);

  final List<OnboardingData> _onboardingPages = [
    OnboardingData(
      title: 'Eunoia',
      subtitle: 'Beautiful Thinking.\nMindful Living.',
      icon: Icons.eco_rounded,
    ),
    OnboardingData(
      title: 'Peace',
      subtitle: 'Your personal sanctuary for\nemotional well-being.',
      icon: Icons.filter_vintage_rounded,
    ),
    OnboardingData(
      title: 'Growth',
      subtitle: 'Capture your journey and\ndiscover your best self.',
      icon: Icons.auto_awesome_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(() {
      _updateParticles();
    })..repeat();

    for (int i = 0; i < 20; i++) {
      _particles.add(Particle(_random));
    }
  }

  void _updateParticles() {
    setState(() {
      for (var p in _particles) {
        p.update();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bgController.dispose();
    _particleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _pointerPos = Offset(
              (details.localPosition.dx - MediaQuery.of(context).size.width / 2) / 60,
              (details.localPosition.dy - MediaQuery.of(context).size.height / 2) / 60,
            );
          });
        },
        child: Stack(
          children: [
            // Elegant Background Glow
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _bgController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: SoftGlowPainter(
                      color: primaryGreen.withOpacity(0.08),
                      animationValue: _bgController.value,
                    ),
                  );
                },
              ),
            ),

            // Floating Bokeh Particles
            Positioned.fill(
              child: CustomPaint(
                painter: ParticlePainter(
                  particles: _particles,
                  color: primaryGreen.withOpacity(0.12),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  // Minimalist Skip
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: TextButton(
                        onPressed: () => _navigateToLogin(),
                        child: Text(
                          'SKIP',
                          style: GoogleFonts.outfit(
                            color: primaryGreen.withOpacity(0.4),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ),

                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (int page) {
                        HapticFeedback.selectionClick();
                        setState(() => _currentPage = page);
                      },
                      itemCount: _onboardingPages.length,
                      itemBuilder: (context, index) {
                        return _buildOnboardingPage(_onboardingPages[index]);
                      },
                    ),
                  ),

                  // Bottom Navigation
                  _buildBottomControls(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingPage(OnboardingData data) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildHeroIcon(data),
        const SizedBox(height: 50),
        _buildContentText(data),
      ],
    );
  }

  Widget _buildHeroIcon(OnboardingData data) {
    return GestureDetector(
      onLongPressStart: (_) {
        setState(() => _isHolding = true);
        HapticFeedback.heavyImpact();
      },
      onLongPressEnd: (_) {
        setState(() => _isHolding = false);
        HapticFeedback.mediumImpact();
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer Breathing Ring
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 160 + (10 * _pulseController.value),
                height: 160 + (10 * _pulseController.value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: primaryGreen.withOpacity(0.05 + (0.1 * _pulseController.value)),
                    width: 1,
                  ),
                ),
              );
            },
          ),
          // Main Icon Container
          AnimatedContainer(
            duration: const Duration(milliseconds: 3000),
            curve: Curves.easeInOutSine,
            padding: EdgeInsets.all(_isHolding ? 50 : 35),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryGreen.withOpacity(_isHolding ? 0.2 : 0.05),
                  blurRadius: _isHolding ? 60 : 40,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.0, end: _isHolding ? 1.3 : 1.0),
              duration: const Duration(milliseconds: 3000),
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Transform.translate(
                    offset: _pointerPos,
                    child: Icon(
                      data.icon,
                      size: 75,
                      color: primaryGreen,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentText(OnboardingData data) {
    return Column(
      children: [
        Text(
          data.title,
          style: GoogleFonts.playfairDisplay(
            fontSize: 44,
            fontWeight: FontWeight.w600,
            color: textColorMain,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 60),
          child: Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 17,
              height: 1.6,
              color: const Color(0xFF7A8981),
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
        const SizedBox(height: 48),
        FadeTransition(
          opacity: _pulseController,
          child: Text(
            _isHolding ? 'RELEASING...' : (_currentPage == 0 ? 'HOLD TO BREATHE' : 'SWIPE TO CONTINUE'),
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: primaryGreen.withOpacity(0.5),
              letterSpacing: 4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 0, 40, 60),
      child: Column(
        children: [
          // Indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _onboardingPages.length,
                  (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 4,
                width: _currentPage == index ? 24 : 4,
                decoration: BoxDecoration(
                  color: _currentPage == index ? primaryGreen : primaryGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),

          // Primary Green Button (Matching App Theme)
          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton(
              onPressed: () {
                if (_currentPage < _onboardingPages.length - 1) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                  );
                } else {
                  _navigateToLogin();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen, // Consistent Sage Green
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 0,
                shadowColor: primaryGreen.withOpacity(0.3),
              ),
              child: Text(
                _currentPage == _onboardingPages.length - 1 ? 'BEGIN JOURNEY' : 'CONTINUE',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToLogin() {
    HapticFeedback.mediumImpact();
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const LoginPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 0.05); // Subtle slide up
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;

          var slideTween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var fadeTween = Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));

          return FadeTransition(
            opacity: animation.drive(fadeTween),
            child: SlideTransition(
              position: animation.drive(slideTween),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }
}

class SoftGlowPainter extends CustomPainter {
  final Color color;
  final double animationValue;

  SoftGlowPainter({required this.color, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);

    // Dynamic drifting light
    final double dx = size.width * 0.5 + (30 * math.sin(animationValue * 2 * math.pi));
    final double dy = size.height * 0.35 + (20 * math.cos(animationValue * 2 * math.pi));

    canvas.drawCircle(Offset(dx, dy), size.width * 0.8, paint);
  }

  @override
  bool shouldRepaint(SoftGlowPainter oldDelegate) => true;
}

class Particle {
  late double x, y, vx, vy, size;
  final math.Random random;

  Particle(this.random) {
    reset();
  }

  void reset() {
    x = random.nextDouble() * 500;
    y = random.nextDouble() * 900;
    vx = (random.nextDouble() - 0.5) * 0.15;
    vy = (random.nextDouble() - 0.5) * 0.15;
    size = random.nextDouble() * 5 + 1;
  }

  void update() {
    x += vx;
    y += vy;
    if (x < 0 || x > 500) vx *= -1;
    if (y < 0 || y > 900) vy *= -1;
  }
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final Color color;

  ParticlePainter({required this.particles, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var p in particles) {
      canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class OnboardingData {
  final String title;
  final String subtitle;
  final IconData icon;

  OnboardingData({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
