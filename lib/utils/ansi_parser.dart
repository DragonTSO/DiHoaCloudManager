import 'package:flutter/material.dart';

/// Parser để xử lý ANSI escape codes trong console output
/// Hỗ trợ màu sắc, bold, italic, underline như terminal
class AnsiParser {
  /// Parse ANSI escape codes và tạo TextSpan với màu/format đúng
  /// Hỗ trợ các format: \x1b[91m, [91m, [37m[4m[91m, etc.
  static TextSpan parseAnsi(String text, {Color defaultColor = Colors.green}) {
    // Sử dụng regex để tìm và thay thế ANSI codes
    final spans = <TextSpan>[];
    Color? currentColor = defaultColor;
    bool isBold = false;
    bool isItalic = false;
    bool isUnderline = false;

    // Tìm tất cả ANSI escape sequences
    // Pattern: \x1b[CODEm hoặc [CODEm (có thể nhiều liên tiếp)
    final ansiPattern = RegExp(r'(?:\x1b\[|\[)([0-9;]*?)m');
    
    int lastIndex = 0;
    final matches = ansiPattern.allMatches(text);
    
    for (final match in matches) {
      // Thêm text trước ANSI code
      if (match.start > lastIndex) {
        final textBefore = text.substring(lastIndex, match.start);
        if (textBefore.isNotEmpty) {
          spans.add(_createTextSpan(
            textBefore,
            currentColor ?? defaultColor,
            isBold,
            isItalic,
            isUnderline,
          ));
        }
      }

      // Parse và apply ANSI codes
      final codeStr = match.group(1) ?? '';
      final codes = codeStr.split(';').where((c) => c.isNotEmpty);
      
      for (final code in codes) {
        _applyAnsiCode(code, defaultColor, (color, bold, italic, underline) {
          if (color != null) currentColor = color;
          isBold = bold;
          isItalic = italic;
          isUnderline = underline;
        });
      }

      lastIndex = match.end;
    }

    // Thêm text còn lại sau ANSI codes
    if (lastIndex < text.length) {
      final textAfter = text.substring(lastIndex);
      if (textAfter.isNotEmpty) {
        spans.add(_createTextSpan(
          textAfter,
          currentColor ?? defaultColor,
          isBold,
          isItalic,
          isUnderline,
        ));
      }
    }

    // Nếu không có spans nào, tạo một span mặc định
    if (spans.isEmpty) {
      return TextSpan(
        text: text,
        style: TextStyle(color: defaultColor, fontFamily: 'monospace', fontSize: 12),
      );
    }

    return TextSpan(children: spans);
  }

  /// Apply ANSI code và cập nhật state
  static void _applyAnsiCode(
    String code,
    Color defaultColor,
    void Function(Color?, bool, bool, bool) updateState,
  ) {
    if (code.isEmpty) return;
    
    final codeInt = int.tryParse(code) ?? 0;
    
    // Reset code
    if (codeInt == 0) {
      updateState(defaultColor, false, false, false);
    }
    // Text style codes
    else if (codeInt == 1) {
      updateState(null, true, false, false);
    } else if (codeInt == 3) {
      updateState(null, false, true, false);
    } else if (codeInt == 4) {
      updateState(null, false, false, true);
    } else if (codeInt == 22) {
      updateState(null, false, false, false);
    } else if (codeInt == 23) {
      updateState(null, false, false, false);
    } else if (codeInt == 24) {
      updateState(null, false, false, false);
    }
    // Foreground colors (30-37)
    else if (codeInt >= 30 && codeInt <= 37) {
      updateState(_getColor(codeInt - 30, bright: false), false, false, false);
    }
    // Bright foreground colors (90-97, hoặc 91 = bright red)
    else if (codeInt >= 90 && codeInt <= 97) {
      updateState(_getColor(codeInt - 90, bright: true), false, false, false);
    }
    // Một số codes phổ biến khác
    else if (codeInt == 39) {
      // Reset foreground color
      updateState(defaultColor, false, false, false);
    }
  }

  /// Tạo TextSpan với style tương ứng
  static TextSpan _createTextSpan(
    String text,
    Color color,
    bool bold,
    bool italic,
    bool underline,
  ) {
    return TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontFamily: 'monospace',
        fontSize: 12,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        decoration: underline ? TextDecoration.underline : TextDecoration.none,
      ),
    );
  }

  /// Map ANSI color codes sang Flutter Colors
  static Color _getColor(int code, {bool bright = false}) {
    switch (code) {
      case 0: // Black
        return bright ? Colors.grey[800]! : Colors.black;
      case 1: // Red
        return bright ? Colors.red[400]! : Colors.red;
      case 2: // Green
        return bright ? Colors.green[400]! : Colors.green;
      case 3: // Yellow
        return bright ? Colors.yellow[400]! : Colors.yellow;
      case 4: // Blue
        return bright ? Colors.blue[400]! : Colors.blue;
      case 5: // Magenta
        return bright ? Colors.purple[400]! : Colors.purple;
      case 6: // Cyan
        return bright ? Colors.cyan[400]! : Colors.cyan;
      case 7: // White
        return bright ? Colors.white : Colors.grey[300]!;
      default:
        return Colors.green;
    }
  }

  /// Strip ANSI escape codes từ text (để hiển thị text thuần túy)
  static String stripAnsi(String text) {
    return text
        .replaceAll(RegExp(r'\x1b\[[0-9;]*m'), '')
        .replaceAll(RegExp(r'\[[0-9;]*m'), '');
  }
}

