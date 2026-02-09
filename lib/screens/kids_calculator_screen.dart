import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../services/theme_service.dart';

class KidsCalculatorScreen extends StatefulWidget {
  const KidsCalculatorScreen({super.key});

  @override
  State<KidsCalculatorScreen> createState() => _KidsCalculatorScreenState();
}

class _KidsCalculatorScreenState extends State<KidsCalculatorScreen> {
  String _display = '';
  String _explanation = '';
  String _emoji = '🤔';

  void _onButton(String value) {
    setState(() {
      if (value == 'C') {
        _display = '';
        _explanation = '';
        _emoji = '🤔';
      } else if (value == '⌫') {
        if (_display.isNotEmpty) {
          _display = _display.substring(0, _display.length - 1);
        }
      } else if (value == '.') {
        // Only allow one decimal per number segment
        final parts = _display.split(RegExp(r'[+\-×÷]'));
        if (!parts.last.contains('.')) {
          _display += '.';
        }
      } else if (value == '=') {
        _calculate();
      } else {
        if (_display.length < 16) {
          _display += value;
        }
      }
    });
  }

  void _calculate() {
    try {
      final exp = _display.replaceAll('×', '*').replaceAll('÷', '/');
      final result = _eval(exp);
      _emoji = '🎉';
      _explanation = _explain(_display);
      _display = result.toString();
    } catch (e) {
      _emoji = '😅';
      _explanation = 'Oops! Try a simple equation like 7 + 5.';
    }
  }

  double _eval(String exp) {
    // Very basic parser for +, -, *, /
    List<String> tokens = [];
    String num = '';
    for (int i = 0; i < exp.length; i++) {
      String c = exp[i];
      if ('0123456789.'.contains(c)) {
        num += c;
      } else if ('+-*/'.contains(c)) {
        if (num.isNotEmpty) tokens.add(num);
        tokens.add(c);
        num = '';
      }
    }
    if (num.isNotEmpty) tokens.add(num);
    // Left-to-right eval (no operator precedence)
    double result = double.parse(tokens[0]);
    for (int i = 1; i < tokens.length; i += 2) {
      String op = tokens[i];
      double n = double.parse(tokens[i + 1]);
      if (op == '+') result += n;
      if (op == '-') result -= n;
      if (op == '*') result *= n;
      if (op == '/') result /= n;
    }
    return result;
  }

