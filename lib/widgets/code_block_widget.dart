import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../globals.dart';

class CodeBlockWidget extends StatefulWidget {
  final String code;
  final String language;

  const CodeBlockWidget({
    Key? key,
    required this.code,
    this.language = 'plaintext',
  }) : super(key: key);

  @override
  State<CodeBlockWidget> createState() => _CodeBlockWidgetState();
}

class _CodeBlockWidgetState extends State<CodeBlockWidget> {
  bool _copied = false;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final lines = widget.code.split('\n');
    final maxLineLength = lines.fold<int>(0, (max, line) => max > line.length ? max : line.length);
    
    final estimatedWidth = (maxLineLength * 7.5).clamp(200.0, 600.0);

    final isLarge = lines.length > 10;
    final visibleCode = (isLarge && !_expanded)
        ? (lines.take(10).join('\n') + (lines.length > 10 ? '\n...' : ''))
        : widget.code;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      width: estimatedWidth,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.language.isEmpty ? 'code' : widget.language,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                    fontFamily: 'Courier New',
                  ),
                ),
                
                GestureDetector(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: widget.code));
                    rootScreenKey.currentState?.showSnack('Copied!');
                    setState(() => _copied = true);
                    Future.delayed(const Duration(seconds: 2), () {
                      if (mounted) setState(() => _copied = false);
                    });
                  },
                  child: Tooltip(
                    message: _copied ? 'Copied!' : 'Copy',
                    child: Icon(
                      _copied ? Icons.check : Icons.content_copy,
                      size: 16,
                      color: _copied ? Colors.green : colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              padding: const EdgeInsets.all(12),
              child: SelectableText.rich(
                TextSpan(
                  children: _highlightCode(visibleCode, widget.language),
                  style: TextStyle(
                    fontFamily: 'Courier New',
                    fontSize: 12,
                    color: colorScheme.onSurface,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),

          if (isLarge)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _expanded
                        ? 'All ${lines.length} lines'
                        : 'First 10 of ${lines.length} lines',
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    child: Text(_expanded ? 'Less' : 'More'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<TextSpan> _highlightCode(String code, String lang) {
    final lines = code.split('\n');
    final spans = <TextSpan>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      if (line.trim().isEmpty) {
        spans.add(TextSpan(text: '\n'));
        continue;
      }

      final colored = _colorizeLineByLanguage(line, lang);
      spans.addAll(colored);
      
      if (i < lines.length - 1) {
        spans.add(TextSpan(text: '\n'));
      }
    }

    return spans;
  }

  List<TextSpan> _colorizeLineByLanguage(String line, String lang) {
    
    final spans = <TextSpan>[];
    
    final keywords = {
      'dart': ['void', 'class', 'final', 'const', 'if', 'else', 'for', 'while', 'return', 'import', 'export', 'extends', 'implements', 'dynamic', 'late', 'async', 'await', 'Future', 'Stream', 'try', 'catch', 'throw'],
      'python': ['def', 'class', 'if', 'else', 'elif', 'for', 'while', 'return', 'import', 'from', 'as', 'try', 'except', 'finally', 'with', 'yield', 'lambda', 'pass', 'break', 'continue'],
      'javascript': ['function', 'class', 'const', 'let', 'var', 'if', 'else', 'for', 'while', 'return', 'import', 'export', 'async', 'await', 'try', 'catch', 'throw', 'new', 'this', 'super', 'extends'],
      'typescript': ['function', 'class', 'const', 'let', 'var', 'if', 'else', 'for', 'while', 'return', 'import', 'export', 'async', 'await', 'try', 'catch', 'throw', 'interface', 'type', 'enum', 'namespace'],
      'java': ['class', 'public', 'private', 'protected', 'static', 'final', 'void', 'if', 'else', 'for', 'while', 'return', 'import', 'package', 'try', 'catch', 'throws', 'interface', 'extends', 'implements'],
      'cpp': ['int', 'void', 'class', 'if', 'else', 'for', 'while', 'return', 'include', 'define', 'using', 'namespace', 'template', 'const', 'static', 'auto', 'nullptr', 'new', 'delete'],
    };

    final langKeywords = keywords[lang] ?? [];
    
    int pos = 0;
    while (pos < line.length) {
      
      if (line[pos] == ' ' || line[pos] == '\t') {
        int spaceEnd = pos;
        while (spaceEnd < line.length && (line[spaceEnd] == ' ' || line[spaceEnd] == '\t')) {
          spaceEnd++;
        }
        spans.add(TextSpan(text: line.substring(pos, spaceEnd)));
        pos = spaceEnd;
        continue;
      }

      if (line[pos] == '"' || line[pos] == "'" || line[pos] == '`') {
        final quote = line[pos];
        int endQuote = pos + 1;
        while (endQuote < line.length && line[endQuote] != quote) {
          if (line[endQuote] == '\\' && endQuote + 1 < line.length) endQuote += 2;
          else endQuote++;
        }
        if (endQuote < line.length) endQuote++;
        spans.add(TextSpan(
          text: line.substring(pos, endQuote),
          style: const TextStyle(color: Color(0xFF6A9955)), 
        ));
        pos = endQuote;
        continue;
      }

      if (pos + 1 < line.length && line[pos] == '/' && line[pos + 1] == '/') {
        spans.add(TextSpan(
          text: line.substring(pos),
          style: const TextStyle(color: Color(0xFF6A9955), fontStyle: FontStyle.italic), 
        ));
        break;
      }

      if (pos + 1 < line.length && line[pos] == '#') {
        spans.add(TextSpan(
          text: line.substring(pos),
          style: const TextStyle(color: Color(0xFF6A9955), fontStyle: FontStyle.italic), 
        ));
        break;
      }

      if (line[pos].codeUnitAt(0) >= 48 && line[pos].codeUnitAt(0) <= 57) {
        int numEnd = pos;
        while (numEnd < line.length && 
               ((line[numEnd].codeUnitAt(0) >= 48 && line[numEnd].codeUnitAt(0) <= 57) || line[numEnd] == '.')) {
          numEnd++;
        }
        spans.add(TextSpan(
          text: line.substring(pos, numEnd),
          style: const TextStyle(color: Color(0xFFB5CEA8)), 
        ));
        pos = numEnd;
        continue;
      }

      int wordEnd = pos;
      while (wordEnd < line.length && 
             (line[wordEnd].codeUnitAt(0) == 95 || 
              (line[wordEnd].codeUnitAt(0) >= 48 && line[wordEnd].codeUnitAt(0) <= 57) || 
              (line[wordEnd].codeUnitAt(0) >= 65 && line[wordEnd].codeUnitAt(0) <= 90) || 
              (line[wordEnd].codeUnitAt(0) >= 97 && line[wordEnd].codeUnitAt(0) <= 122))) { 
        wordEnd++;
      }

      if (wordEnd > pos) {
        final word = line.substring(pos, wordEnd);
        
        if (langKeywords.contains(word)) {
          spans.add(TextSpan(
            text: word,
            style: const TextStyle(
              color: Color(0xFF569CD6), 
              fontWeight: FontWeight.w600,
            ),
          ));
        } else {
          spans.add(TextSpan(text: word));
        }
        pos = wordEnd;
        continue;
      }

      spans.add(TextSpan(text: line[pos]));
      pos++;
    }

    return spans;
  }
}