import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class DigitalClockWidget extends StatefulWidget {
  final bool is24Hours;
  final bool showDate;

  const DigitalClockWidget({super.key, this.is24Hours = true, this.showDate = true});

  @override
  State<DigitalClockWidget> createState() => _DigitalClockWidgetState();
}

class _DigitalClockWidgetState extends State<DigitalClockWidget> {
  late Timer _timer;
  String _timeString = "";
  String _dateString = "";

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    final now = DateTime.now();
    // إجبار استخدام أرقام لاتينية en_US دائماً
    final timeFormat = widget.is24Hours ? DateFormat('HH:mm:ss', 'en_US') : DateFormat('hh:mm:ss a', 'en_US');
    String dateStr = "";

    try {
      dateStr = DateFormat('EEEE، d MMMM yyyy', 'ar_SA').format(now);
    } catch (_) {
      try {
        dateStr = DateFormat('yyyy-MM-dd').format(now);
      } catch (_) {
        dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      }
    }

    if (mounted) {
      setState(() {
        _timeString = timeFormat.format(now);
        _dateString = dateStr;
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _timeString,
            style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          if (widget.showDate)
            Text(
              _dateString,
              style: GoogleFonts.cairo(fontSize: 11, color: Colors.white70),
            ),
        ],
      ),
    );
  }
}
