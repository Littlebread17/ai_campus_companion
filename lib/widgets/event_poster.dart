import 'package:flutter/material.dart';

/// Shows an event's poster. If [posterUrl] is empty, renders a deterministic
/// gradient banner derived from the event title (so each event looks distinct)
/// with the title + host overlaid — no upload required.
class EventPoster extends StatelessWidget {
  const EventPoster({
    super.key,
    required this.title,
    required this.posterUrl,
    this.host = '',
    this.height = 180,
    this.borderRadius = 0,
    this.showOverlayText = true,
  });

  final String title;
  final String posterUrl;
  final String host;
  final double height;
  final double borderRadius;
  final bool showOverlayText;

  // A small palette of pleasant gradient pairs.
  static const _gradients = <List<Color>>[
    [Color(0xff2563eb), Color(0xff7c3aed)],
    [Color(0xff0891b2), Color(0xff0e7490)],
    [Color(0xffdb2777), Color(0xff9d174d)],
    [Color(0xff16a34a), Color(0xff065f46)],
    [Color(0xffea580c), Color(0xff9a3412)],
    [Color(0xff4f46e5), Color(0xff1e1b4b)],
  ];

  List<Color> get _gradientFor {
    if (title.isEmpty) return _gradients.first;
    final idx =
        title.codeUnits.fold<int>(0, (a, b) => a + b) % _gradients.length;
    return _gradients[idx];
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    if (posterUrl.isNotEmpty) {
      if (posterUrl.startsWith('asset:')) {
        return ClipRRect(
          borderRadius: radius,
          child: Image.asset(
            posterUrl.substring('asset:'.length),
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (c, e, s) => _banner(radius),
          ),
        );
      }
      return ClipRRect(
        borderRadius: radius,
        child: Image.network(
          posterUrl,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (c, w, p) =>
              p == null ? w : _placeholder(radius, loading: true),
          errorBuilder: (c, e, s) => _banner(radius),
        ),
      );
    }
    return _banner(radius);
  }

  Widget _placeholder(BorderRadius radius, {bool loading = false}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xffe2e8f0),
        borderRadius: radius,
      ),
      child: loading ? const Center(child: CircularProgressIndicator()) : null,
    );
  }

  Widget _banner(BorderRadius radius) {
    final colors = _gradientFor;
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: showOverlayText
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: height < 140 ? 16 : 20,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                ),
                if (host.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    host,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ],
            )
          : null,
    );
  }
}
