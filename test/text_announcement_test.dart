import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signage_player/models/text_announcement_model.dart';
import 'package:signage_player/models/signage_models.dart';
import 'package:signage_player/views/player/widgets/text_announcement_slide_widget.dart';

void main() {
  group('TextAnnouncementSlide Serialization Tests', () {
    test('Parses server API JSON payload accurately', () {
      final json = {
        "id": 104,
        "type": "announcement",
        "title": "إعلان إداري - مواعيد شهر رمضان المبارك",
        "url": null,
        "duration": 15,
        "order": 4,
        "transition": "fade",
        "custom_content": {
          "title": "إعلان إداري هام",
          "body": "يسر إدارة الشركة أن تتقدم بأطيب التهاني بمناسبة حلول الشهر الفضيل.",
          "background_color": "#0f172a",
          "text_color": "#ffffff",
          "badge_text": "تعميم رسمي",
          "badge_color": "#4f46e5",
          "icon": "campaign"
        },
        "media": null
      };

      final slide = TextAnnouncementSlide.fromJson(json);

      expect(slide.id, 104);
      expect(slide.title, "إعلان إداري هام");
      expect(slide.body, contains("يسر إدارة الشركة"));
      expect(slide.duration, 15);
      expect(slide.backgroundColor, const Color(0xFF0F172A));
      expect(slide.textColor, const Color(0xFFFFFFFF));
      expect(slide.badgeText, "تعميم رسمي");
      expect(slide.badgeColor, const Color(0xFF4F46E5));
      expect(slide.iconType, "campaign");
    });

    test('PlaylistItemModel recognizes text and announcement slides', () {
      final textItem = PlaylistItemModel.fromJson({
        "id": 105,
        "type": "text",
        "title": "ترحيب",
        "duration": 10,
        "custom_content": {"body": "أهلاً وسهلاً"}
      });

      expect(textItem.isTextAnnouncement, isTrue);
      expect(textItem.isVideo, isFalse);
      expect(textItem.isImage, isFalse);
      expect(textItem.isWebUrl, isFalse);

      final announcementItem = PlaylistItemModel.fromJson({
        "id": 106,
        "type": "announcement",
        "title": "تنبيه",
        "duration": 20,
        "custom_content": {"body": "تنبيه هام"}
      });

      expect(announcementItem.isTextAnnouncement, isTrue);
      expect(announcementItem.isVideo, isFalse);
    });
  });

  group('TextAnnouncementSlideWidget Widget Tests', () {
    testWidgets('Renders badge, title, and body properly', (WidgetTester tester) async {
      final slide = TextAnnouncementSlide(
        id: 1,
        title: "عنوان الإعلان التجريبي",
        body: "نص الإعلان التفصيلي التوضيحي",
        duration: 5,
        backgroundColor: const Color(0xFF0F172A),
        textColor: Colors.white,
        badgeText: "تعميم عاجل",
        badgeColor: const Color(0xFF4F46E5),
        iconType: "campaign",
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextAnnouncementSlideWidget(slide: slide),
          ),
        ),
      );

      // Verify widget elements rendered
      expect(find.text("تعميم عاجل"), findsOneWidget);
      expect(find.text("عنوان الإعلان التجريبي"), findsOneWidget);
      expect(find.text("نص الإعلان التفصيلي التوضيحي"), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });
}

