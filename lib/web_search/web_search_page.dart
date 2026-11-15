import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:adblocker_webview/adblocker_webview.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/database/models/song_model.dart';
import '../core/theme/cinematic_colors.dart';
import '../features/player/providers/player_provider.dart';
import '../features/library/providers/library_provider.dart';
import '../core/services/scanner_service.dart';

/// WebView-based MP3 search and download screen (Pagalworld) powered by flutter_inappwebview.
///
/// Features:
/// - Loads https://pagalworld.is/ by default with integrated ad-blocking ContentBlockers.
/// - If autoSubmit is true and initialQuery is provided, loads search results immediately without loading home first.
/// - Top search bar navigates to https://pagalworld.is/search?q=<encoded_query> on Enter.
/// - Non-http/https schemes (intent://, market://) are blocked in shouldOverrideUrlLoading to prevent ERR_UNKNOWN_URL_SCHEME.
/// - Native download interception via onDownloadStartRequest: downloads MP3 bytes, saves to device Music storage,
///   and auto-imports into the app's Local Library via ScannerService and libraryProvider.
/// - Floating "Use this MP3" button to capture current page / audio link into the player immediately.
/// - Desktop/Windows graceful fallback with direct external browser launch.
class WebSearchPage extends ConsumerStatefulWidget {
  const WebSearchPage({
    super.key,
    this.initialQuery,
    this.autoSubmit = false,
  });

  final String? initialQuery;
  final bool autoSubmit;

  static const String homeUrl = 'https://pagalworld.is/';
  static const String searchBaseUrl = 'https://pagalworld.is/search?q=';

  /// Computes the initial URL to load, ensuring search results are loaded immediately when autoSubmit is true.
  static String computeInitialUrl({String? initialQuery, bool autoSubmit = false}) {
    final query = initialQuery?.trim();
    if (autoSubmit && query != null && query.isNotEmpty) {
      return '${WebSearchPage.searchBaseUrl}${Uri.encodeComponent(query)}';
    }
    return WebSearchPage.homeUrl;
  }

  /// Validates that a navigation URL uses an allowed HTTP or HTTPS scheme.
  /// Prevents WebView crashes from Android intent schemes (e.g., intent://, market://).
  static bool isAllowedUrlScheme(String url) {
    final lower = url.trim().toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  /// Determines if a URL matches known intrusive ad networks, popunders, or redirects.
  static bool isAdUrl(String url) {
    final lower = url.toLowerCase();
    const adKeywords = [
      'doubleclick.net',
      'googlesyndication.com',
      'adnxs.com',
      'popads.net',
      'adsterra.com',
      'propellerads.com',
      'exoclick.com',
      'juicyads.com',
      'trafficjunky.com',
      'onclickpredictiv.com',
      'syndication.exoclick.com',
      'googleadservices.com',
      'adservice.google',
      '/popunder',
      'bet365',
      '1xbet',
    ];
    return adKeywords.any((kw) => lower.contains(kw));
  }

  /// Extracts and sanitizes the target MP3 filename from suggested filename or URL path.
  static String extractFilename(String url, [String? suggestedFilename]) {
    if (suggestedFilename != null && suggestedFilename.trim().isNotEmpty) {
      var name = suggestedFilename.trim();
      if (!name.toLowerCase().endsWith('.mp3')) {
        name = '$name.mp3';
      }
      return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    }

    try {
      final uri = Uri.parse(url);
      final lastSegment = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      if (lastSegment.isNotEmpty && lastSegment.toLowerCase().endsWith('.mp3')) {
        return Uri.decodeComponent(lastSegment).replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      }
    } catch (_) {}

    return 'song_${DateTime.now().millisecondsSinceEpoch}.mp3';
  }

  /// Extracts clean song title from filename by stripping the .mp3 extension and formatting.
  static String extractSongName(String filename) {
    var name = filename;
    if (name.toLowerCase().endsWith('.mp3')) {
      name = name.substring(0, name.length - 4);
    }
    return name.trim();
  }

  /// Resolves the destination directory for saved MP3 audio tracks using path_provider and system paths.
  static Future<Directory> getMusicDownloadDirectory() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await ScannerService.requestStoragePermissions();
      } catch (_) {}

