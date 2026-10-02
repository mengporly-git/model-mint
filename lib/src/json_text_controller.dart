import 'package:flutter/material.dart';

/// Colors the editable text without changing its selection or input behavior.
class JsonTextController extends TextEditingController {
  JsonTextController({super.text});

  static final _tokens = RegExp(
    r'"(?:\\.|[^"\\])*"\s*:|"(?:\\.|[^"\\])*"|\b(?:true|false|null)\b|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?|[{}\[\],:]',
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final token in _tokens.allMatches(text)) {
      if (token.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, token.start)));
      }
      final value = token.group(0)!;
      final color = value.startsWith('"')
          ? (value.trimRight().endsWith(':')
                ? const Color(0xFF80C9EA)
                : const Color(0xFFD5987B))
          : (value == 'true' || value == 'false' || value == 'null')
          ? const Color(0xFFC792EA)
          : RegExp(r'^-?\d').hasMatch(value)
          ? const Color(0xFFB8D994)
          : const Color(0xFFBCC8C0);
      // Preserve the IME underline while composing a token or plain segment.
      spans.add(
        TextSpan(
          text: value,
          style: TextStyle(color: color),
        ),
      );
      cursor = token.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    if (withComposing &&
        value.composing.isValid &&
        !value.composing.isCollapsed) {
      // The native controller handles composing text safely for IME input.
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: true,
      );
    }
    return TextSpan(style: style, children: spans);
  }
}
