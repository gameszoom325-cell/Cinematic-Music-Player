import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:adblocker_webview/adblocker_webview.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/database/models/song_model.dart';
import '../core/theme/cinematic_colors.dart';
import '../features/player/providers/player_provider.dart';

/// WebView-based MP3 search and download screen (Pagalworld) with integrated ad-blocking.
///
/// Features:
/// - Loads https://pagalworld.is/ by default with EasyList & AdGuard ad filtering.
/// - Integrated top search bar: navigates to https://pagalworld.is/search?q=<encoded_query> on Enter.
/// - Safe AdBlockerWebviewController blocking non-http/https schemes (intent://, market://) to prevent ERR_UNKNOWN_URL_SCHEME.
/// - Pre-fills search query when navigated from main search screen (handoff flow).
/// - Floating "Use this MP3" button to extract current page / download audio link into the player.
/// - Home button in AppBar returning to https://pagalworld.is/.
/// - System Android back button navigation in WebView history.
/// - Desktop/Windows graceful fallback with direct external browser launch.
class WebSearchPage extends ConsumerStatefulWidget {
  const WebSearchPage({super.key, this.initialQuery});

  final String? initialQuery;

  static const String homeUrl = 'https://pagalworld.is/';
  static const String searchBaseUrl = 'https://pagalworld.is/search?q=';

  /// Validates that a navigation URL uses an allowed HTTP or HTTPS scheme.
  /// Prevents WebView crashes from Android intent schemes (e.g., intent://, market://).
  static bool isAllowedUrlScheme(String url) {
    final lower = url.trim().toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  @override
  ConsumerState<WebSearchPage> createState() => _WebSearchPageState();
}

/// Custom wrapper around AdBlockerWebviewController that strictly enforces
/// allowed HTTP/HTTPS URL schemes, preventing crashes on intent:// or market:// links.
class SafeAdBlockerWebviewController implements AdBlockerWebviewController {
  final AdBlockerWebviewController _delegate = AdBlockerWebviewController.instance;
  WebViewController? _internalController;

  WebViewController? get internalController => _internalController;

  @override
  Future<void> initialize(FilterConfig filterConfig) => _delegate.initialize(filterConfig);

  @override
  bool shouldBlockResource(String url) {
    // Intercept non-http/https navigation schemes to prevent ERR_UNKNOWN_URL_SCHEME
    if (!WebSearchPage.isAllowedUrlScheme(url)) {
      debugPrint("WebSearchPage: Blocked non-http navigation scheme: $url");
      return true;
    }
    return _delegate.shouldBlockResource(url);
  }

  @override
  Future<bool> canGoBack() => _delegate.canGoBack();

  @override
  Future<bool> canGoForward() => _delegate.canGoForward();

  @override
  Future<void> clearCache() => _delegate.clearCache();

  @override
  UnmodifiableListView<ResourceRule> get allResourceRules => _delegate.allResourceRules;

  @override
  Future<String?> getTitle() => _delegate.getTitle();

  @override
  Future<void> loadUrl(String url) => _delegate.loadUrl(url);

  @override
  Future<void> loadData(String data, {String? baseUrl}) => _delegate.loadData(data, baseUrl: baseUrl);

  @override
  List<String> getCssRulesForWebsite(String url) => _delegate.getCssRulesForWebsite(url);

  @override
  Future<void> goBack() => _delegate.goBack();

  @override
  Future<void> goForward() => _delegate.goForward();

  @override
  Future<void> reload() => _delegate.reload();

  @override
  Future<void> stopLoading() => _delegate.stopLoading();

  @override
  Future<void> runScript(String script) => _delegate.runScript(script);

  @override
  Set<String> get allowedDomains => _delegate.allowedDomains;

  @override
  void addAllowedDomain(String domain) => _delegate.addAllowedDomain(domain);

  @override
  bool removeAllowedDomain(String domain) => _delegate.removeAllowedDomain(domain);

  @override
  bool isAllowedDomain(String urlOrDomain) => _delegate.isAllowedDomain(urlOrDomain);

  @override
  Set<String> get blockedDomains => _delegate.blockedDomains;

  @override
  void addBlockedDomain(String domain) => _delegate.addBlockedDomain(domain);

  @override
  bool removeBlockedDomain(String domain) => _delegate.removeBlockedDomain(domain);

  @override
  bool isBlockedDomain(String urlOrDomain) => _delegate.isBlockedDomain(urlOrDomain);