      final publicMusic = Directory('/storage/emulated/0/Music');
      if (publicMusic.existsSync()) {
        return publicMusic;
      }
      try {
        await publicMusic.create(recursive: true);
        if (publicMusic.existsSync()) return publicMusic;
      } catch (_) {}

      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final musicSub = Directory(p.join(extDir.path, 'Music'));
        if (!await musicSub.exists()) await musicSub.create(recursive: true);
        return musicSub;
      }
    } else if (!kIsWeb && Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'] ?? 'C:\\Users\\Public';
      final musicDir = Directory(p.join(userProfile, 'Music'));
      if (!await musicDir.exists()) await musicDir.create(recursive: true);
      return musicDir;
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    final fallback = Directory(p.join(appDocDir.path, 'Music'));
    if (!await fallback.exists()) await fallback.create(recursive: true);
    return fallback;
  }

  @override
  ConsumerState<WebSearchPage> createState() => _WebSearchPageState();
}

/// Backward compatibility wrapper for AdBlockerWebviewController unit tests.
class SafeAdBlockerWebviewController implements AdBlockerWebviewController {
  final AdBlockerWebviewController _delegate = AdBlockerWebviewController.instance;
  dynamic _internalController;

  dynamic get internalController => _internalController;

  @override
  Future<void> initialize(FilterConfig filterConfig) => _delegate.initialize(filterConfig);

  @override
  bool shouldBlockResource(String url) {
    if (!WebSearchPage.isAllowedUrlScheme(url)) {
      debugPrint("WebSearchPage: Blocked non-http navigation scheme: $url");
      return true;
    }
    if (WebSearchPage.isAdUrl(url)) {
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
  void setInternalController(dynamic controller) {
    _internalController = controller;
  }
}

class _WebSearchPageState extends ConsumerState<WebSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  InAppWebViewController? _webViewController;
  late String _initialUrl;
  String? _currentUrl;
  double _loadingProgress = 0.0;
  bool _isLoading = false;
  bool _isSupported = false;

  static final List<ContentBlocker> _adBlockers = [
    ContentBlocker(
      trigger: ContentBlockerTrigger(
        urlFilter:
            r'.*(doubleclick\.net|googlesyndication\.com|adnxs\.com|popads\.net|adsterra\.com|propellerads\.com|exoclick\.com|juicyads\.com|trafficjunky\.com|onclickpredictiv\.com|bet365|1xbet).*',
      ),
      action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
    ),
    ContentBlocker(
      trigger: ContentBlockerTrigger(
        urlFilter: r'.*(\/ads?\/|\/banner\/|\/popunder\/|ad_frame|\/adserv|\/advertisement).*',
      ),
      action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
    ),
  ];

  @override
  void initState() {
    super.initState();
    final query = widget.initialQuery?.trim();
    if (query != null && query.isNotEmpty) {
      _searchController.text = query;
    }
    // Set initial URL immediately to search results when autoSubmit is true
    _initialUrl = WebSearchPage.computeInitialUrl(
      initialQuery: widget.initialQuery,
      autoSubmit: widget.autoSubmit,
    );
    _currentUrl = _initialUrl;
    _isSupported = !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);
  }

  @override
  void didUpdateWidget(WebSearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialQuery != oldWidget.initialQuery || widget.autoSubmit != oldWidget.autoSubmit) {
      final query = widget.initialQuery?.trim();
      if (query != null && query.isNotEmpty) {
        _searchController.text = query;
        if (widget.autoSubmit) {
          final targetUrl = WebSearchPage.computeInitialUrl(
            initialQuery: query,
            autoSubmit: true,
          );
          _initialUrl = targetUrl;
          _currentUrl = targetUrl;
          if (_isSupported && _webViewController != null) {
            _webViewController!.loadUrl(urlRequest: URLRequest(url: WebUri(targetUrl)));
          }
        }
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
    if (_isSupported && _webViewController != null) {
      _webViewController!.loadUrl(
        urlRequest: URLRequest(url: WebUri(targetUrl)),
      );
    } else {
      launchUrl(Uri.parse(targetUrl), mode: LaunchMode.externalApplication);
    }
  }

  void _goHome() {
    _searchController.clear();
    if (_isSupported && _webViewController != null) {
      _webViewController!.loadUrl(
        urlRequest: URLRequest(url: WebUri(WebSearchPage.homeUrl)),
      );
    } else {
      launchUrl(Uri.parse(WebSearchPage.homeUrl), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _handleBackNavigation() async {
    if (_isSupported && _webViewController != null && await _webViewController!.canGoBack()) {
      await _webViewController!.goBack();
      return;
    }

    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      SystemNavigator.pop();
    }
  }

  Future<void> _handleDownloadRequest(DownloadStartRequest downloadRequest) async {
    final downloadUri = downloadRequest.url;
    final urlStr = downloadUri.toString();

    if (!WebSearchPage.isAllowedUrlScheme(urlStr)) {
      debugPrint("WebSearchPage: Download rejected due to unsafe scheme: $urlStr");
      return;
    }

    final filename = WebSearchPage.extractFilename(urlStr, downloadRequest.suggestedFilename);
    final songName = WebSearchPage.extractSongName(filename);

    // 1. Request storage permissions using permission_handler
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final audioStatus = await Permission.audio.status;
        if (!audioStatus.isGranted) {
          await Permission.audio.request();
        }
        final storageStatus = await Permission.storage.status;
        if (!storageStatus.isGranted) {
          await Permission.storage.request();
        }
      } catch (e) {
        debugPrint("WebSearchPage: Permission request notice: $e");
      }
    }

    // 2. Show a SnackBar indicating the download has started
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(CinematicColors.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Downloading $songName...",
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1B1B22),
        duration: const Duration(seconds: 4),
      ),
    );