  String _explain(String exp) {
    // Only explain simple a op b
    final ops = ['+', '-', '×', '÷'];
    for (var op in ops) {
      final parts = exp.split(op);
      if (parts.length == 2) {
        int? a = int.tryParse(parts[0].trim());
        int? b = int.tryParse(parts[1].trim());
        if (a != null && b != null) {
          switch (op) {
            case '+':
              return 'Let\'s add $a and $b!\n$a + $b = ${a + b}.';
            case '-':
              return 'Let\'s subtract $b from $a!\n$a - $b = ${a - b}.';
            case '×':
              // Always use the bigger number as the addend, smaller as the count
              int count = a < b ? a : b;
              int value = a < b ? b : a;
              String repeated;
              if (count <= 5) {
                repeated =
                    '${List.filled(count, value).join(' + ')} = ${a * b}.';
              } else {
                repeated = '$value + $value';
                if (count > 2) repeated += ' + ... ($count times)';
                repeated += ' = ${a * b}.';
              }
              return "Let's multiply $a and $b!\n$a × $b = ${a * b}.\nOr, $value added $count times: $repeated";
            case '÷':
              return 'Let\'s divide $a by $b!\n$a ÷ $b = ${a ~/ b} remainder ${a % b}.';
          }
        }
      }
    }
    return 'Try a simple equation like 7 + 5!';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final themeConfig = context.watch<ThemeService>().config;

    // Enhanced device detection (same as other screens)
    final shortestSide = math.min(screenWidth, screenHeight);
    final isTablet =
        shortestSide > 600 || (shortestSide > 500 && devicePixelRatio < 2.5);
    final isLandscape = screenWidth > screenHeight;
    final isSmallPhoneLandscape =
        isLandscape && !isTablet && screenHeight < 380;

    // Enhanced responsive sizing with three-tier system - more aggressive landscape reduction
    final horizontalPadding = isTablet
        ? 24.0
        : (isSmallPhoneLandscape ? 8.0 : (isLandscape ? 8.0 : 16.0));
    final verticalPadding = isTablet
        ? 16.0
        : (isSmallPhoneLandscape ? 3.0 : (isLandscape ? 4.0 : 12.0));
    final borderRadius = isTablet
        ? 24.0
        : (isSmallPhoneLandscape ? 12.0 : (isLandscape ? 14.0 : 20.0));
    final iconSize = isTablet
        ? 32.0
        : (isSmallPhoneLandscape ? 18.0 : (isLandscape ? 22.0 : 28.0));
    final titleFontSize = isTablet
        ? 32.0
        : (isSmallPhoneLandscape ? 18.0 : (isLandscape ? 22.0 : 28.0));
    final displayFontSize = isTablet
        ? 36.0
        : (isSmallPhoneLandscape ? 22.0 : (isLandscape ? 26.0 : 32.0));
    final buttonSize = isTablet
        ? 64.0
        : (isSmallPhoneLandscape ? 38.0 : (isLandscape ? 44.0 : 56.0));
    final buttonFontSize = isTablet
        ? 28.0
        : (isSmallPhoneLandscape ? 16.0 : (isLandscape ? 18.0 : 24.0));
    final spacing = isTablet
        ? 8.0
        : (isSmallPhoneLandscape ? 2.0 : (isLandscape ? 3.0 : 6.0));
    final explanationFontSize = isTablet
        ? 18.0
        : (isSmallPhoneLandscape ? 11.0 : (isLandscape ? 13.0 : 16.0));

    // Redesigned layout
    final numButtons = [
      ['7', '8', '9'],
      ['4', '5', '6'],
      ['1', '2', '3'],
    ];
    final opButtons = ['÷', '×', '-', '+'];
    final opColors = {
      '+': const Color(0xFFFF9F43),
      '-': const Color(0xFF43C465),
      '×': const Color(0xFF8E6CFF),
      '÷': const Color(0xFFFF6B6B),
      '=': const Color(0xFF8E6CFF),
      'C': const Color(0xFFB2F2E9),
      '⌫': const Color(0xFFB2F2E9),
    };
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: themeConfig.screenGradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              SizedBox(height: verticalPadding),
              Row(
                children: [
                  SizedBox(width: horizontalPadding * 0.75),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF8E6CFF),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0x338E6CFF),
                            blurRadius: isTablet ? 10.0 : 8.0,
                            offset: Offset(0, isTablet ? 5.0 : 4.0),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(isTablet ? 14.0 : 12.0),
                      child: Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: iconSize),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Kid\'s Calculator',
                    style: TextStyle(
                      fontFamily: 'Baloo2',
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF8E6CFF),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(width: isTablet ? 52.0 : 44.0),
                ],
              ),
              SizedBox(height: verticalPadding),
              // Display
              Container(
                margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
                padding: EdgeInsets.symmetric(
                    vertical: verticalPadding, horizontal: horizontalPadding),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: isTablet ? 8.0 : 6.0,
                      offset: Offset(0, isTablet ? 3.0 : 2.0),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(_emoji, style: TextStyle(fontSize: displayFontSize)),
                    SizedBox(width: verticalPadding),
                    Expanded(
                      child: Text(
                        _display.isEmpty ? '...' : _display,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: displayFontSize,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF8E6CFF),
                            fontFamily: 'Baloo2'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: verticalPadding),
              // Buttons
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: verticalPadding),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Number grid + operations
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Number grid
                          Column(
                            children: [
                              for (var row in numButtons)
                                Row(
                                  children: [
                                    for (var n in row)
                                      Padding(
                                        padding: EdgeInsets.all(spacing),
                                        child: GestureDetector(
                                          onTap: () => _onButton(n),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 100),
                                            width: buttonSize,
                                            height: buttonSize,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      borderRadius * 0.8),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.04),
                                                  blurRadius:
                                                      isTablet ? 5.0 : 4.0,
                                                  offset: Offset(
                                                      0, isTablet ? 3.0 : 2.0),
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: Text(
                                                n,
                                                style: TextStyle(
                                                    fontSize: buttonFontSize,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        const Color(0xFF8E6CFF),
                                                    fontFamily: 'Baloo2'),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              // Bottom row: 0, ., C, ⌫
                              Row(
                                children: [
                                  Padding(
                                    padding: EdgeInsets.all(spacing),
                                    child: GestureDetector(
                                      onTap: () => _onButton('0'),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 100),
                                        width: buttonSize,
                                        height: buttonSize,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                              borderRadius * 0.8),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.04),
                                              blurRadius: isTablet ? 5.0 : 4.0,
                                              offset: Offset(
                                                  0, isTablet ? 3.0 : 2.0),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text('0',
                                              style: TextStyle(
                                                  fontSize: buttonFontSize,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      const Color(0xFF8E6CFF),
                                                  fontFamily: 'Baloo2')),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.all(spacing),
                                    child: GestureDetector(
                                      onTap: () => _onButton('.'),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 100),
                                        width: buttonSize,
                                        height: buttonSize,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                              borderRadius * 0.8),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.04),
                                              blurRadius: isTablet ? 5.0 : 4.0,
                                              offset: Offset(
                                                  0, isTablet ? 3.0 : 2.0),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text('.',
                                              style: TextStyle(
                                                  fontSize: buttonFontSize,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      const Color(0xFF8E6CFF),
                                                  fontFamily: 'Baloo2')),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.all(spacing),
                                    child: GestureDetector(
                                      onTap: () => _onButton('C'),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 100),
                                        width: buttonSize,
                                        height: buttonSize,
                                        decoration: BoxDecoration(
                                          color: opColors['C'],
                                          borderRadius: BorderRadius.circular(
                                              borderRadius * 0.8),
                                          boxShadow: [
                                            BoxShadow(
                                              color: opColors['C']!
                                                  .withValues(alpha: 0.13),
                                              blurRadius: isTablet ? 8.0 : 6.0,
                                              offset: Offset(
                                                  0, isTablet ? 3.0 : 2.0),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Icon(
                                              Icons.cleaning_services_rounded,
                                              color: const Color(0xFF8E6CFF),
                                              size: buttonFontSize),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          // Operations column
                          Padding(
                            padding: EdgeInsets.only(
                                left: isLandscape ? spacing : spacing + 2.0,
                                top: 0),
                            child: Column(
                              children: [
                                for (var op in opButtons)
                                  Padding(
                                    padding: EdgeInsets.all(spacing),
                                    child: GestureDetector(
                                      onTap: () => _onButton(op),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 100),
                                        width: buttonSize,
                                        height: buttonSize,
                                        decoration: BoxDecoration(
                                          color: opColors[op],
                                          borderRadius: BorderRadius.circular(
                                              borderRadius * 0.8),
                                          boxShadow: [
                                            BoxShadow(
                                              color: opColors[op]!
                                                  .withValues(alpha: 0.13),
                                              blurRadius: isTablet ? 8.0 : 6.0,
                                              offset: Offset(
                                                  0, isTablet ? 3.0 : 2.0),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            op,
                                            style: TextStyle(
                                                fontSize: buttonFontSize,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                fontFamily: 'Baloo2'),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Big = button
                      Padding(
                        padding: EdgeInsets.only(
                            top: isLandscape ? spacing : spacing + 2.0),
                        child: GestureDetector(
                          onTap: () => _onButton('='),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 100),
                            width: isTablet
                                ? 320.0
                                : (isSmallPhoneLandscape
                                    ? 180.0
                                    : (isLandscape ? 220.0 : 280.0)),
                            height: isTablet
                                ? 64.0
                                : (isSmallPhoneLandscape
                                    ? 38.0
                                    : (isLandscape ? 44.0 : 56.0)),
                            decoration: BoxDecoration(
                              color: opColors['='],
                              borderRadius: BorderRadius.circular(isTablet
                                  ? 32.0
                                  : (isSmallPhoneLandscape
                                      ? 19.0
                                      : (isLandscape ? 22.0 : 28.0))),
                              boxShadow: [
                                BoxShadow(
                                  color: opColors['=']!.withValues(alpha: 0.13),
                                  blurRadius: isTablet ? 8.0 : 6.0,
                                  offset: Offset(0, isTablet ? 3.0 : 2.0),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text('=',
                                  style: TextStyle(
                                      fontSize: isTablet
                                          ? 30.0
                                          : (isSmallPhoneLandscape
                                              ? 16.0
                                              : (isLandscape ? 20.0 : 26.0)),
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontFamily: 'Baloo2')),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Explanation
              if (_explanation.isNotEmpty)
                Container(
                  margin: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: isLandscape
                          ? verticalPadding * 0.25
                          : verticalPadding * 0.75),
                  padding: EdgeInsets.symmetric(
                      horizontal: verticalPadding,
                      vertical: isLandscape
                          ? verticalPadding * 0.25
                          : verticalPadding * 0.75),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEA),
                    borderRadius: BorderRadius.circular(borderRadius * 0.75),
                    border: Border.all(
                        color: const Color(0xFFFF9F43),
                        width: isTablet ? 2.5 : 2.0),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('💡 ',
                          style: TextStyle(
                              fontSize: isTablet
                                  ? 20.0
                                  : (isSmallPhoneLandscape
                                      ? 14.0
                                      : (isLandscape ? 16.0 : 18.0)))),
                      Expanded(
                        child: Text(
                          _explanation,
                          style: TextStyle(
                              fontSize: explanationFontSize,
                              color: const Color(0xFFFF9800),
                              fontFamily: 'Baloo2',
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: verticalPadding),
            ],
          ),
        ),
      ),
    );
  }
}
