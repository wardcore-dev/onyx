// lib/widgets/link_preview_card.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/link_preview_service.dart';

class LinkPreviewCard extends StatefulWidget {
  final String url;
  const LinkPreviewCard({super.key, required this.url});

  @override
  State<LinkPreviewCard> createState() => _LinkPreviewCardState();
}

class _LinkPreviewCardState extends State<LinkPreviewCard> {
  late Future<LinkPreviewData?> _future;

  @override
  void initState() {
    super.initState();
    _future = LinkPreviewService.fetch(widget.url);
  }

  @override
  void didUpdateWidget(LinkPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _future = LinkPreviewService.fetch(widget.url);
    }
  }

  @override
  Widget build(BuildContext context) {
    // If already in cache, render immediately with no FutureBuilder flash.
    if (LinkPreviewService.isCached(widget.url)) {
      final data = LinkPreviewService.getCached(widget.url);
      if (data == null) return const SizedBox.shrink();
      return _buildCard(context, data);
    }

    return FutureBuilder<LinkPreviewData?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        return _buildCard(context, snapshot.data!);
      },
    );
  }

  Widget _buildCard(BuildContext context, LinkPreviewData data) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => launchUrl(
        Uri.parse(widget.url),
        mode: LaunchMode.externalApplication,
      ),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cs.outline.withValues(alpha: 0.15),
            width: 0.6,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (data.imageUrl != null)
              CachedNetworkImage(
                imageUrl: data.imageUrl!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
                placeholder: (_, __) => const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (data.siteName != null)
                    Text(
                      data.siteName!,
                      style: TextStyle(
                        color: cs.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (data.title != null) ...[
                    if (data.siteName != null) const SizedBox(height: 2),
                    Text(
                      data.title!,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (data.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      data.description!,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.65),
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
