import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/pin_security_service.dart';

/// نافذة التحقق من رمز PIN لفتح الإعدادات ومنع التلاعب
class PinVerificationDialog extends StatefulWidget {
  const PinVerificationDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const PinVerificationDialog(),
    );
    return result ?? false;
  }

  @override
  State<PinVerificationDialog> createState() => _PinVerificationDialogState();
}

class _PinVerificationDialogState extends State<PinVerificationDialog> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _errorMessage;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final pin = _pinController.text.trim();
    if (pin.length != 4) {
      setState(() => _errorMessage = "يرجى إدخال 4 أرقام كاملة");
      return;
    }

    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });

    final isValid = await PinSecurityService().verifyPin(pin);
    if (!mounted) return;

    if (isValid) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _isChecking = false;
        _errorMessage = "رمز PIN غير صحيح، حاول مرة أخرى";
        _pinController.clear();
      });
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth * 0.85).clamp(300.0, 420.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: const Color(0xFF0F172A),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: dialogWidth,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.35), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
              blurRadius: 25,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_outline_rounded, color: Color(0xFF00E5FF), size: 22),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "قفل حماية الإعدادات",
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => Navigator.pop(context, false),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 24),

            Text(
              "أدخل رمز PIN المكون من 4 أرقام للوصول إلى لوحة الإعدادات:",
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(color: const Color(0xFF94A3B8), fontSize: 12),
            ),
            const SizedBox(height: 18),

            // حقل إدخال PIN المكون من 4 أرقام
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF070B18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _errorMessage != null ? Colors.redAccent : const Color(0xFF00E5FF).withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: _pinController,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                obscureText: true,
                obscuringCharacter: '●',
                textAlign: TextAlign.center,
                maxLength: 4,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                style: GoogleFonts.cairo(
                  fontSize: 26,
                  letterSpacing: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF00F0FF),
                ),
                decoration: const InputDecoration(
                  counterText: "",
                  hintText: "••••",
                  hintStyle: TextStyle(fontSize: 22, letterSpacing: 10, color: Colors.white24),
                  contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _verify(),
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context, false),
                    child: Text("إلغاء", style: GoogleFonts.cairo(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isChecking ? null : _verify,
                    child: _isChecking
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : Text(
                            "فتح الإعدادات",
                            style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// نافذة تغيير رمز PIN للحماية من داخل الإعدادات
class PinChangeDialog extends StatefulWidget {
  const PinChangeDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const PinChangeDialog(),
    );
    return result ?? false;
  }

  @override
  State<PinChangeDialog> createState() => _PinChangeDialogState();
}

class _PinChangeDialogState extends State<PinChangeDialog> {
  final TextEditingController _currentPinController = TextEditingController();
  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  String? _errorMessage;
  bool _isSaving = false;

  @override
  void dispose() {
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _submitChange() async {
    final current = _currentPinController.text.trim();
    final newPin = _newPinController.text.trim();
    final confirm = _confirmPinController.text.trim();

    if (current.length != 4 || newPin.length != 4 || confirm.length != 4) {
      setState(() => _errorMessage = "يجب أن يتكون كل حقل من 4 أرقام بالضبط");
      return;
    }

    if (newPin != confirm) {
      setState(() => _errorMessage = "الرمز الجديد وتأكيد الرمز غير متطابقين");
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final success = await PinSecurityService().changePin(current, newPin);
    if (!mounted) return;

    if (success) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _isSaving = false;
        _errorMessage = "رمز PIN الحالي غير صحيح";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth * 0.88).clamp(320.0, 440.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFF0F172A),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: dialogWidth,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3), width: 1.2),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.pin_rounded, color: Color(0xFF00E5FF), size: 22),
                      const SizedBox(width: 8),
                      Text(
                        "تغيير رمز PIN للحماية",
                        style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context, false),
                    child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 22),

              _buildField("رمز PIN الحالي (4 أرقام):", _currentPinController),
              const SizedBox(height: 12),
              _buildField("رمز PIN الجديد (4 أرقام):", _newPinController),
              const SizedBox(height: 12),
              _buildField("تأكيد رمز PIN الجديد:", _confirmPinController),

              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: Text("إلغاء", style: GoogleFonts.cairo(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isSaving ? null : _submitChange,
                      child: _isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : Text("حفظ الرمز الجديد", style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold)),
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

  Widget _buildField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.cairo(color: const Color(0xFFCBD5E1), fontSize: 11.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF070B18),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            obscureText: true,
            obscuringCharacter: '●',
            textAlign: TextAlign.center,
            maxLength: 4,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            style: GoogleFonts.cairo(fontSize: 18, letterSpacing: 8, color: const Color(0xFF00E5FF), fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              counterText: "",
              hintText: "••••",
              hintStyle: TextStyle(fontSize: 16, letterSpacing: 6, color: Colors.white24),
              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}
