import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Design tokens: Trust-Bank-style dark fintech (UI.pdf palette). Semantic colours keep one meaning each.
const cPage = Color(0xFF0F121B), cSurface = Color(0xFF171B27), cRaised = Color(0xFF1E2333);
const cInk = Color(0xFFF1F3F9), cMuted = Color(0xFF8F95A6), cLine = Color(0xFF262B3B);
const cActive = Color(0xFF4C61F0), cActiveTint = Color(0xFF1D2347), cViolet = Color(0xFF7462F9), cCyan = Color(0xFF4FC3FF);
const cNavy = Color(0xFF4C61F0), cConsole = Color(0xFF0A0C13);
const cPass = Color(0xFF59CFAC), cPassTint = Color(0xFF14302B);
const cBlock = Color(0xFFFF5756), cBlockTint = Color(0xFF3A1B20);
const cHold = Color(0xFFF5A524), cHoldTint = Color(0xFF3A2C12);
const cIdle = Color(0xFF6B7180), cIdleTint = Color(0xFF1B1F2C);

const heroGradient = LinearGradient(
    colors: [Color(0xFF7462F9), Color(0xFF4C61F0), Color(0xFF13C1FB)], begin: Alignment.topLeft, end: Alignment.bottomRight);

TextStyle sans({double size = 14, FontWeight w = FontWeight.w400, Color c = cInk}) =>
    GoogleFonts.inter(fontSize: size, fontWeight: w, color: c, letterSpacing: size >= 20 ? -0.3 : 0);
TextStyle mono({double size = 13, FontWeight w = FontWeight.w400, Color c = cInk}) =>
    GoogleFonts.jetBrainsMono(fontSize: size, fontWeight: w, color: c);
TextStyle kpi(Color c) => GoogleFonts.inter(
    fontSize: 28, fontWeight: FontWeight.w700, color: c, letterSpacing: -0.5, fontFeatures: const [FontFeature.tabularFigures()]);

ThemeData appTheme() => ThemeData(
      scaffoldBackgroundColor: cPage,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(seedColor: cActive, brightness: Brightness.dark, primary: cActive, surface: cSurface),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      useMaterial3: true,
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? null : cLine),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );

BoxDecoration card({Color color = cSurface, Color border = cLine, double r = 16}) => BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(r),
    border: Border.all(color: border, width: 1),
    boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 6))]);

Color verdictColor(String? v) => switch (v) {
      'PASS' || 'ALLOW' => cPass,
      'BLOCK' || 'DENY' => cBlock,
      'INFO' => cActive,
      _ => cIdle,
    };
Color verdictTint(String? v) => switch (v) {
      'PASS' || 'ALLOW' => cPassTint,
      'BLOCK' || 'DENY' => cBlockTint,
      _ => cIdleTint,
    };

String euro(num? cents) {
  final c = (cents ?? 0).round();
  final s = (c ~/ 100).toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  final rest = c % 100;
  return rest == 0 ? '€$s' : '€$s.${rest.toString().padLeft(2, '0')}';
}

String hms(dynamic ts) {
  if (ts is! Timestamp) return '--:--:--';
  final d = ts.toDate().toLocal();
  String p(int n) => n.toString().padLeft(2, '0');
  return '${p(d.hour)}:${p(d.minute)}:${p(d.second)}';
}

String maskIban(String? iban) {
  final s = (iban ?? '').replaceAll(' ', '');
  return s.length > 8 ? '${s.substring(0, 4)}…${s.substring(s.length - 4)}' : '…';
}

final db = FirebaseFirestore.instance;
Stream<Map<String, dynamic>> docStream(String path) => db.doc(path).snapshots().map((s) => s.data() ?? {});

Widget chip(String text, Color fg, Color bg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: sans(size: 11.5, w: FontWeight.w600, c: fg)),
    );

class Stamp extends StatelessWidget {
  final String text;
  const Stamp(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: -8 * 3.14159 / 180,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          decoration: BoxDecoration(border: Border.all(color: cBlock, width: 4), borderRadius: BorderRadius.circular(8)),
          child: Text(text,
              style: GoogleFonts.ibmPlexSansCondensed(
                  fontSize: 44, fontWeight: FontWeight.w700, color: cBlock, letterSpacing: 4)),
        ),
      );
}
