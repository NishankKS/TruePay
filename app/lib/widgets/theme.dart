import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Design tokens (PRD §9)
const cPage = Color(0xFFEDF0F3), cSurface = Color(0xFFFFFFFF);
const cInk = Color(0xFF10213A), cMuted = Color(0xFF4E5D73), cLine = Color(0xFFD3DAE3);
const cActive = Color(0xFF1F4FD1);
const cPass = Color(0xFF0B7A55), cPassTint = Color(0xFFE7F5EF);
const cBlock = Color(0xFFC21F3A), cBlockTint = Color(0xFFFCECEF);
const cHold = Color(0xFFA35200), cHoldTint = Color(0xFFFFF4E5);
const cIdle = Color(0xFF6B7686), cIdleTint = Color(0xFFF5F7FA);

TextStyle sans({double size = 14, FontWeight w = FontWeight.w400, Color c = cInk}) =>
    GoogleFonts.ibmPlexSans(fontSize: size, fontWeight: w, color: c);
TextStyle mono({double size = 13, FontWeight w = FontWeight.w400, Color c = cInk}) =>
    GoogleFonts.ibmPlexMono(fontSize: size, fontWeight: w, color: c);
TextStyle kpi(Color c) => GoogleFonts.ibmPlexSans(
    fontSize: 30, fontWeight: FontWeight.w600, color: c, fontFeatures: const [FontFeature.tabularFigures()]);

ThemeData appTheme() => ThemeData(
      scaffoldBackgroundColor: cPage,
      colorScheme: ColorScheme.fromSeed(seedColor: cActive, surface: cSurface),
      textTheme: GoogleFonts.ibmPlexSansTextTheme(),
      useMaterial3: true,
    );

BoxDecoration card({Color color = cSurface, Color border = cLine, double r = 14}) => BoxDecoration(
    color: color, borderRadius: BorderRadius.circular(r), border: Border.all(color: border, width: 1));

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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: mono(size: 12.5, w: FontWeight.w600, c: fg)),
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
