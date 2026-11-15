import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:adblocker_webview/adblocker_webview.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/theme/cinematic_colors.dart';

/// WebView-based MP3 search and download screen (Pagalworld) with integrated ad-blocking.
///
/// Features:
/// - Loads https://pagalworld.is/ by default with EasyList & AdGuard ad filtering.
/// - Integrated top search bar: navigates to https://pagalworld.is/search?q=<encoded_query> on Enter.
/// - Safe AdBlockerWebviewController blocking non-http/https schemes (intent://, market://) to prevent ERR_UNKNOWN_URL_SCHEME.
/// - Home button in AppBar returning to https://pagalworld.is/.
/// - System Android back button navigation in WebView history.
/// - Desktop/Windows graceful fallback with direct external browser launch.
class WebSearchPage extends StatefulWidget {
  const WebSearchPage({super.key});

  static const String homeUrl = 'https://pagalworld.is/';
  static const String searchBaseUrl = 'https://pagalworld.is/search?q=';

  /// Validates that a navigation URL uses an allowed HTTP or HTTPS scheme.
  /// Prevents WebView crashes from Android intent schemes (e.g., intent://, market://).
  static bool isAllowedUrlScheme(String url) {
    final lower = url.trim().toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  @override
  State<WebSearchPage> createState() => _WebSearchPageState();
}

/// Custom wrapper around AdBlockerWebviewController that strictly enforces
/// allowed HTTP/HTTPS URL schemes, preventing crashes on intent:// or market:// links.
class SafeAdBlockerWebviewController implements AdBlockerWebviewController {
  final AdBlockerWebviewController _delegate = AdBlockerWebviewController.instance;

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
    try {
      controller.setBackgroundColor(const Color(0xFF0F0F12));
    } catch (_) {}
    _delegate.setInternalController(controller);
  }
}

class _WebSearchPageState extends State<WebSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final SafeAdBlockerWebviewController _adBlockerController = SafeAdBlockerWebviewController();
  double _loadingProgress = 0.0;
  bool _isLoading = false;
  bool _isSupported = false;
  bool _isAdBlockerInitialized = false;

  @override
  void initState() {
    super.initState();
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
            onLoadStart: (url) {
              if (mounted) setState(() => _isLoading = true);
            },
            onLoadFinished: (url) {
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
}
