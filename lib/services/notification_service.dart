import 'dart:async';
import 'dart:convert';
// Completer imported via dart:async above
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

// ---------------------------------------------------------------------------
// EconomicEvent — economic calendar event model
// ---------------------------------------------------------------------------
class EconomicEvent {
  final String country;
  final String event;
  final String impact; // 'high' | 'medium' | 'low'
  final DateTime time;
  final String? actual;
  final String? estimate;
  final String? previous;

  const EconomicEvent({
    required this.country,
    required this.event,
    required this.impact,
    required this.time,
    this.actual,
    this.estimate,
    this.previous,
  });

  /// From Finnhub economic calendar API response
  factory EconomicEvent.fromFinnhub(Map<String, dynamic> json) {
    DateTime parsedTime;
    try {
      final raw = (json['time'] as String? ?? '').trim();
      parsedTime = DateTime.parse(raw.replaceFirst(' ', 'T')).toLocal();
    } catch (_) {
      parsedTime = DateTime.now();
    }
    final impact = (json['impact'] as String? ?? 'low').toLowerCase();
    return EconomicEvent(
      country: json['country'] as String? ?? '',
      event: json['event'] as String? ?? '',
      impact: impact == 'high' ? 'high' : impact == 'medium' ? 'medium' : 'low',
      time: parsedTime,
      actual: json['actual']?.toString(),
      estimate: json['estimate']?.toString(),
      previous: json['prev']?.toString(),
    );
  }

  /// From TradingView Economic Calendar API
  factory EconomicEvent.fromTradingView(Map<String, dynamic> json) {
    DateTime parsedTime;
    try {
      parsedTime = DateTime.parse(json['date'] as String? ?? '').toLocal();
    } catch (_) {
      parsedTime = DateTime.now();
    }
    // TradingView uses "importance" with scale: -1=low, 0=medium, 1=high
    final impactNum = (json['importance'] as num?)?.toInt()
        ?? (json['impact'] as num?)?.toInt()
        ?? -1;
    final impact = impactNum >= 1 ? 'high' : impactNum == 0 ? 'medium' : 'low';
    return EconomicEvent(
      country: json['country'] as String? ?? '',
      event: json['title'] as String? ?? '',
      impact: impact,
      time: parsedTime,
      actual: json['actual']?.toString(),
      estimate: json['forecast']?.toString(),
      previous: json['prev']?.toString(),
    );
  }

  /// From ForexFactory JSON feed
  factory EconomicEvent.fromForexFactory(Map<String, dynamic> json) {
    DateTime parsedTime;
    try {
      parsedTime = DateTime.parse(json['date'] as String? ?? '').toLocal();
    } catch (_) {
      parsedTime = DateTime.now();
    }
    final impactRaw = (json['impact']?.toString() ?? '').toLowerCase().trim();
    final impact = (impactRaw.contains('high') || impactRaw == '3')
        ? 'high'
        : (impactRaw.contains('medium') || impactRaw.contains('moderate') || impactRaw == '2')
            ? 'medium'
            : 'low';
    return EconomicEvent(
      country: json['country'] as String? ?? '',
      event: json['title'] as String? ?? '',
      impact: impact,
      time: parsedTime,
      actual: null,
      estimate: (json['forecast'] as String?)?.isNotEmpty == true
          ? json['forecast'] as String
          : null,
      previous: (json['previous'] as String?)?.isNotEmpty == true
          ? json['previous'] as String
          : null,
    );
  }

