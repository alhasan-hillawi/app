import 'package:flutter/material.dart';
import '../../../models/split_screen_model.dart';
import 'zone_media_slot_widget.dart';

class SplitScreenMultiVideoWidget extends StatefulWidget {
  final SplitScreenSlide slide;
  final VoidCallback? onSlideCompleted;

  const SplitScreenMultiVideoWidget({
    super.key,
    required this.slide,
    this.onSlideCompleted,
  });

  @override
  State<SplitScreenMultiVideoWidget> createState() => _SplitScreenMultiVideoWidgetState();
}

class _SplitScreenMultiVideoWidgetState extends State<SplitScreenMultiVideoWidget> {
  // مؤشر الزون الذي يمتلك الصوت النشط حالياً (الافتراضي: الزون رقم 0)
  int _activeAudioIndex = 0;

  void _switchAudioToZone(int index) {
    setState(() {
      _activeAudioIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final zones = widget.slide.zones;
    final layout = widget.slide.layout.toLowerCase().trim();

    if (zones.isEmpty) {
      return Container(
        color: const Color(0xFF020617),
        child: const Center(
          child: Text("لا توجد مقاطع مخصصة لهذه الشاشة المقسمة", style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    return Container(
      color: const Color(0xFF020617),
      child: LayoutBuilder(
        builder: (context, constraints) {
          switch (layout) {
            // ==========================================
            // النمط 1: تقسيم رأسي متساوٍ (عمودين 50/50)
            // ==========================================
            case 'split_2_vertical':
            case '2_vertical':
            case 'two_columns':
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildSlot(zones, 0),
                  ),
                  _buildBezelDivider(isVertical: true),
                  Expanded(
                    child: _buildSlot(zones, 1),
                  ),
                ],
              );

            // ==========================================
            // النمط 2: تقسيم أفقي متساوٍ (صفين 50/50)
            // ==========================================
            case 'split_2_horizontal':
            case '2_horizontal':
            case 'two_rows':
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildSlot(zones, 0),
                  ),
                  _buildBezelDivider(isVertical: false),
                  Expanded(
                    child: _buildSlot(zones, 1),
                  ),
                ],
              );

            // ==========================================
            // النمط 3: فيديو رئيسي كبير + فيديوهان جانبيان
            // ==========================================
            case 'split_3_main_side':
            case '3_main_side':
            case 'main_two_side':
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // النصف الرئيسي: الفيديو الأول (يشغل كامل الارتفاع و 60% من العرض)
                  Expanded(
                    flex: 6,
                    child: _buildSlot(zones, 0),
                  ),
                  _buildBezelDivider(isVertical: true),
                  // النصف الجانبي: فيديوهان مكدسان رأسياً (40% من العرض)
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _buildSlot(zones, 1),
                        ),
                        _buildBezelDivider(isVertical: false),
                        Expanded(
                          child: _buildSlot(zones, 2),
                        ),
                      ],
                    ),
                  ),
                ],
              );

            // ==========================================
            // النمط 4: شبكة متوازية من 4 أرباع (2x2 Grid)
            // ==========================================
            case 'split_4_grid':
            case '4_grid':
            case 'grid_4':
            case 'quad':
            default:
              // إذا كان هناك منطقتين فقط وجاء النمط الافتراضي
              if (zones.length == 2 && layout != 'split_4_grid') {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildSlot(zones, 0)),
                    _buildBezelDivider(isVertical: true),
                    Expanded(child: _buildSlot(zones, 1)),
                  ],
                );
              }

              // شبكة 2x2
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // الصف العلوي (فيديو 1 وفيديو 2)
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _buildSlot(zones, 0)),
                        _buildBezelDivider(isVertical: true),
                        Expanded(child: _buildSlot(zones, 1)),
                      ],
                    ),
                  ),
                  _buildBezelDivider(isVertical: false),
                  // الصف السفلي (فيديو 3 وفيديو 4)
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _buildSlot(zones, 2)),
                        _buildBezelDivider(isVertical: true),
                        Expanded(child: _buildSlot(zones, 3)),
                      ],
                    ),
                  ),
                ],
              );
          }
        },
      ),
    );
  }

  // بناء خانة الفيديو مع مؤشر الصوت وشريط معلومات الزون
  Widget _buildSlot(List<SplitZone> zones, int index) {
    if (index >= zones.length) {
      return Container(
        color: const Color(0xFF0F172A),
        child: Center(
          child: Text(
            "جزء ${index + 1} (فارغ)",
            style: const TextStyle(color: Colors.white24, fontSize: 12),
          ),
        ),
      );
    }

    final zone = zones[index];
    final hasAudio = _activeAudioIndex == index;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _switchAudioToZone(index),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // مشغل الوسائط المستقل للزون
          ZoneMediaSlotWidget(
            key: ValueKey("zone_${zone.id}_${zone.url}"),
            zone: zone,
            isAudioEnabled: hasAudio,
          ),

          // شارة رقم الزون وحالة الصوت في الزاوية
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasAudio ? Colors.greenAccent : Colors.white12,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasAudio ? Icons.volume_up : Icons.volume_off,
                    color: hasAudio ? Colors.greenAccent : Colors.white38,
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    zone.title.isNotEmpty ? zone.title : "جزء ${index + 1}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // فاصل إطار الشاشات (Bezel Divider)
  Widget _buildBezelDivider({required bool isVertical}) {
    return Container(
      width: isVertical ? 2 : double.infinity,
      height: isVertical ? double.infinity : 2,
      color: const Color(0xFF000000),
    );
  }
}
