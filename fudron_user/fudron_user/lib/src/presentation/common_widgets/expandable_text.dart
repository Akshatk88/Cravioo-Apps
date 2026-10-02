import 'package:flutter/material.dart';

/// Text clamped to [maxLines], with a Read more / Read less toggle that only
/// appears when the text actually overflows.
///
/// The toggle is driven by a real layout measurement rather than a character
/// count, because whether text overflows depends on the font, the width it is
/// given and the user's text scale — a "longer than N characters" guess shows
/// "Read more" on text that already fits, and hides it on text that does not.
class ExpandableText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int maxLines;
  final Color? linkColor;

  const ExpandableText(
    this.text, {
    super.key,
    this.style,
    this.maxLines = 2,
    this.linkColor,
  });

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    final linkColor = widget.linkColor ?? Theme.of(context).colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: widget.maxLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.text,
              style: style,
              maxLines: _expanded ? null : widget.maxLines,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            if (overflows)
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _expanded ? 'Read less' : 'Read more',
                    style: style.copyWith(
                      color: linkColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
