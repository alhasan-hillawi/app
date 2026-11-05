import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// ويدجت احترافي متقدم لعرض روابط الويب الحية ومقاطع وقنوات يوتيوب مع تشغيل الفيديو والصوت تلقائياً
/// يدعم شاشات العرض الرقمية (Digital Signage OS) عبر Android و iOS و macOS ومتصفحات Web.
class WebViewSignageWidget extends StatefulWidget {
  final String url;
  final String? htmlContent;
  final int refreshIntervalSeconds;

  const WebViewSignageWidget({
    super.key,
    required this.url,
    this.htmlContent,
    this.refreshIntervalSeconds = 0,
  });

  @override
  State<WebViewSignageWidget> createState() => _WebViewSignageWidgetState();
}

class _WebViewSignageWidgetState extends State<WebViewSignageWidget> {
  WebViewController? _controller;
  bool _hasError = false;
  String? _lastErrorMessage;
  Timer? _reloadTimer;
  Timer? _autoRetryTimer;
  int _retryCountdown = 15;

  // معرف مستعرض سطح مكتب حديث لتفادي حظر YouTube أو لوحات التحكم
  static const String _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  /// التأكد من تهيئة وتسجيل منصة الويب دون المساس بـ Platform على الويب
  static void ensureWebViewPlatform() {
    // على بيئة الويب (Flutter Web)، يتم تسجيل WebWebViewPlatform تلقائياً
    if (kIsWeb) return;

    if (WebViewPlatform.instance != null) return;

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        AndroidWebViewPlatform.registerWith();
        return;
      }
    } catch (e) {
      debugPrint('[WebViewSignage] Android platform register note: $e');
    }

    try {
      if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
        WebKitWebViewPlatform.registerWith();
        return;
      }
    } catch (e) {
      debugPrint('[WebViewSignage] WebKit platform register note: $e');
    }

    // احتياطاً: محاولة تسجيل المنصة المتاحة تلقائياً
    try {
      WebKitWebViewPlatform.registerWith();
    } catch (_) {
      try {
        AndroidWebViewPlatform.registerWith();
      } catch (_) {}
    }
  }

  /// استخراج معرف فيديو يوتيوب من أي صيغة رابط ممكنة (عادي، مختصر، بث مباشر، أو تضمين)
  static String? extractYouTubeVideoId(String rawUrl) {
    final clean = rawUrl.trim();
    if (clean.isEmpty) return null;

    final regExp = RegExp(
      r'(?:youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?|live|shorts)\/|\S*?[?&]v=)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(clean);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    return null;
  }

  /// تطبيع روابط الويب العامة وإضافة البروتوكول إن لم يتوفر
  static String normalizeWebUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return trimmed;
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return 'https://$trimmed';
    }
    return trimmed;
  }

  void _initializeWebView() {
    ensureWebViewPlatform();

    if (!kIsWeb && WebViewPlatform.instance == null) {
      debugPrint('[WebViewSignage] WebViewPlatform.instance is null after ensureWebViewPlatform');
      if (mounted) {
        setState(() {
          _hasError = true;
          _lastErrorMessage =
              "محرك المتصفح يتطلب إعادة تشغيل التطبيق بالكامل (أوقف التطبيق ثم أعد تشغيله لتضمين مكتبات الويب الجديدة).";
        });
      }
      return;
    }

    try {
      late final PlatformWebViewControllerCreationParams params;
      if (!kIsWeb && WebViewPlatform.instance is WebKitWebViewPlatform) {
        params = WebKitWebViewControllerCreationParams(
          allowsInlineMediaPlayback: true,
          mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
        );
      } else if (!kIsWeb && WebViewPlatform.instance is AndroidWebViewPlatform) {
        params = AndroidWebViewControllerCreationParams();
      } else {
        params = const PlatformWebViewControllerCreationParams();
      }

      final controller = WebViewController.fromPlatformCreationParams(params)
        ..setJavaScriptMode(JavaScriptMode.unrestricted);

      if (!kIsWeb) {
        controller.setUserAgent(_desktopUserAgent);
        try {
          controller.setBackgroundColor(const Color(0xFF0F172A));
        } catch (_) {
          // macOS قد لا يدعم setBackgroundColor في بعض الإصدارات القديمة، يتم تجاوزها بأمان
        }
      }

      controller.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            debugPrint('[WebViewSignage] Page started: $url');
          },
          onPageFinished: (String url) {
            debugPrint('[WebViewSignage] Page finished: $url');
            if (mounted) {
              setState(() {
                _hasError = false;
                _lastErrorMessage = null;
              });
              _autoRetryTimer?.cancel();
            }
            if (!kIsWeb) {
              _injectSignageEnhancements();
            }
          },
          onWebResourceError: (WebResourceError error) {
            // تجاهل أخطاء الموارد الفرعية (الإعلانات، التراكرز، الخطوط)
            if (error.isForMainFrame != true) {
              debugPrint('[WebViewSignage] Ignored sub-resource error: ${error.errorCode} - ${error.description}');
              return;
            }

            // تجاهل إلغاء الطلبات الناتج عن إعادة التوجيه الداخلي
            if (error.errorCode == -1 || error.description.contains('ERR_ABORTED')) {
              debugPrint('[WebViewSignage] Navigation redirect / aborted ignored: ${error.description}');
              return;
            }

            debugPrint('[WebViewSignage] Main frame error: ${error.errorCode} - ${error.description}');
            if (mounted) {
              setState(() {
                _hasError = true;
                _lastErrorMessage = error.description;
              });
              _startAutoRetryCountdown();
            }
          },
        ),
      );

      // تفعيل تشغيل الوسائط والصوت تلقائياً على نظام أندرويد
      if (!kIsWeb && controller.platform is AndroidWebViewController) {
        final androidController = controller.platform as AndroidWebViewController;
        androidController.setMediaPlaybackRequiresUserGesture(false);
        androidController.setOnPlatformPermissionRequest((request) => request.grant());
      }

      _controller = controller;
      _loadContent();
      _setupRefreshTimer();
    } catch (e, stack) {
      debugPrint('[WebViewSignage] Exception during controller init: $e\n$stack');
      if (mounted) {
        setState(() {
          _hasError = true;
          _lastErrorMessage = "تعذر تهيئة محرك المتصفح على هذا الجهاز: $e";
        });
      }
    }
  }

  void _loadContent() {
    if (_controller == null) return;
    _autoRetryTimer?.cancel();

    // 1. إذا كان المحتوى كود HTML مخصص
    if (widget.htmlContent != null && widget.htmlContent!.trim().isNotEmpty) {
      _controller!.loadHtmlString(widget.htmlContent!);
      return;
    }

    // 2. إذا كان الرابط هو مقطع أو بث يوتيوب: تحميل رابط التضمين المباشر عبر loadRequest (يمنع أخطاء 153 و 152-4)
    final videoId = extractYouTubeVideoId(widget.url);
    if (videoId != null && videoId.isNotEmpty) {
      final embedUrl =
          'https://www.youtube-nocookie.com/embed/$videoId?autoplay=1&mute=0&controls=0&loop=1&playlist=$videoId&playsinline=1&rel=0&modestbranding=1&enablejsapi=1&iv_load_policy=3&disablekb=1&fs=0';
      debugPrint('[WebViewSignage] Loading direct YouTube embed URL (anti-152/153): $embedUrl');
      _controller!.loadRequest(
        Uri.parse(embedUrl),
        headers: const {
          'Referer': 'https://www.youtube-nocookie.com',
        },
      );
      return;
    }

    // 3. لأي موقع ويب حي أو تطبيق لوحة معلومات عام
    final targetUrl = normalizeWebUrl(widget.url);
    if (targetUrl.isNotEmpty) {
      debugPrint('[WebViewSignage] Loading live web URL: $targetUrl');
      _controller!.loadRequest(Uri.parse(targetUrl));
    }
  }

  void _setupRefreshTimer() {
    _reloadTimer?.cancel();
    if (widget.refreshIntervalSeconds > 0) {
      _reloadTimer = Timer.periodic(
        Duration(seconds: widget.refreshIntervalSeconds),
        (_) {
          debugPrint('[WebViewSignage] Auto-refreshing web view (${widget.refreshIntervalSeconds}s)');
          _controller?.reload();
        },
      );
    }
  }

  void _startAutoRetryCountdown() {
    _autoRetryTimer?.cancel();
    _retryCountdown = 15;
    _autoRetryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _retryCountdown--;
      });
      if (_retryCountdown <= 0) {
        timer.cancel();
        _retryLoad();
      }
    });
  }

  void _retryLoad() {
    _autoRetryTimer?.cancel();
    setState(() {
      _hasError = false;
    });
    if (_controller == null) {
      _initializeWebView();
    } else {
      _loadContent();
    }
  }

  /// حقن نصوص لتحسين الشاشات وإخفاء أشرطة التمرير وتشغيل الفيديو والصوت ملء الشاشة كلياً
  Future<void> _injectSignageEnhancements() async {
    if (_controller == null || kIsWeb) return;
    try {
      await _controller!.runJavaScript('''
        (function() {
          try {
            // 1. حقن قواعد CSS صارمة لملء الشاشة بالكامل (Edge-to-Edge Fullscreen) وإخفاء الحواف السوداء
            var existingStyle = document.getElementById('signage-injected-styles');
            if (!existingStyle) {
              existingStyle = document.createElement('style');
              existingStyle.id = 'signage-injected-styles';
              document.head.appendChild(existingStyle);
            }

            existingStyle.innerHTML = `
              /* إزالة أشرطة التمرير وجعل الصفحة بعرض وارتفاع الشاشة بالكامل */
              ::-webkit-scrollbar { display: none !important; }
              html, body {
                scrollbar-width: none !important;
                overflow: hidden !important;
                background: #000000 !important;
                margin: 0 !important;
                padding: 0 !important;
                width: 100vw !important;
                height: 100vh !important;
                position: fixed !important;
                top: 0 !important;
                left: 0 !important;
              }

              /* إخفاء كافة الترويسات والتراكبات وأزرار المشاركة وعلامات يوتيوب */
              .ytp-chrome-top,
              .ytp-chrome-bottom,
              .ytp-pause-overlay,
              .ytp-pause-overlay-container,
              .ytp-copylink-button,
              .ytp-watermark,
              .ytp-gradient-top,
              .ytp-gradient-bottom,
              .ytp-show-cards-title,
              .ytp-ce-element,
              .ytp-paid-content-overlay,
              .ytp-bezel,
              .ytp-bezel-text-wrapper,
              .ytp-share-button,
              .ytp-overflow-button,
              .ytp-subtitles-button,
              .ytp-embed,
              #masthead-container,
              #masthead,
              #related,
              #comments,
              #secondary,
              #below {
                display: none !important;
                opacity: 0 !important;
                visibility: hidden !important;
                pointer-events: none !important;
              }

              /* إجبار حاوية المشغل على احتلال أبعاد الشاشة 100% */
              #player,
              #player-container,
              #movie_player,
              .html5-video-player,
              .html5-video-container {
                position: fixed !important;
                top: 0 !important;
                left: 0 !important;
                width: 100vw !important;
                height: 100vh !important;
                max-width: 100vw !important;
                max-height: 100vh !important;
                margin: 0 !important;
                padding: 0 !important;
                border: none !important;
                z-index: 1 !important;
              }

              /* إجبار وسم الفيديو على ملء الشاشة كلياً بدون أي حواف أو أشرطة سوداء (BoxFit.cover) */
              video,
              video.video-stream,
              video.html5-main-video {
                position: fixed !important;
                top: 0 !important;
                left: 0 !important;
                width: 100vw !important;
                height: 100vh !important;
                max-width: 100vw !important;
                max-height: 100vh !important;
                object-fit: cover !important;
                object-position: center center !important;
                transform: none !important;
                margin: 0 !important;
                padding: 0 !important;
                z-index: 2 !important;
              }
            `;

            // 2. دالة لفرض خصائص ملء الشاشة وتجاوز أي حسابات داخلية تجريها سكربتات يوتيوب
            function enforceEdgeToEdgeFullScreen() {
              var vids = document.querySelectorAll('video');
              for (var i = 0; i < vids.length; i++) {
                var v = vids[i];
                v.style.setProperty('position', 'fixed', 'important');
                v.style.setProperty('top', '0px', 'important');
                v.style.setProperty('left', '0px', 'important');
                v.style.setProperty('width', '100vw', 'important');
                v.style.setProperty('height', '100vh', 'important');
                v.style.setProperty('max-width', '100vw', 'important');
                v.style.setProperty('max-height', '100vh', 'important');
                v.style.setProperty('object-fit', 'cover', 'important');
                v.style.setProperty('object-position', 'center center', 'important');
                v.style.setProperty('transform', 'none', 'important');
                v.style.setProperty('margin', '0px', 'important');
                v.style.setProperty('padding', '0px', 'important');
              }

              var containers = document.querySelectorAll('#player, #player-container, #movie_player, .html5-video-player, .html5-video-container');
              for (var j = 0; j < containers.length; j++) {
                var c = containers[j];
                c.style.setProperty('position', 'fixed', 'important');
                c.style.setProperty('top', '0px', 'important');
                c.style.setProperty('left', '0px', 'important');
                c.style.setProperty('width', '100vw', 'important');
                c.style.setProperty('height', '100vh', 'important');
                c.style.setProperty('max-width', '100vw', 'important');
                c.style.setProperty('max-height', '100vh', 'important');
                c.style.setProperty('margin', '0px', 'important');
                c.style.setProperty('padding', '0px', 'important');
              }
            }

            // 3. وظيفة الضغط التلقائي على أزرار الموافقة وزر التشغيل وفك كتم الصوت
            function triggerSignagePlayback() {
              enforceEdgeToEdgeFullScreen();

              // تخطي شاشات الموافقة على ملفات تعريف الارتباط من جوجل/يوتيوب إن ظهرت
              var buttons = document.querySelectorAll('button');
              for (var i = 0; i < buttons.length; i++) {
                var txt = (buttons[i].innerText || buttons[i].getAttribute('aria-label') || '').toLowerCase();
                if (txt.includes('accept') || txt.includes('agree') || txt.includes('موافق') || txt.includes('قبول')) {
                  buttons[i].click();
                }
              }

              // النقر على زر التشغيل الكبير إذا كان متوقفاً
              var bigPlay = document.querySelector('.ytp-large-play-button');
              if (bigPlay && bigPlay.offsetParent !== null) {
                bigPlay.click();
              }

              // إرسال أوامر تشغيل وفك كتم الصوت لمشغل يوتيوب
              window.postMessage('{"event":"command","func":"unMute","args":""}', '*');
              window.postMessage('{"event":"command","func":"playVideo","args":""}', '*');
              window.postMessage('{"event":"command","func":"setVolume","args":[100]}', '*');

              // تشغيل كافة وسائط الفيديو داخل الصفحة بدون كتم وبأقصى صوت
              document.querySelectorAll('video').forEach(function(vid) {
                vid.muted = false;
                vid.volume = 1.0;
                var playPromise = vid.play();
                if (playPromise !== undefined) {
                  playPromise.catch(function() {
                    // في حال حظر المتصفح للصوت بدون لمس الشاشة، يتم البدء صامتاً ثم فك الكتم فوراً
                    vid.muted = true;
                    vid.play().then(function() {
                      setTimeout(function() {
                        vid.muted = false;
                        vid.volume = 1.0;
                      }, 800);
                    });
                  });
                }
              });
            }

            // مراقبة أي تغييرات على الشجرة لعزل أي إعادة حسابات للأبعاد من قبل يوتيوب
            if (window.MutationObserver) {
              var observer = new MutationObserver(function() {
                enforceEdgeToEdgeFullScreen();
              });
              observer.observe(document.body, { attributes: true, subtree: true, attributeFilter: ['style', 'class'] });
            }

            window.addEventListener('resize', enforceEdgeToEdgeFullScreen);

            // تشغيل فوري وتكرار دوري خلال أول 8 ثوانٍ لضمان استقرار البث والشاشة الكاملة
            triggerSignagePlayback();
            var intervals = [300, 700, 1500, 3000, 5000, 8000];
            intervals.forEach(function(delay) {
              setTimeout(triggerSignagePlayback, delay);
            });
          } catch(e) {}
        })();
      ''');
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant WebViewSignageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.htmlContent != widget.htmlContent) {
      setState(() {
        _hasError = false;
      });
      _loadContent();
    }
    if (oldWidget.refreshIntervalSeconds != widget.refreshIntervalSeconds) {
      _setupRefreshTimer();
    }
  }

  @override
  void dispose() {
    _reloadTimer?.cancel();
    _autoRetryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError || _controller == null) {
      return Container(
        color: const Color(0xFF0F172A),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cloud_off_rounded, color: Colors.amber, size: 54),
                ),
                const SizedBox(height: 16),
                Text(
                  "تعذر جلب موقع الويب الحي",
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.url,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(color: Colors.white54, fontSize: 12),
                ),
                if (_lastErrorMessage != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _lastErrorMessage!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(color: Colors.redAccent.shade100, fontSize: 11),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  "إعادة المحاولة تلقائياً خلال $_retryCountdown ثوانٍ...",
                  style: GoogleFonts.cairo(color: Colors.amberAccent, fontSize: 12),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigoAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _retryLoad,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(
                    "إعادة المحاولة الآن",
                    style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Positioned.fill(
      child: WebViewWidget(controller: _controller!),
    );
  }
}
