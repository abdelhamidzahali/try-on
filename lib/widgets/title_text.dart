import 'package:flutter/material.dart';

/// Consistent uppercase title text using theme title styles.
/// Defaults to titleLarge if no style is provided.
class TitleText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;

  const TitleText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.titleLarge;
    return Text(
      text.toUpperCase(),
      style: base,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
    );
  }
}
