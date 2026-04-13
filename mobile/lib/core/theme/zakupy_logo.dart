import 'package:flutter/material.dart';

class ZakupyLogo extends StatelessWidget {
  const ZakupyLogo({this.size = 88, this.showGlow = true, super.key});

  final double size;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.3);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF15171C), Color(0xFF050608)],
        ),
        border: Border.all(
          color: const Color(0xFF5EE0A2).withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: showGlow
                ? const Color(0xFF10B96B).withValues(alpha: 0.22)
                : Colors.black.withValues(alpha: 0.14),
            blurRadius: size * 0.18,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.16),
        child: CustomPaint(painter: _ZakupyLogoPainter()),
      ),
    );
  }
}

class _ZakupyLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final panelRect = Rect.fromLTWH(
      size.width * 0.08,
      size.height * 0.08,
      size.width * 0.84,
      size.height * 0.84,
    );
    final panel = RRect.fromRectAndRadius(
      panelRect,
      Radius.circular(size.width * 0.18),
    );
    final panelPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF071712), Color(0xFF0D372C)],
      ).createShader(panelRect);
    canvas.drawRRect(panel, panelPaint);

    final panelStroke = Paint()
      ..color = const Color(0xFF17694F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.03;
    canvas.drawRRect(panel.deflate(size.width * 0.012), panelStroke);

    final whiteLinePaint = Paint()
      ..color = const Color(0xFFF4F6FA)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.05;
    final blueStrokePaint = Paint()
      ..color = const Color(0xFF23D88A)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.04
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final accentFill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2BE39A), Color(0xFF0FA35F)],
      ).createShader(panelRect);

    final left = size.width * 0.24;
    final top = size.height * 0.27;
    final unit = size.width;

    final cartBody = Path()
      ..moveTo(left, top)
      ..lineTo(left + unit * 0.11, top)
      ..quadraticBezierTo(
        left + unit * 0.145,
        top,
        left + unit * 0.152,
        top + unit * 0.035,
      )
      ..lineTo(left + unit * 0.35, top + unit * 0.035)
      ..lineTo(left + unit * 0.35, top + unit * 0.28)
      ..lineTo(left + unit * 0.255, top + unit * 0.28)
      ..lineTo(left + unit * 0.205, top + unit * 0.35)
      ..quadraticBezierTo(
        left + unit * 0.17,
        top + unit * 0.4,
        left + unit * 0.19,
        top + unit * 0.445,
      )
      ..lineTo(left + unit * 0.35, top + unit * 0.445)
      ..lineTo(left + unit * 0.35, top + unit * 0.5)
      ..lineTo(left + unit * 0.16, top + unit * 0.5)
      ..quadraticBezierTo(
        left + unit * 0.09,
        top + unit * 0.5,
        left + unit * 0.065,
        top + unit * 0.455,
      )
      ..quadraticBezierTo(
        left + unit * 0.03,
        top + unit * 0.39,
        left + unit * 0.09,
        top + unit * 0.31,
      )
      ..lineTo(left + unit * 0.15, top + unit * 0.255)
      ..lineTo(left + unit * 0.09, top + unit * 0.04)
      ..lineTo(left, top + unit * 0.04)
      ..quadraticBezierTo(
          left - unit * 0.035, top + unit * 0.04, left - unit * 0.035, top)
      ..quadraticBezierTo(left - unit * 0.035, top - unit * 0.04, left, top)
      ..close();
    canvas.drawPath(cartBody, accentFill);

    canvas.drawCircle(
      Offset(left + unit * 0.11, top + unit * 0.59),
      unit * 0.06,
      accentFill,
    );
    canvas.drawCircle(
      Offset(left + unit * 0.31, top + unit * 0.59),
      unit * 0.06,
      accentFill,
    );

    final checks = <double>[
      size.height * 0.38,
      size.height * 0.51,
      size.height * 0.64,
    ];
    for (final y in checks) {
      final check = Path()
        ..moveTo(size.width * 0.52, y)
        ..lineTo(size.width * 0.57, y + size.width * 0.05)
        ..lineTo(size.width * 0.66, y - size.width * 0.06);
      canvas.drawPath(check, blueStrokePaint);
      canvas.drawLine(
        Offset(size.width * 0.74, y),
        Offset(size.width * 0.9, y),
        whiteLinePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
