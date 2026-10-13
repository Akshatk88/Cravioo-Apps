import 'package:flutter/material.dart';

/// Minimal HTML renderer for admin-authored CMS content (no extra package).
/// Supports paragraphs, line breaks, headings, bold/italic/underline,
/// ordered/unordered lists and common entities. Unknown tags are ignored.
class SimpleHtmlView extends StatelessWidget {
  const SimpleHtmlView({super.key, required this.html, this.color, this.fontSize = 14});

  final String html;
  final Color? color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      color: color ?? Theme.of(context).colorScheme.onSurface,
      fontSize: fontSize,
      height: 1.5,
    );
    final blocks = _parse(html, base);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }

  static final RegExp _tagRe = RegExp(r'<(/?)([a-zA-Z][a-zA-Z0-9]*)[^>]*?(/?)>');

  static String _decode(String s) {
    return s
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&rsquo;', '’')
        .replaceAll('&lsquo;', '‘')
        .replaceAll('&ldquo;', '“')
        .replaceAll('&rdquo;', '”')
        .replaceAll('&ndash;', '–')
        .replaceAll('&mdash;', '—')
        .replaceAll('&amp;', '&');
  }

  static List<Widget> _parse(String source, TextStyle base) {
    // Plain-text content (no markup) keeps its line breaks.
    final html = _tagRe.hasMatch(source)
        ? source
        : source.replaceAll('\n', '<br>');
    final widgets = <Widget>[];
    var spans = <InlineSpan>[];
    var bold = 0, italic = 0, underline = 0;
    double? headingSize;
    final listStack = <_ListCtx>[];

    TextStyle currentStyle() => base.copyWith(
      fontWeight: (bold > 0 || headingSize != null) ? FontWeight.w700 : null,
      fontStyle: italic > 0 ? FontStyle.italic : null,
      decoration: underline > 0 ? TextDecoration.underline : null,
      fontSize: headingSize ?? base.fontSize,
    );

    void flush({double bottom = 8, double leftIndent = 0}) {
      // Drop blocks that are only whitespace.
      final hasText = spans.any(
        (s) => s is TextSpan && (s.text ?? '').trim().isNotEmpty,
      );
      if (hasText) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(bottom: bottom, left: leftIndent),
            child: Text.rich(TextSpan(children: List.of(spans), style: base)),
          ),
        );
      }
      spans = <InlineSpan>[];
    }

    void addText(String raw) {
      final text = _decode(raw.replaceAll(RegExp(r'\s+'), ' '));
      if (text.isEmpty) return;
      spans.add(TextSpan(text: text, style: currentStyle()));
    }

    var cursor = 0;
    for (final m in _tagRe.allMatches(html)) {
      if (m.start > cursor) addText(html.substring(cursor, m.start));
      cursor = m.end;
      final closing = m.group(1) == '/';
      final tag = m.group(2)!.toLowerCase();
      switch (tag) {
        case 'b':
        case 'strong':
          bold += closing ? -1 : 1;
        case 'i':
        case 'em':
          italic += closing ? -1 : 1;
        case 'u':
          underline += closing ? -1 : 1;
        case 'br':
          spans.add(const TextSpan(text: '\n'));
        case 'h1':
        case 'h2':
        case 'h3':
        case 'h4':
        case 'h5':
        case 'h6':
          flush();
          if (closing) {
            headingSize = null;
          } else {
            final level = int.parse(tag.substring(1));
            headingSize = (base.fontSize ?? 14) + (7 - level) * 1.6;
          }
        case 'ul':
        case 'ol':
          flush();
          if (closing) {
            if (listStack.isNotEmpty) listStack.removeLast();
          } else {
            listStack.add(_ListCtx(ordered: tag == 'ol'));
          }
        case 'li':
          if (closing) {
            flush(bottom: 4, leftIndent: 8.0 * listStack.length);
          } else {
            flush();
            if (listStack.isNotEmpty) {
              final ctx = listStack.last;
              ctx.index++;
              spans.add(
                TextSpan(
                  text: ctx.ordered ? '${ctx.index}. ' : '•  ',
                  style: currentStyle(),
                ),
              );
            }
          }
        case 'p':
        case 'div':
        case 'tr':
        case 'blockquote':
          flush();
        case 'script':
        case 'style':
          // Skip everything up to the closing tag.
          if (!closing) {
            final end = html.indexOf('</$tag', cursor);
            if (end != -1) cursor = end;
          }
        default:
          break;
      }
    }
    if (cursor < html.length) addText(html.substring(cursor));
    flush();
    return widgets;
  }
}

class _ListCtx {
  _ListCtx({required this.ordered});

  final bool ordered;
  int index = 0;
}
