// lib/utils/link_preview_service.dart
import 'package:http/http.dart' as http;

class LinkPreviewData {
  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? siteName;

  const LinkPreviewData({
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
    this.siteName,
  });

  bool get hasContent => title != null || description != null || imageUrl != null;
}

class LinkPreviewService {
  static final Map<String, LinkPreviewData?> _cache = {};

  static Future<LinkPreviewData?> fetch(String url) async {
    if (_cache.containsKey(url)) return _cache[url];

    try {
      final uri = Uri.parse(url);
      final response = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
        'Accept': 'text/html,application/xhtml+xml',
        'Accept-Language': 'en-US,en;q=0.9',
      }).timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) {
        _cache[url] = null;
        return null;
      }

      final html = response.body;
      final imageUrl = _parseOgMeta(html, 'og:image') ?? _parseOgMeta(html, 'og:image:secure_url');
      final data = LinkPreviewData(
        url: url,
        title: _decode(_parseOgMeta(html, 'og:title') ?? _parseMetaName(html, 'title') ?? _parseTitleTag(html)),
        description: _decode(_parseOgMeta(html, 'og:description') ?? _parseMetaName(html, 'description')),
        imageUrl: imageUrl != null ? _resolveUrl(imageUrl, uri) : null,
        siteName: _decode(_parseOgMeta(html, 'og:site_name') ?? uri.host.replaceFirst('www.', '')),
      );

      _cache[url] = data.hasContent ? data : null;
      return _cache[url];
    } catch (e) {
      _cache[url] = null;
      return null;
    }
  }

  static String _resolveUrl(String imageUrl, Uri base) {
    if (imageUrl.startsWith('http')) return imageUrl;
    if (imageUrl.startsWith('//')) return '${base.scheme}:$imageUrl';
    if (imageUrl.startsWith('/')) return '${base.scheme}://${base.host}$imageUrl';
    return '${base.scheme}://${base.host}/$imageUrl';
  }

  static String? _parseOgMeta(String html, String property) {
    final tagRe = RegExp(
      '<meta[^>]+property=(?:"|\'|)${_reEscape(property)}(?:"|\'|)[^>]*>',
      caseSensitive: false,
    );
    final tag = tagRe.firstMatch(html)?.group(0);
    if (tag == null) return null;
    return _extractAttr(tag, 'content');
  }

  static String? _parseMetaName(String html, String name) {
    final tagRe = RegExp(
      '<meta[^>]+name=(?:"|\'|)${_reEscape(name)}(?:"|\'|)[^>]*>',
      caseSensitive: false,
    );
    final tag = tagRe.firstMatch(html)?.group(0);
    if (tag == null) return null;
    return _extractAttr(tag, 'content');
  }

  static String? _extractAttr(String tag, String attr) {
    
    final re2 = RegExp('${_reEscape(attr)}="([^"]*)"', caseSensitive: false);
    final m2 = re2.firstMatch(tag);
    if (m2 != null) return m2.group(1);
    
    final re1 = RegExp("${_reEscape(attr)}='([^']*)'", caseSensitive: false);
    return re1.firstMatch(tag)?.group(1);
  }

  static String? _parseTitleTag(String html) {
    final re = RegExp(r'<title[^>]*>([^<]+)</title>', caseSensitive: false);
    return re.firstMatch(html)?.group(1)?.trim();
  }

  static String _reEscape(String s) =>
      s.replaceAllMapped(RegExp(r'[.*+?^${}()|[\]\\]'), (m) => '\\${m.group(0)}');

  static String? _decode(String? s) {
    if (s == null) return null;
    return s
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
  }
}