  @override
  BlockingStatistics get statistics => _delegate.statistics;

  @override
  void resetStatistics() => _delegate.resetStatistics();

  @override
  void setInternalController(WebViewController controller) {
    _internalController = controller;
    try {
      controller.setBackgroundColor(const Color(0xFF0F0F12));
    } catch (_) {}
    _delegate.setInternalController(controller);
  }
}

class _WebSearchPageState extends ConsumerState<WebSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final SafeAdBlockerWebviewController _adBlockerController = SafeAdBlockerWebviewController();
  String? _currentUrl;
  double _loadingProgress = 0.0;
  bool _isLoading = false;
  bool _isSupported = false;
  bool _isAdBlockerInitialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _searchController.text = widget.initialQuery!.trim();
    }
    _checkAndInitWebView();
  }

  Future<void> _checkAndInitWebView() async {
    final supported = !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);
    _isSupported = supported;

    if (supported) {
      try {
        await _adBlockerController.initialize(
          FilterConfig(filterTypes: [FilterType.easyList, FilterType.adGuard]),
        );
        if (mounted) {
          setState(() {
            _isAdBlockerInitialized = true;
          });
        }
      } catch (e) {
        debugPrint("WebSearchPage initialization error: $e");
        _isSupported = false;
        if (mounted) setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearch(String query) {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    final targetUrl = '${WebSearchPage.searchBaseUrl}${Uri.encodeComponent(cleanQuery)}';
    if (_isSupported && _isAdBlockerInitialized) {
      _adBlockerController.loadUrl(targetUrl);
    } else {
      launchUrl(Uri.parse(targetUrl), mode: LaunchMode.externalApplication);
    }
  }

  void _goHome() {
    _searchController.clear();
    if (_isSupported && _isAdBlockerInitialized) {
      _adBlockerController.loadUrl(WebSearchPage.homeUrl);
    } else {
      launchUrl(Uri.parse(WebSearchPage.homeUrl), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _handleBackNavigation() async {
    if (_isSupported && _isAdBlockerInitialized && await _adBlockerController.canGoBack()) {
      await _adBlockerController.goBack();
      return;
    }

    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      // Background or exit app if at root
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        await _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F12),
        appBar: AppBar(
          backgroundColor: const Color(0xFF141418),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.home_rounded, color: CinematicColors.primary),
            tooltip: "Pagalworld Home",
            onPressed: _goHome,
          ),
          title: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              textInputAction: TextInputAction.search,
              onSubmitted: _handleSearch,
              decoration: InputDecoration(
                hintText: "Search MP3 songs on Pagalworld...",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54, size: 18),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Colors.white54, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
          actions: [
            if (_isSupported && _isAdBlockerInitialized)
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                tooltip: "Reload Page",
                onPressed: () => _adBlockerController.reload(),
              ),
            IconButton(
              icon: const Icon(Icons.open_in_browser_rounded, color: Colors.white70),
              tooltip: "Open in Browser",
              onPressed: () {
                final text = _searchController.text.trim();
                final url = text.isNotEmpty
                    ? '${WebSearchPage.searchBaseUrl}${Uri.encodeComponent(text)}'
                    : WebSearchPage.homeUrl;
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              },
            ),
          ],
          bottom: _isLoading && _loadingProgress < 1.0
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2),
                  child: LinearProgressIndicator(
                    value: _loadingProgress,
                    backgroundColor: Colors.transparent,
                    valueColor: const AlwaysStoppedAnimation<Color>(CinematicColors.primary),
                    minHeight: 2,
                  ),
                )
              : null,
        ),
        body: _buildBody(),
        floatingActionButton: _isSupported ? _buildUseMp3Button() : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildBody() {
    if (_isSupported) {
      if (!_isAdBlockerInitialized) {
        return Container(
          color: const Color(0xFF0F0F12),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: CinematicColors.primary,
                  strokeWidth: 2.5,
                ),
                SizedBox(height: 16),
                Text(
                  "Initializing Ad-Blocker...",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        );
      }

      return Stack(
        children: [
          AdBlockerWebview(
            url: Uri.parse(WebSearchPage.homeUrl),
            adBlockerWebviewController: _adBlockerController,
            shouldBlockAds: true,
            onUrlChanged: (url) {
              if (url != null) _currentUrl = url;
            },
            onLoadStart: (url) {
              if (url != null) _currentUrl = url;
              if (mounted) setState(() => _isLoading = true);
            },
            onLoadFinished: (url) {
              if (url != null) _currentUrl = url;
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _loadingProgress = 1.0;
                });
              }
            },
            onProgress: (progress) {
              if (mounted) {
                setState(() => _loadingProgress = progress / 100.0);
              }
            },
            onLoadError: (url, code) {
              debugPrint("WebSearchPage AdBlocker error ($code): $url");
            },
          ),
          if (_isLoading && _loadingProgress < 0.3)
            Container(
              color: const Color(0xFF0F0F12),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: CinematicColors.primary,
                      strokeWidth: 2.5,
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Loading Pagalworld MP3 Portal...",
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    // Windows Desktop or unsupported platform fallback UI
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Container(
          constraints: const Duration(milliseconds: 0) == Duration.zero
              ? const BoxConstraints(maxWidth: 580)
              : null,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF18181D),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: CinematicColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.travel_explore_rounded,
                  size: 40,
                  color: CinematicColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Pagalworld Web MP3 Portal",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Search, discover, and download Indian and international MP3 audio directly via Pagalworld.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      textInputAction: TextInputAction.search,
                      onSubmitted: _handleSearch,
                      decoration: InputDecoration(
                        hintText: "Enter song or artist name...",
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CinematicColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => _handleSearch(_searchController.text),
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: const Text("Search", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: _goHome,
                icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                label: const Text("Open Pagalworld in Browser"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUseMp3Button() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: CinematicColors.primary,
        borderRadius: BorderRadius.circular(6),
        elevation: 6,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: _captureAndPlayMp3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_circle_fill_rounded, color: Colors.black, size: 20),
                SizedBox(width: 8),
                Text(
                  "Use this MP3",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _captureAndPlayMp3() async {
    String? targetUrl = _currentUrl;
    try {
      final ctrl = _adBlockerController.internalController;
      if (ctrl != null) {
        final activeUrl = await ctrl.currentUrl();
        if (activeUrl != null && activeUrl.isNotEmpty) {
          targetUrl = activeUrl;
        }

        final extracted = await ctrl.runJavaScriptReturningResult('''
          (function() {
            var loc = window.location.href || '';
            if (loc.indexOf('.mp3') !== -1) return loc;
            var audio = document.querySelector('audio source, audio');
            if (audio && (audio.src || audio.currentSrc)) return audio.src || audio.currentSrc;
            var dwn = document.querySelector('a[href*=".mp3"], a.dwn-btn, a[download*=".mp3"]');
            if (dwn && dwn.href) return dwn.href;
            return loc;
          })()
        ''');

        final clean = extracted.toString().replaceAll('"', '').trim();
        if (clean.startsWith('http://') || clean.startsWith('https://')) {
          targetUrl = clean;
        }
      }
    } catch (e) {
      debugPrint("WebSearchPage: Error extracting MP3 link: $e");
    }

    if (targetUrl == null || targetUrl.isEmpty || targetUrl == WebSearchPage.homeUrl) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please navigate to a song page or tap a download button first."),
          backgroundColor: Color(0xFF222228),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    String title = "Web MP3 Song";
    try {
      final pageTitle = await _adBlockerController.internalController?.getTitle();
      if (pageTitle != null && pageTitle.isNotEmpty) {
        title = pageTitle
            .replaceAll(RegExp(r'\s*-\s*Pagalworld.*', caseSensitive: false), '')
            .replaceAll(RegExp(r'Mp3 Song Download.*', caseSensitive: false), '')
            .trim();
        if (title.isEmpty) title = "Web MP3 Track";
      }
    } catch (_) {}

    final capturedSong = SongModel(
      id: 'web_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      artist: 'Pagalworld Web',
      album: 'Web MP3',
      durationMs: 0,
      path: targetUrl,
      sourceType: 'web_prefetch',
      externalUrl: targetUrl,
      dateAdded: DateTime.now(),
      isFavorite: false,
    );

    debugPrint("WebSearchPage: Captured MP3 URL: $targetUrl for song '${capturedSong.title}'");

    try {
      await ref.read(playerProvider.notifier).playTrack([capturedSong], 0);
    } catch (e) {
      debugPrint("WebSearchPage: Playback error: $e");
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Playing '$title' in Cinematic Player"),
        backgroundColor: CinematicColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(capturedSong);
    }
  }
}
