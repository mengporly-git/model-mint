import 'package:flutter/material.dart';

/// Highlights generated Dart without altering selection or copying.
class DartTextController extends TextEditingController {
  static final _tokens = RegExp(
    r'''//[^\n]*|/\*[\s\S]*?\*/|'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"|\b\d+(?:\.\d+)?\b|[a-zA-Z_$][\w$]*''',
  );
  static const _keywords = {
    'class',
    'final',
    'factory',
    'required',
    'this',
    'return',
    'if',
    'is',
    'as',
    'else',
    'const',
    'null',
    'true',
    'false',
    'dynamic',
    'import',
  };
  static const _types = {
    'String',
    'int',
    'double',
    'bool',
    'Map',
    'List',
    'Object',
    'num',
  };

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (withComposing &&
        value.composing.isValid &&
        !value.composing.isCollapsed) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: true,
      );
    }
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final token in _tokens.allMatches(text)) {
      if (token.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, token.start)));
      }
      final word = token.group(0)!;
      Color? color;
      if (word.startsWith('//') || word.startsWith('/*')) {
        color = const Color(0xFF819087);
      } else if (word.startsWith("'") || word.startsWith('"')) {
        color = const Color(0xFFD5987B);
      } else if (_keywords.contains(word)) {
        color = const Color(0xFFC792EA);
      } else if (_types.contains(word) || RegExp(r'^[A-Z]').hasMatch(word)) {
        color = const Color(0xFF80C9EA);
      } else if (RegExp(r'^\d').hasMatch(word)) {
        color = const Color(0xFFB8D994);
      } else if (text.substring(token.end).trimLeft().startsWith('(')) {
        color = const Color(0xFFDCDCAA);
      }
      spans.add(
        TextSpan(
          text: word,
          style: TextStyle(color: color),
        ),
      );
      cursor = token.end;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
    return TextSpan(style: style, children: spans);
  }
}