  factory EconomicEvent.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('title') && json.containsKey('date')) {
      return EconomicEvent.fromForexFactory(json);
    }
    if (json.containsKey('time') && json.containsKey('impact')) {
      return EconomicEvent.fromFinnhub(json);
    }
    DateTime parsedTime;
    try {
      final raw = (json['time'] as String? ?? '').trim();
      parsedTime = DateTime.parse(raw.replaceFirst(' ', 'T')).toLocal();
    } catch (_) {
      parsedTime = DateTime.now();
    }
    return EconomicEvent(
      country: json['country'] as String? ?? '',
      event: json['event'] as String? ?? '',
      impact: (json['impact'] as String? ?? 'low').toLowerCase(),
      time: parsedTime,
      actual: json['actual'] as String?,
      estimate: json['estimate'] as String?,
      previous: json['previous'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// NewsArticle — financial news from RSS feeds
// ---------------------------------------------------------------------------
class NewsArticle {
  final String title;
  final String url;
  final String source;
  final DateTime publishedAt;
  final String? summary;

  const NewsArticle({
    required this.title,
    required this.url,
    required this.source,
    required this.publishedAt,
    this.summary,
  });
}

// ---------------------------------------------------------------------------
// NotificationService
// ---------------------------------------------------------------------------
class NotificationService {
  static bool _initialized = false;
  static String? _fcmToken;
  static Timer? _monitoringTimer;
  static Timer? _dailyRefreshTimer;

  // Finnhub API key (set via setFinnhubKey before use)
  static String _finnhubKey = '';
  static void setFinnhubKey(String key) => _finnhubKey = key;

  static final Set<String> _sentNotificationIds = {};

  // ---------------------------------------------------------------------------
  // Notification preferences cache — avoids hitting Supabase on every send.
  // Refreshed on initialize() and invalidated whenever the user saves prefs.
  // ---------------------------------------------------------------------------
  static Map<String, dynamic>? _prefCache;

  /// Reload prefs from Supabase into the in-memory cache.
  static Future<void> refreshPrefsCache() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final data = await Supabase.instance.client
          .from('notification_prefs')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      _prefCache = data;
    } catch (_) {}
  }

  /// Synchronous pref check (returns true by default — fail-open).
  static bool isPrefEnabled(String key) => _prefCache?[key] as bool? ?? true;

  /// Call this after the user saves notification prefs so the cache is fresh.
  static void invalidatePrefsCache() => _prefCache = null;

  /// Returns true if the user's saved locale is Italian.
  static Future<bool> _isIt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getString('locale') ?? 'en') == 'it';
    } catch (_) {
      return false;
    }
  }
  static String _t(bool isIt, String en, String it) => isIt ? it : en;

  // 30-day event cache — TTL 60 minutes
  static List<EconomicEvent>? _cachedMonthEvents;
  static DateTime? _cacheTime;
  static const _cacheTtl = Duration(minutes: 60);
  // In-flight deduplication: if a fetch is already running, all callers share the same Future
  static Completer<List<EconomicEvent>>? _fetchMonthInFlight;

  static final FlutterLocalNotificationsPlugin _fln =
      FlutterLocalNotificationsPlugin();

  static const _channelId   = 'piplock_v2';
  static const _channelName = 'PipLock Alerts';
  static const _channelDesc = 'Economic news and risk management alerts';

  // Scheduled notification ID range (avoids collision with session reminder = 9901)
  static const int _scheduledNotifBaseId = 10000;
  static const int _scheduledNotifMaxId  = 99999;

  static const _ffBaseUrl = 'https://nfs.faireconomy.media';
  static const _finnhubBaseUrl = 'https://finnhub.io/api/v1';
  static const _tvCalendarUrl = 'https://economic-calendar.tradingview.com/events';

  // News cache — TTL 60 minutes
  static List<NewsArticle>? _cachedNews;
  static DateTime? _newsCacheTime;
  static const _newsCacheTtl = Duration(minutes: 60);

  static const _newsRssSources = <(String, String)>[
    ('ForexLive', 'https://www.forexlive.com/feed/'),
    ('FXStreet', 'https://www.fxstreet.com/rss/news'),
    ('MarketWatch', 'https://feeds.marketwatch.com/marketwatch/topstories/'),
  ];

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------
  static Future<void> initialize() async {
    if (_initialized) return;

    try { tz_data.initializeTimeZones(); } catch (_) {}

    // Flutter Local Notifications
    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      await _fln.initialize(initSettings);

      await _fln
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.max,
        playSound: true,
      );
      await _fln
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      debugPrint('[NotificationService] Flutter Local Notifications OK');
    } catch (e) {
      debugPrint('[NotificationService] flutter_local_notifications error: $e');
    }

    // Firebase Messaging
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      _fcmToken = await messaging.getToken().timeout(
        const Duration(seconds: 4),
        onTimeout: () => null,
      );
      debugPrint('[NotificationService] FCM token: $_fcmToken');

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null && _fcmToken != null) {
        await Supabase.instance.client.from('notification_prefs').upsert(
          {'user_id': userId, 'fcm_token': _fcmToken},
          onConflict: 'user_id',
        );
      }

      // Load prefs so isPrefEnabled() works synchronously right away
      await refreshPrefsCache();

      FirebaseMessaging.onMessage.listen(_handleForegroundFcmMessage);
      debugPrint('[NotificationService] Firebase Messaging OK');
    } catch (e) {
      debugPrint('[NotificationService] Firebase not available ($e)');
    }

    _initialized = true;
  }

  static void _handleForegroundFcmMessage(RemoteMessage message) {
    if (message.notification != null) {
      showLocalNotification(
        title: message.notification!.title ?? 'PipLock',
        body: message.notification!.body ?? '',
        id: message.hashCode,
      );
    }
  }

  static Future<String?> getToken() async => _fcmToken;

  // ---------------------------------------------------------------------------
  // Immediate local notification
  // ---------------------------------------------------------------------------
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    int? id,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        ticker: title,
      );
      final details = NotificationDetails(android: androidDetails);
      await _fln.show(
        id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        details,
      );
    } catch (e) {
      debugPrint('[NotificationService] Notification error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // In-app monitoring — check every 5 minutes (only while app is open)
  // Daily refresh of the scheduled notification list
  // ---------------------------------------------------------------------------
  static void startFinnhubMonitoring() {
    // Delay the first check by 15s: scheduleUpcomingNotifications() is called
    // in MainNavScreen after ~4s; this gives it time to populate the cache first.
    Future.delayed(const Duration(seconds: 15), _checkUpcomingEvents);
    _monitoringTimer?.cancel();
    _monitoringTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _checkUpcomingEvents(),
    );

    // Refresh every 6 hours: invalidate cache and reschedule all notifications
    _dailyRefreshTimer?.cancel();
    _dailyRefreshTimer = Timer.periodic(
      const Duration(hours: 6),
      (_) async {
        debugPrint('[NotificationService] 6h refresh — updating calendar');
        _cachedMonthEvents = null;
        _cacheTime = null;
        await scheduleUpcomingNotifications();
      },
    );

    debugPrint('[NotificationService] Monitoring started (5 min check, 6h refresh)');
  }

  static void stopFinnhubMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _dailyRefreshTimer?.cancel();
    _dailyRefreshTimer = null;
  }

  /// Scrive i timestamp degli eventi high-impact passati recentemente (ultimi 45 min)
  /// e futuri (prossime 24h) in SharedPreferences, nella chiave 'upcoming_events'
  /// di 'piplock_news_cache'. L'AccessibilityService Kotlin legge questi timestamp
  /// per rilevare il pattern FOMO (finestra T+2 a T+30 minuti dopo l'evento).
  ///
  /// Formato: JSON array di int (millisecondsSinceEpoch)
  /// Esempio: [1720000000000, 1720003600000]
  static Future<void> _writeNewsTimestampsToPrefs(List<EconomicEvent> events) async {
    try {
      final now = DateTime.now();
      final timestamps = events
          .where((e) => e.impact == 'high')
          .where((e) {
            final diff = e.time.difference(now);
            // Include: eventi passati nelle ultime 45 min (finestra FOMO post-news)
            //          ed eventi futuri nelle prossime 24h (per check pre-sessione)
            return diff.inMinutes >= -45 && diff.inHours <= 24;
          })
          .map((e) => e.time.millisecondsSinceEpoch)
          .toList();

      final prefs = await SharedPreferences.getInstance();
      // Nota: il pref-file di default Flutter ('FlutterSharedPreferences') viene
      // letto dal Kotlin come 'FlutterSharedPreferences' con prefisso 'flutter.'
      // Per semplicità usiamo la stessa istanza — Kotlin deve leggere da
      // getSharedPreferences('FlutterSharedPreferences', MODE_PRIVATE)
      // con chiave 'flutter.piplock_news_upcoming'.
      await prefs.setString('piplock_news_upcoming', jsonEncode(timestamps));
      debugPrint('[NotificationService] News timestamps scritti: ${timestamps.length} eventi high-impact');
    } catch (e) {
      debugPrint('[NotificationService] _writeNewsTimestampsToPrefs error: $e');
    }
  }

  static Future<void> _checkUpcomingEvents() async {
    if (!isPrefEnabled('news_alerts')) return;
    try {
      final isIt = await _isIt();
      final events = await _fetchMonth();
      final now = DateTime.now();

      for (final e in events) {
        if (e.impact == 'low') continue;
        final diff = e.time.difference(now);
        if (diff.inMinutes < 5 || diff.inMinutes > 30) continue;

        final notifId = '${e.event}_${e.time.toIso8601String()}';
        if (_sentNotificationIds.contains(notifId)) continue;
        _sentNotificationIds.add(notifId);

        final minLabel = _t(isIt, 'in ${diff.inMinutes} min', 'tra ${diff.inMinutes} min');
        final isHigh = e.impact == 'high';
        await showLocalNotification(
          id: e.time.millisecondsSinceEpoch.remainder(100000),
          title: isHigh
              ? _t(isIt, '⚠️ Upcoming news: ${e.event}', '⚠️ Notizie imminenti: ${e.event}')
              : _t(isIt, '📊 News coming up: ${e.event}', '📊 Notizie in arrivo: ${e.event}'),
          body: _t(isIt,
              '${e.country.toUpperCase()} · $minLabel · Watch out for volatility.',
              '${e.country.toUpperCase()} · $minLabel · Attenzione alla volatilità.'),
        );
        debugPrint('[NotificationService] Alert: ${e.event} $minLabel');
      }

      // Scrivi sempre i timestamp in SharedPreferences, così l'AccessibilityService
      // Kotlin può rilevare il pattern FOMO anche quando l'app è in background.
      await _writeNewsTimestampsToPrefs(events);
    } catch (err) {
      debugPrint('[NotificationService] _checkUpcomingEvents error: $err');
    }
  }

  // ---------------------------------------------------------------------------
  // Pre-schedule notifications — works even when app is closed
  //
  // Cancels all previously scheduled notifications, then for every HIGH-impact
  // event in the next 30 days schedules:
  //   • a notification 60 min before
  //   • a notification 15 min before
  // ---------------------------------------------------------------------------
  static Future<void> scheduleUpcomingNotifications() async {
    try {
      // Cancel previously scheduled economic calendar notifications
      final pending = await _fln.pendingNotificationRequests();
      for (final n in pending) {
        if (n.id >= _scheduledNotifBaseId && n.id <= _scheduledNotifMaxId) {
          await _fln.cancel(n.id);
        }
      }

      // If the user has disabled news alerts, leave them all cancelled and stop.
      if (!isPrefEnabled('news_alerts')) {
        debugPrint('[NotificationService] news_alerts disabled — skipping schedule');
        return;
      }

      final isIt = await _isIt();

      final events = await _fetchMonth();
      final now = DateTime.now();
      final cutoff = now.add(const Duration(days: 30));

      int scheduled = 0;
      for (final e in events) {
        if (e.impact == 'low') continue;
        if (e.time.isBefore(now)) continue;
        if (e.time.isAfter(cutoff)) continue;

        final timeLabel =
            '${e.time.hour.toString().padLeft(2, '0')}:${e.time.minute.toString().padLeft(2, '0')}';
        final isHigh = e.impact == 'high';

        // 60-minute warning (high impact only)
        if (isHigh) {
          final notif60 = e.time.subtract(const Duration(minutes: 60));
          if (notif60.isAfter(now)) {
            final id60 = _stableId(e, suffix: 60);
            await _scheduleExact(
              id: id60,
              title: _t(isIt, '📅 High-impact news in 1 hour: ${e.event}', '📅 Notizie ad alto impatto tra 1 ora: ${e.event}'),
              body: _t(isIt, '${e.country.toUpperCase()} · $timeLabel · Prepare your plan.', '${e.country.toUpperCase()} · $timeLabel · Prepara il tuo piano.'),
              scheduledTime: notif60,
            );
            scheduled++;
          }
        }

        // 15-minute warning (high = ⚠️, medium = 📊)
        final notif15 = e.time.subtract(const Duration(minutes: 15));
        if (notif15.isAfter(now)) {
          final id15 = _stableId(e, suffix: 15);
          await _scheduleExact(
            id: id15,
            title: isHigh
                ? _t(isIt, '⚠️ News in 15 minutes: ${e.event}', '⚠️ Notizie tra 15 minuti: ${e.event}')
                : _t(isIt, '📊 Medium-impact news in 15 min: ${e.event}', '📊 Notizie a medio impatto tra 15 min: ${e.event}'),
            body: _t(isIt, '${e.country.toUpperCase()} · $timeLabel · Watch for volatility.', '${e.country.toUpperCase()} · $timeLabel · Attenzione alla volatilità.'),
            scheduledTime: notif15,
          );
          scheduled++;
        }
      }

      debugPrint('[NotificationService] Scheduled $scheduled notifications (30 days)');
    } catch (e) {
      debugPrint('[NotificationService] scheduleUpcomingNotifications error: $e');
    }
  }

  /// Generates a stable notification ID in [_scheduledNotifBaseId, _scheduledNotifMaxId]
  static int _stableId(EconomicEvent e, {required int suffix}) {
    final hash = '${e.event}_${e.time.millisecondsSinceEpoch}_$suffix'.hashCode.abs();
    return _scheduledNotifBaseId +
        hash % (_scheduledNotifMaxId - _scheduledNotifBaseId);
  }

  static Future<void> _scheduleExact({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    try {
      final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);
      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        fullScreenIntent: false,
        ticker: title,
      );
      await _fln.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        NotificationDetails(android: androidDetails),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('[NotificationService] _scheduleExact error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Primary source: Finnhub economic calendar (full date-range query)
  // Fallback: ForexFactory this-month + next-month JSON feeds
  // ---------------------------------------------------------------------------

  /// Returns all events in the next 30 days, with 60-minute cache.
  /// Uses a Completer to deduplicate concurrent requests — if a fetch is already
  /// in progress (e.g. two callers at startup), all waiters share the same Future.
  // Retry state: how many auto-retries have been attempted after an empty result
  static int _fetchRetryCount = 0;
  static const _fetchMaxRetries = 3;
  static const _fetchRetryDelays = [30, 90, 300]; // seconds

  static Future<List<EconomicEvent>> _fetchMonth() async {
    if (_cachedMonthEvents != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheTtl) {
      return _cachedMonthEvents!;
    }

    // Another fetch is already in flight — join it instead of making a second request
    if (_fetchMonthInFlight != null) {
      return _fetchMonthInFlight!.future;
    }

    final completer = Completer<List<EconomicEvent>>();
    _fetchMonthInFlight = completer;

    try {
      final result = await _doFetchMonth();
      completer.complete(result);
      // If all sources returned empty (likely a network-not-ready transient failure),
      // schedule an automatic retry with backoff, up to _fetchMaxRetries times.
      if (result.isEmpty && _fetchRetryCount < _fetchMaxRetries) {
        final delaySeconds = _fetchRetryDelays[_fetchRetryCount];
        _fetchRetryCount++;
        debugPrint('[NotificationService] Empty result — retry #$_fetchRetryCount in ${delaySeconds}s');
        Future.delayed(Duration(seconds: delaySeconds), () async {
          // Only retry if still no cached data
          if (_cachedMonthEvents == null || _cachedMonthEvents!.isEmpty) {
            _cachedMonthEvents = null;
            _cacheTime = null;
            try {
              await scheduleUpcomingNotifications();
            } catch (_) {}
          }
        });
      } else if (result.isNotEmpty) {
        _fetchRetryCount = 0; // reset on success
      }
      return result;
    } catch (e) {
      completer.completeError(e);
      // Schedule retry on exception too
      if (_fetchRetryCount < _fetchMaxRetries) {
        final delaySeconds = _fetchRetryDelays[_fetchRetryCount];
        _fetchRetryCount++;
        debugPrint('[NotificationService] Fetch error — retry #$_fetchRetryCount in ${delaySeconds}s');
        Future.delayed(Duration(seconds: delaySeconds), () async {
          _cachedMonthEvents = null;
          _cacheTime = null;
          try { await scheduleUpcomingNotifications(); } catch (_) {}
        });
      }
      rethrow;
    } finally {
      _fetchMonthInFlight = null;
    }
  }

  static Future<List<EconomicEvent>> _doFetchMonth() async {
    final now = DateTime.now();
    final from = now;
    final to = now.add(const Duration(days: 30));

    List<EconomicEvent> events = [];

    // Primary: TradingView Economic Calendar (free, no key needed)
    events = await _fetchTradingView(from, to);
    debugPrint('[NotificationService] TradingView returned ${events.length} events');

    // Fallback 1: Finnhub
    if (events.isEmpty && _finnhubKey.isNotEmpty) {
      events = await _fetchFinnhub(from, to);
      debugPrint('[NotificationService] Finnhub returned ${events.length} events');
    }

    // Fallback 2: ForexFactory
    if (events.isEmpty) {
      debugPrint('[NotificationService] Falling back to ForexFactory monthly feeds');
      events = await _fetchForexFactoryMonthly();
    }

    // Filter to the 30-day window
    final windowStart = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 1));
    final windowEnd = to;
    final filtered = events
        .where((e) => e.time.isAfter(windowStart) && e.time.isBefore(windowEnd))
        .toList();
    filtered.sort((a, b) => a.time.compareTo(b.time));

    _cachedMonthEvents = filtered;
    _cacheTime = DateTime.now();
    debugPrint('[NotificationService] Loaded ${filtered.length} events (30 days)');
    return filtered;
  }

  // ---------------------------------------------------------------------------
  // TradingView Economic Calendar (primary source, free, no API key)
  // ---------------------------------------------------------------------------

  static Future<List<EconomicEvent>> _fetchTradingView(
      DateTime from, DateTime to) async {
    try {
      String iso(DateTime d) {
        final u = d.toUtc();
        return '${u.year}-${u.month.toString().padLeft(2,'0')}-${u.day.toString().padLeft(2,'0')}'
               'T${u.hour.toString().padLeft(2,'0')}:${u.minute.toString().padLeft(2,'0')}:00.000Z';
      }
      const countries =
          'US,EU,GB,JP,CN,CA,AU,NZ,CH,DE,FR,IT,ES,KR,SG,HK,MX,BR,IN,ZA,SE,NO';
      final url = Uri.parse(
        '$_tvCalendarUrl?from=${iso(from)}&to=${iso(to)}&countries=$countries',
      );
      final resp = await http.get(url, headers: {
        'Accept': 'application/json',
        'User-Agent': 'Mozilla/5.0 PipLockApp/1.0',
        'Origin': 'https://www.tradingview.com',
        'Referer': 'https://www.tradingview.com/',
      }).timeout(const Duration(seconds: 20));

      if (resp.statusCode == 200) {
        final raw = jsonDecode(resp.body);
        List<dynamic> list;
        if (raw is List) {
          list = raw;
        } else if (raw is Map && raw.containsKey('result')) {
          list = raw['result'] as List<dynamic>? ?? [];
        } else {
          list = [];
        }
        return list
            .map((e) => EconomicEvent.fromTradingView(e as Map<String, dynamic>))
            .where((e) => e.event.isNotEmpty)
            .toList();
      }
      debugPrint('[NotificationService] TradingView HTTP ${resp.statusCode}');
    } catch (e) {
      debugPrint('[NotificationService] TradingView error: $e');
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // News RSS feeds (ForexLive, FXStreet, MarketWatch)
  // ---------------------------------------------------------------------------

  /// Returns latest financial news, sorted by date, with 60-min cache.
  static Future<List<NewsArticle>> fetchLatestNews() async {
    if (_cachedNews != null &&
        _newsCacheTime != null &&
        DateTime.now().difference(_newsCacheTime!) < _newsCacheTtl) {
      return _cachedNews!;
    }

    final results = await Future.wait(
      _newsRssSources.map((s) => _fetchRss(s.$1, s.$2)),
      eagerError: false,
    );

    final seen = <String>{};
    final all = <NewsArticle>[];
    for (final list in results) {
      for (final a in list) {
        final key = a.title.toLowerCase().replaceAll(RegExp(r'\s+'), '');
        if (seen.add(key)) all.add(a);
      }
    }
    all.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    final news = all.take(40).toList();

    _cachedNews = news;
    _newsCacheTime = DateTime.now();
    debugPrint('[NotificationService] Loaded ${news.length} news articles');
    return news;
  }

  static Future<List<NewsArticle>> _fetchRss(
      String source, String url) async {
    try {
      final resp = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Mozilla/5.0 PipLockApp/1.0'},
      ).timeout(const Duration(seconds: 12));

      if (resp.statusCode != 200) {
        debugPrint('[NotificationService] RSS $source HTTP ${resp.statusCode}');
        return [];
      }

      final items = _parseRssItems(resp.body);
      return items.map((item) {
        DateTime dt;
        try { dt = _parseRssDate(item['pubDate'] ?? ''); } catch (_) { dt = DateTime.now(); }
        final summary = _stripHtml(item['description'] ?? '');
        return NewsArticle(
          title: _stripHtml(item['title'] ?? ''),
          url: (item['link'] ?? '').trim(),
          source: source,
          publishedAt: dt.toLocal(),
          summary: summary.isEmpty ? null : summary,
        );
      }).where((a) => a.title.isNotEmpty).toList();
    } catch (e) {
      debugPrint('[NotificationService] RSS $source error: $e');
      return [];
    }
  }

  static List<Map<String, String>> _parseRssItems(String xmlContent) {
    final items = <Map<String, String>>[];
    final itemRx = RegExp(r'<item[^>]*>([\s\S]*?)<\/item>');
    final titleRx = RegExp(r'<title>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/title>');
    final linkRx  = RegExp(r'<link>([\s\S]*?)<\/link>');
    final dateRx  = RegExp(r'<pubDate>([\s\S]*?)<\/pubDate>');
    final descRx  = RegExp(r'<description>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/description>');

    for (final m in itemRx.allMatches(xmlContent)) {
      final content = m.group(1) ?? '';
      final title = titleRx.firstMatch(content)?.group(1)?.trim() ?? '';
      if (title.isEmpty) continue;
      items.add({
        'title': title,
        'link': linkRx.firstMatch(content)?.group(1)?.trim() ?? '',
        'pubDate': dateRx.firstMatch(content)?.group(1)?.trim() ?? '',
        'description': descRx.firstMatch(content)?.group(1)?.trim() ?? '',
      });
    }
    return items;
  }

  static DateTime _parseRssDate(String raw) {
    if (raw.isEmpty) return DateTime.now();
    try { return DateTime.parse(raw); } catch (_) {}
    // RFC 822: "Fri, 22 Aug 2026 10:30:00 +0000"
    try {
      const months = {
        'Jan':1,'Feb':2,'Mar':3,'Apr':4,'May':5,'Jun':6,
        'Jul':7,'Aug':8,'Sep':9,'Oct':10,'Nov':11,'Dec':12,
      };
      final p = raw.replaceAll(',', '').trim().split(RegExp(r'\s+'));
      final day   = int.parse(p[1]);
      final month = months[p[2]] ?? 1;
      final year  = int.parse(p[3]);
      final tp    = p[4].split(':');
      return DateTime.utc(year, month, day, int.parse(tp[0]), int.parse(tp[1]),
          tp.length > 2 ? int.parse(tp[2]) : 0);
    } catch (_) {}
    return DateTime.now();
  }

  static String _stripHtml(String html) => html
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Invalidate news cache
  static void invalidateNewsCache() {
    _cachedNews = null;
    _newsCacheTime = null;
  }

  /// Fetch from Finnhub /calendar/economic with from/to date range
  static Future<List<EconomicEvent>> _fetchFinnhub(
      DateTime from, DateTime to) async {
    try {
      String fmt(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      // Fetch in two calls: current month and next month range to stay within free-tier limits
      final results = await Future.wait([
        _fetchFinnhubChunk(fmt(from), fmt(to)),
      ]);

      final seen = <String>{};
      final merged = <EconomicEvent>[];
      for (final list in results) {
        for (final e in list) {
          final key = '${e.event}_${e.time.toIso8601String()}_${e.country}';
          if (seen.add(key)) merged.add(e);
        }
      }
      return merged;
    } catch (e) {
      debugPrint('[NotificationService] Finnhub fetch error: $e');
      return [];
    }
  }

  static Future<List<EconomicEvent>> _fetchFinnhubChunk(
      String from, String to) async {
    try {
      final url = Uri.parse(
        '$_finnhubBaseUrl/calendar/economic?from=$from&to=$to&token=$_finnhubKey',
      );
      final resp = await http.get(url, headers: {
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final list = body['economicCalendar'] as List<dynamic>? ?? [];
        return list
            .map((e) => EconomicEvent.fromFinnhub(e as Map<String, dynamic>))
            .toList();
      }
      debugPrint('[NotificationService] Finnhub $from→$to: HTTP ${resp.statusCode}');
    } catch (e) {
      debugPrint('[NotificationService] Finnhub chunk error ($from→$to): $e');
    }
    return [];
  }

  /// Fallback: ForexFactory this-month + next-month feeds
  static Future<List<EconomicEvent>> _fetchForexFactoryMonthly() async {
    final results = await Future.wait([
      _fetchWeek('$_ffBaseUrl/ff_calendar_thisweek.json'),
      _fetchWeek('$_ffBaseUrl/ff_calendar_nextweek.json'),
      _fetchWeek('$_ffBaseUrl/ff_calendar_thismonth.json'),
      _fetchWeek('$_ffBaseUrl/ff_calendar_nextmonth.json'),
      // Additional URL patterns used by different FF mirrors
      _fetchWeek('$_ffBaseUrl/ff_calendar_next_month.json'),
      _fetchWeek('$_ffBaseUrl/ff_calendar_next_week.json'),
    ], eagerError: false);

    final seen = <String>{};
    final merged = <EconomicEvent>[];
    for (final list in results) {
      for (final e in list) {
        final key = '${e.event}_${e.time.toIso8601String()}_${e.country}';
        if (seen.add(key)) merged.add(e);
      }
    }
    return merged;
  }

  static Future<List<EconomicEvent>> _fetchWeek(String url) async {
    try {
      final resp = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 PipLockApp/1.0',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final raw = jsonDecode(resp.body) as List<dynamic>;
        return raw
            .map((e) => EconomicEvent.fromForexFactory(e as Map<String, dynamic>))
            .toList();
      }
      debugPrint('[NotificationService] $url → ${resp.statusCode}');
    } catch (e) {
      debugPrint('[NotificationService] Fetch error ($url): $e');
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // Public API for screens
  // ---------------------------------------------------------------------------

  /// All events in the next 30 days (all impacts, sorted by date).
  static Future<List<EconomicEvent>> fetchEconomicCalendar() => _fetchMonth();

  /// Only HIGH-impact events in the next 30 days.
  static Future<List<EconomicEvent>> fetchEconomicEvents() async {
    final all = await _fetchMonth();
    return all.where((e) => e.impact == 'high').toList();
  }

  static Future<bool> hasUpcomingHighImpactEvent() async {
    final events = await fetchEconomicEvents();
    final now = DateTime.now();
    return events.any((e) {
      final diff = e.time.difference(now);
      return diff.inMinutes > 0 && diff.inMinutes <= 30;
    });
  }

  /// Invalidate cache and reschedule all notifications (e.g. after manual refresh)
  static Future<void> refresh() async {
    _cachedMonthEvents = null;
    _cacheTime = null;
    _cachedNews = null;
    _newsCacheTime = null;
    await scheduleUpcomingNotifications();
  }

  // ---------------------------------------------------------------------------
  // Killswitch unlock reminder — 30 min before unlock
  // ---------------------------------------------------------------------------

  static Future<void> scheduleUnlockReminder(DateTime unlockAt) async {
    if (!isPrefEnabled('risk_warnings')) return;
    try {
      final isIt = await _isIt();
      final tzTime = tz.TZDateTime.from(unlockAt, tz.local);
      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        ticker: _t(isIt, 'Killswitch ending soon', 'Killswitch in scadenza'),
      );
      await _fln.zonedSchedule(
        8002,
        _t(isIt, '🔓 Killswitch ending in 30 minutes', '🔓 Killswitch in scadenza tra 30 minuti'),
        _t(isIt, 'Your trading block will be lifted soon. Prepare your plan.', 'Il blocco di trading sarà rimosso presto. Prepara il tuo piano.'),
        tzTime,
        NotificationDetails(android: androidDetails),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('[NotificationService] scheduleUnlockReminder error: $e');
    }
  }

  static Future<void> cancelUnlockReminder() async {
    await _fln.cancel(8002);
  }

  /// Notifica immediata quando il killswitch scade naturalmente (non con token).
  static Future<void> sendKillswitchLiftedNotification() async {
    if (!isPrefEnabled('risk_warnings')) return;
    try {
      final isIt = await _isIt();
      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        ticker: _t(isIt, 'Killswitch lifted', 'Killswitch rimosso'),
      );
      await _fln.show(
        8003,
        _t(isIt, '🔓 Killswitch lifted — you can trade again', '🔓 Killswitch rimosso — puoi tornare a fare trading'),
        _t(isIt, 'Your trading block has expired. Stay disciplined.', 'Il blocco di trading è scaduto. Rimani disciplinato.'),
        NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint('[NotificationService] sendKillswitchLiftedNotification error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Session reminder — 15 min before session start
  // ---------------------------------------------------------------------------
  static Future<void> scheduleSessionReminder({
    required int startHour,
    required int startMinute,
  }) async {
    const id = 9901;
    await _fln.cancel(id);
    if (!isPrefEnabled('session_changes')) return;

    var notifHour   = startHour;
    var notifMinute = startMinute - 15;
    if (notifMinute < 0) { notifMinute += 60; notifHour -= 1; }
    if (notifHour < 0) notifHour = 23;

    final now = DateTime.now();
    var notifTime = DateTime(now.year, now.month, now.day, notifHour, notifMinute);
    if (notifTime.isBefore(now)) {
      notifTime = notifTime.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'session_reminder',
      'Session Reminder',
      channelDescription: '15-minute warning before your trading session starts',
      importance: Importance.high,
      priority: Priority.high,
    );

    try {
      final isIt = await _isIt();
      final scheduledDate = tz.TZDateTime.from(notifTime, tz.local);
      await _fln.zonedSchedule(
        id,
        _t(isIt, '⏰ Session starts in 15 minutes', '⏰ La sessione inizia tra 15 minuti'),
        _t(isIt, 'Your trading session is about to begin. Do you have a plan for today? 📋', 'La tua sessione di trading sta per iniziare. Hai un piano per oggi? 📋'),
        scheduledDate,
        const NotificationDetails(android: androidDetails),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      debugPrint('[NotificationService] Session reminder → $notifHour:${notifMinute.toString().padLeft(2, '0')}');
    } catch (e) {
      debugPrint('[NotificationService] scheduleSessionReminder error: $e');
    }
  }

  static Future<void> cancelSessionReminder() async {
    await _fln.cancel(9901);
  }

  // ---------------------------------------------------------------------------
  // Session end notification — at exact tradingHoursEnd time, daily repeat
  // ---------------------------------------------------------------------------
  static Future<void> scheduleSessionEndNotification({
    required int endHour,
    required int endMinute,
  }) async {
    const id = 9902;
    await _fln.cancel(id);
    if (!isPrefEnabled('session_changes')) return;

    final now = DateTime.now();
    var notifTime = DateTime(now.year, now.month, now.day, endHour, endMinute);
    if (notifTime.isBefore(now)) {
      notifTime = notifTime.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'session_reminder',
      'Session Reminder',
      channelDescription: '15-minute warning before your trading session starts',
      importance: Importance.max,
      priority: Priority.high,
    );

    try {
      final isIt = await _isIt();
      final scheduledDate = tz.TZDateTime.from(notifTime, tz.local);
      await _fln.zonedSchedule(
        id,
        _t(isIt, '⛔ Trading session ended', '⛔ Sessione di trading conclusa'),
        _t(isIt,
          'Close all open positions now — trading hours are over',
          'Chiudi ora tutte le posizioni aperte — orario di trading terminato'),
        scheduledDate,
        const NotificationDetails(android: androidDetails),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      debugPrint('[NotificationService] Session end notif → $endHour:${endMinute.toString().padLeft(2, '0')}');
    } catch (e) {
      debugPrint('[NotificationService] scheduleSessionEndNotification error: $e');
    }
  }

  static Future<void> cancelSessionEndNotification() async {
    await _fln.cancel(9902);
  }
}