    try {
      // 3. Use http.get to download the file bytes
      final response = await http.get(
        Uri.parse(urlStr),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Referer': WebSearchPage.homeUrl,
        },
      );

      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw Exception("Download HTTP status: ${response.statusCode}");
      }

      // 4. Save the file to the Android public Music directory using path_provider
      final targetDir = await WebSearchPage.getMusicDownloadDirectory();
      final targetFile = File(p.join(targetDir.path, filename));
      await targetFile.writeAsBytes(response.bodyBytes);
      debugPrint("WebSearchPage: Successfully saved MP3 to ${targetFile.path} (${response.bodyBytes.length} bytes)");

      // 5. Crucial: Trigger a rescan of the local library so the downloaded song instantly appears in the user's Local Files tab
      await ScannerService.importFiles([targetFile]);
      ref.read(libraryProvider.notifier).refreshLibrary();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Downloaded & added to Local Library: $songName"),
          backgroundColor: CinematicColors.primary,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint("WebSearchPage: Download error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to download $songName: $e"),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 4),
        ),
      );
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
            if (_isSupported)
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                tooltip: "Reload Page",
                onPressed: () => _webViewController?.reload(),
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
      return Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(_initialUrl)),
            initialSettings: InAppWebViewSettings(
              useShouldOverrideUrlLoading: true,
              useOnDownloadStart: true,
              javaScriptEnabled: true,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              transparentBackground: false,
              useHybridComposition: true,
              contentBlockers: _adBlockers,
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
              // Ensure the WebView immediately navigates to search results without hitting home
              if (widget.autoSubmit && widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
                final targetUrl = WebSearchPage.computeInitialUrl(
                  initialQuery: widget.initialQuery,
                  autoSubmit: true,
                );
                if (_currentUrl != targetUrl) {
                  controller.loadUrl(urlRequest: URLRequest(url: WebUri(targetUrl)));
                }
              }
            },
            onLoadStart: (controller, url) {
              if (url != null) _currentUrl = url.toString();
              if (mounted) setState(() => _isLoading = true);
            },
            onLoadStop: (controller, url) {
              if (url != null) _currentUrl = url.toString();
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _loadingProgress = 1.0;
                });
              }
            },
            onProgressChanged: (controller, progress) {
              if (mounted) {
                setState(() => _loadingProgress = progress / 100.0);
              }
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final uri = navigationAction.request.url;
              if (uri == null) return NavigationActionPolicy.ALLOW;
              final urlStr = uri.toString();

              if (!WebSearchPage.isAllowedUrlScheme(urlStr)) {
                debugPrint("WebSearchPage: Blocked non-http navigation scheme: $urlStr");
                return NavigationActionPolicy.CANCEL;
              }

              if (WebSearchPage.isAdUrl(urlStr)) {
                debugPrint("WebSearchPage: Blocked ad URL: $urlStr");
                return NavigationActionPolicy.CANCEL;
              }

              return NavigationActionPolicy.ALLOW;
            },
            onDownloadStartRequest: (controller, downloadStartRequest) async {
              await _handleDownloadRequest(downloadStartRequest);
            },
            onReceivedError: (controller, request, error) {
              debugPrint("WebSearchPage load error: ${error.description}");
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
      if (_webViewController != null) {
        final activeUri = await _webViewController!.getUrl();
        if (activeUri != null && activeUri.toString().isNotEmpty) {
          targetUrl = activeUri.toString();
        }

        final extracted = await _webViewController!.evaluateJavascript(source: '''
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

        if (extracted != null) {
          final clean = extracted.toString().replaceAll('"', '').trim();
          if (clean.startsWith('http://') || clean.startsWith('https://')) {
            targetUrl = clean;
          }
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
      final pageTitle = await _webViewController?.getTitle();
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
