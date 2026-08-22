import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
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

  // 30-day event cache — TTL 60 minutes
  static List<EconomicEvent>? _cachedMonthEvents;
  static DateTime? _cacheTime;
  static const _cacheTtl = Duration(minutes: 60);

  static final FlutterLocalNotificationsPlugin _fln =
      FlutterLocalNotificationsPlugin();

  static const _channelId   = 'piplock_alerts';
  static const _channelName = 'PipLock Alerts';
  static const _channelDesc = 'Economic news and risk management alerts';

  // Scheduled notification ID range (avoids collision with session reminder = 9901)
  static const int _scheduledNotifBaseId = 10000;
  static const int _scheduledNotifMaxId  = 99999;

  static const _ffBaseUrl = 'https://nfs.faireconomy.media';
  static const _finnhubBaseUrl = 'https://finnhub.io/api/v1';

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
        importance: Importance.high,
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
      _fcmToken = await messaging.getToken();
      debugPrint('[NotificationService] FCM token: $_fcmToken');

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null && _fcmToken != null) {
        await Supabase.instance.client.from('notification_prefs').upsert(
          {'user_id': userId, 'fcm_token': _fcmToken},
          onConflict: 'user_id',
        );
      }

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
      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
      );
      const details = NotificationDetails(android: androidDetails);
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
    _checkUpcomingEvents();
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

  static Future<void> _checkUpcomingEvents() async {
    try {
      final events = await _fetchMonth();
      final now = DateTime.now();

      for (final e in events) {
        if (e.impact == 'low') continue;
        final diff = e.time.difference(now);
        if (diff.inMinutes < 5 || diff.inMinutes > 30) continue;

        final notifId = '${e.event}_${e.time.toIso8601String()}';
        if (_sentNotificationIds.contains(notifId)) continue;
        _sentNotificationIds.add(notifId);

        final minLabel = 'in ${diff.inMinutes} min';
        final isHigh = e.impact == 'high';
        await showLocalNotification(
          id: e.time.millisecondsSinceEpoch.remainder(100000),
          title: isHigh
              ? '⚠️ Upcoming news: ${e.event}'
              : '📊 News coming up: ${e.event}',
          body: '${e.country.toUpperCase()} · $minLabel · Watch out for volatility.',
        );
        debugPrint('[NotificationService] Alert: ${e.event} $minLabel');
      }
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
              title: '📅 High-impact news in 1 hour: ${e.event}',
              body: '${e.country.toUpperCase()} · $timeLabel · Prepare your plan.',
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
                ? '⚠️ News in 15 minutes: ${e.event}'
                : '📊 Medium-impact news in 15 min: ${e.event}',
            body: '${e.country.toUpperCase()} · $timeLabel · Watch for volatility.',
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
      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
      );
      await _fln.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        const NotificationDetails(android: androidDetails),
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
  static Future<List<EconomicEvent>> _fetchMonth() async {
    if (_cachedMonthEvents != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheTtl) {
      return _cachedMonthEvents!;
    }

    final now = DateTime.now();
    final from = now;
    final to = now.add(const Duration(days: 30));

    List<EconomicEvent> events = [];

    // Try Finnhub first
    if (_finnhubKey.isNotEmpty) {
      events = await _fetchFinnhub(from, to);
      debugPrint('[NotificationService] Finnhub returned ${events.length} events');
    }

    // Fallback to ForexFactory if Finnhub returned nothing
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
    await scheduleUpcomingNotifications();
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
      final scheduledDate = tz.TZDateTime.from(notifTime, tz.local);
      await _fln.zonedSchedule(
        id,
        '⏰ Session starts in 15 minutes',
        'Your trading session is about to begin. Do you have a plan for today? 📋',
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
}
