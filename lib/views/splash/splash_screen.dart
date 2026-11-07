import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../player/signage_player_screen.dart';
import '../setup/pairing_screen.dart';

class SplashScreen extends StatefulWidget {
  final ApiService apiService;
  final Widget? nextScreen;
  final Duration minDuration;

  const SplashScreen({
    super.key,
    required this.apiService,
    this.nextScreen,
    this.minDuration = const Duration(milliseconds: 3200),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _pulseController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _glowFade;
  late final Animation<double> _titleSlide;
  late final Animation<double> _titleFade;
  late final Animation<double> _subtitleSlide;
  late final Animation<double> _subtitleFade;
  late final Animation<double> _badgeSlide;
  late final Animation<double> _badgeFade;
  late final Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();

    // متحكم حركة الدخول المتسلسلة (Entrance)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // متحكم النبض المستمر للشعار والهالة النيونية (Breathing / Pulse)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    // حركات الشعار
    _logoScale = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );

    _glowFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.1, 0.70, curve: Curves.easeInOut),
      ),
    );

    // حركة العنوان الرئيسي "سٌحبْ"
    _titleSlide = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.35, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.35, 0.70, curve: Curves.easeOut),
      ),
    );

    // حركة الوصف "منظومة ادارة الشاشات وبث الطوارئ"
    _subtitleSlide = Tween<double>(begin: 25.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.50, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.50, 0.82, curve: Curves.easeOut),
      ),
    );

    // حركة رابط الموقع "www.sohob.dev"
    _badgeSlide = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.65, 0.95, curve: Curves.easeOutCubic),
      ),
    );

    _badgeFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.65, 0.95, curve: Curves.easeOut),
      ),
    );

    // شريط التقدم النيوني
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.20, 1.0, curve: Curves.easeInOutCubic),
      ),
    );

    _entranceController.forward();

    // الانتقال بعد انتهاء المدة المحددة والتحقق من التوكن
    _startTransitionTimer();
  }

  Future<void> _startTransitionTimer() async {
    final startTime = DateTime.now();

    // التحقق من حالة التوكن وتجهيز الشاشة التالية في الخلفية
    Widget targetScreen = widget.nextScreen ?? const SizedBox();
    if (widget.nextScreen == null) {
      final hasToken = await widget.apiService.hasToken();
      if (!hasToken) {
        targetScreen = PairingScreen(apiService: widget.apiService);
      } else {
        targetScreen = SignagePlayerScreen(apiService: widget.apiService);
      }
    }

    final elapsed = DateTime.now().difference(startTime);
    final remaining = widget.minDuration - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 900),
        pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
          return FadeTransition(
            opacity: curved,
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B18),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final shortestSide = math.min(width, height);

          // حسابات أحجام ديناميكية متوافقة مع شاشات التلفزيون والأجهزة اللوحية والمحاذاة الرأسية
          final isPortrait = height > width;
          final logoSize = (shortestSide * (isPortrait ? 0.38 : 0.30)).clamp(140.0, 320.0);
          final titleFontSize = (shortestSide * (isPortrait ? 0.095 : 0.080)).clamp(36.0, 72.0);
          final subtitleFontSize = (shortestSide * (isPortrait ? 0.040 : 0.032)).clamp(15.0, 26.0);
          final websiteFontSize = (shortestSide * (isPortrait ? 0.034 : 0.026)).clamp(13.0, 20.0);
          final spacingFactor = (height * 0.018).clamp(8.0, 24.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. خلفية متدرجة سينمائية داكنة وعميقة
              Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.0, -0.1),
                    radius: 1.1,
                    colors: [
                      Color(0xFF0F1B38), // أزرق ليلي غامق في المنتصف
                      Color(0xFF0A0F24),
                      Color(0xFF050711), // أسود فضائي عند الحواف
                    ],
                    stops: [0.0, 0.55, 1.0],
                  ),
                ),
              ),

              // 2. هالة ضوئية نيونية خلفية نابضة بألوان الشعار (Cyan / Indigo)
              AnimatedBuilder(
                animation: Listenable.merge([_glowFade, _pulseController]),
                builder: (context, _) {
                  final pulse = _pulseController.value;
                  final glowRadius = (logoSize * 1.5) + (pulse * 30);
                  final opacity = (_glowFade.value * (0.35 + (pulse * 0.18))).clamp(0.0, 1.0);

                  return Center(
                    child: Transform.translate(
                      offset: Offset(0, -spacingFactor * 2.5),
                      child: Container(
                        width: glowRadius,
                        height: glowRadius,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF00E5FF).withValues(alpha: opacity),
                              const Color(0xFF7C3AED).withValues(alpha: opacity * 0.5),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.45, 1.0],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // 3. المحتوى الرئيسي في المنتصف
              Center(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // أ. الشعار مع الحركة المركبة والنبض الهادئ
                        AnimatedBuilder(
                          animation: Listenable.merge([_entranceController, _pulseController]),
                          builder: (context, child) {
                            final pulseScale = 1.0 + (_pulseController.value * 0.035);
                            return Transform.scale(
                              scale: _logoScale.value * pulseScale,
                              child: Opacity(
                                opacity: _logoFade.value,
                                child: child,
                              ),
                            );
                          },
                          child: Container(
                            width: logoSize,
                            height: logoSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00E5FF).withValues(alpha: 0.30),
                                  blurRadius: 40,
                                  spreadRadius: 8,
                                ),
                                BoxShadow(
                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                                  blurRadius: 65,
                                  spreadRadius: 15,
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/images/sohob_logo.png',
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                        ),

                        SizedBox(height: spacingFactor * 1.6),

                        // ب. كلمة "سٌحبْ" بخط كايرو العريض مع تأثير توهج نيون راقٍ
                        AnimatedBuilder(
                          animation: _entranceController,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, _titleSlide.value),
                              child: Opacity(
                                opacity: _titleFade.value,
                                child: child,
                              ),
                            );
                          },
                          child: Text(
                            'سٌحبْ',
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            style: GoogleFonts.cairo(
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.5,
                              height: 1.2,
                              shadows: [
                                Shadow(
                                  color: const Color(0xFF00E5FF).withValues(alpha: 0.85),
                                  blurRadius: 22,
                                  offset: const Offset(0, 0),
                                ),
                                Shadow(
                                  color: const Color(0xFF38BDF8).withValues(alpha: 0.60),
                                  blurRadius: 40,
                                  offset: const Offset(0, 2),
                                ),
                                const Shadow(
                                  color: Colors.black87,
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: spacingFactor * 0.7),

                        // ج. عبارة "منظومة ادارة الشاشات وبث الطوارئ" بخط كايرو متناسق وواضح
                        AnimatedBuilder(
                          animation: _entranceController,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, _subtitleSlide.value),
                              child: Opacity(
                                opacity: _subtitleFade.value,
                                child: child,
                              ),
                            );
                          },
                          child: Text(
                            'منظومة ادارة الشاشات وبث الطوارئ',
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            style: GoogleFonts.cairo(
                              fontSize: subtitleFontSize,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFE2E8F0),
                              letterSpacing: 0.8,
                              height: 1.35,
                              shadows: [
                                Shadow(
                                  color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                                  blurRadius: 14,
                                  offset: const Offset(0, 0),
                                ),
                                const Shadow(
                                  color: Colors.black87,
                                  blurRadius: 10,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: spacingFactor * 1.2),

                        // خط فاصل مضيء ناعم
                        AnimatedBuilder(
                          animation: _entranceController,
                          builder: (context, child) {
                            return Opacity(
                              opacity: _subtitleFade.value,
                              child: Container(
                                width: (shortestSide * 0.28).clamp(80.0, 160.0),
                                height: 2.0,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Color(0xFF00E5FF),
                                      Color(0xFF818CF8),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        SizedBox(height: spacingFactor * 1.2),

                        // د. شارة الموقع الإلكتروني "www.sohob.dev" بأسلوب نيون تقني مميز
                        AnimatedBuilder(
                          animation: _entranceController,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, _badgeSlide.value),
                              child: Opacity(
                                opacity: _badgeFade.value,
                                child: child,
                              ),
                            );
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: (shortestSide * 0.040).clamp(16.0, 32.0),
                              vertical: (shortestSide * 0.016).clamp(8.0, 14.0),
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A1329).withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(40),
                              border: Border.all(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.50),
                                width: 1.4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00E5FF).withValues(alpha: 0.20),
                                  blurRadius: 18,
                                  spreadRadius: 1,
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.language_rounded,
                                  size: websiteFontSize * 1.15,
                                  color: const Color(0xFF00E5FF),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'www.sohob.dev',
                                  textDirection: TextDirection.ltr,
                                  style: GoogleFonts.cairo(
                                    fontSize: websiteFontSize,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFF1F5F9),
                                    letterSpacing: 1.2,
                                    shadows: [
                                      Shadow(
                                        color: const Color(0xFF00E5FF).withValues(alpha: 0.65),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 4. شريط مؤشر التقدم النيوني الأنيق أسفل الشاشة
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, _) {
                    return Container(
                      height: 3.5,
                      alignment: Alignment.centerLeft,
                      color: Colors.white.withValues(alpha: 0.05),
                      child: FractionallySizedBox(
                        widthFactor: _progressAnimation.value,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF7C3AED),
                                Color(0xFF00E5FF),
                                Color(0xFF38BDF8),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF00E5FF),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
