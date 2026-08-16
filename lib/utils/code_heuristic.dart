// lib/utils/code_heuristic.dart
//
// Heuristic guess at whether a plain-text message looks like source code.
// Used pre-send (chat screens) to decide whether to ask the user "send as
// code artifact?" instead of silently auto-rendering as a code block, which
// used to misfire on ordinary prose containing brackets/semicolons.

bool looksLikeCode(String text) {
  if (text.isEmpty) return false;
  if (text.length < 10) return false;

  int codeIndicators = 0;

  if (text.contains('{') ||
      text.contains('}') ||
      text.contains('[') ||
      text.contains(']') ||
      text.contains('(') && text.contains(')')) {
    codeIndicators++;
  }

  if (text.contains(';')) {
    codeIndicators++;
  }

  if (text.contains('=>') ||
      text.contains('==') ||
      text.contains('!=') ||
      text.contains('===') ||
      text.contains('const ') ||
      text.contains('final ') ||
      text.contains('let ') ||
      text.contains('var ') ||
      text.contains('function') ||
      text.contains('class ') ||
      text.contains('def ') ||
      text.contains('void ')) {
    codeIndicators += 2;
  }

  final lines = text.split('\n');
  if (lines.length > 2) {
    int linesWithIndent = 0;
    for (final line in lines) {
      if (line.startsWith('  ') || line.startsWith('\t')) {
        linesWithIndent++;
      }
    }
    if (linesWithIndent > lines.length * 0.3) {
      codeIndicators++;
    }
  }

  return codeIndicators >= 2;
}

String detectCodeLanguage(String text) {
  final lower = text.toLowerCase();

  if (lower.contains('void main') ||
      lower.contains('import') && lower.contains('dart')) {
    return 'dart';
  }
  if (lower.contains('def ') ||
      lower.contains('import ') &&
          (lower.contains('sys') || lower.contains('os'))) {
    return 'python';
  }
  if (lower.contains('function ') ||
      lower.contains('const ') && lower.contains('=>')) {
    return 'javascript';
  }
  if (lower.contains('public class') || lower.contains('public static')) {
    return 'java';
  }
  if (lower.contains('class ') && lower.contains('{')) {
    if (lower.contains('async') || lower.contains('await')) {
      return 'dart';
    }
    return 'java';
  }
  if (lower.contains('#include')) {
    return 'cpp';
  }

  return 'plaintext';
}
