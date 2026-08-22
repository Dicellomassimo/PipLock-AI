# Graph Report - piplock_ai  (2026-08-15)

## Corpus Check
- 55 files · ~38,257 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 911 nodes · 1215 edges · 53 communities (48 shown, 5 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- notifications_screen.dart
- killswitch_screen.dart
- metaapi_provider.dart
- checkin_modal.dart
- personal_rules.dart
- personal_rules_screen.dart
- challenge_setup_screen.dart
- supabase_service.dart
- purchase_service.dart
- ai_planner_screen.dart
- app_colors.dart
- broker_screen.dart
- main.dart
- help_faq_screen.dart
- auth_screen.dart
- history_screen.dart
- challenge.dart
- dashboard_screen.dart
- metaapi_service.dart
- notification_service.dart
- main_nav_screen.dart
- app.dart
- killswitch_provider.dart
- rules_provider.dart
- auth_provider.dart
- ai_service.dart
- killswitch_event.dart
- currentUserIdProvider
- permissions_screen.dart
- privacy_policy_screen.dart
- ConsumerState
- accessibility_provider.dart
- profile.dart
- splash_screen.dart
- package:flutter/material.dart
- StatelessWidget
- EventChannel
- build
- realtime_provider.dart
- account_screen.dart
- authProvider
- package:google_fonts/google_fonts.dart
- ea-webhook/index.ts
- metaApiProvider
- package:flutter_riverpod/flutter_riverpod.dart
- StateNotifier
- piplock_ai
- constants.dart
- _AiPlannerScreenState
- reset-daily-limits/index.ts

## God Nodes (most connected - your core abstractions)
1. `authProvider` - 13 edges
2. `currentUserIdProvider` - 13 edges
3. `build` - 9 edges
4. `killswitchProvider` - 8 edges
5. `EventChannel` - 7 edges
6. `PipLockAccessibilityService` - 7 edges
7. `_DashboardScreenState` - 7 edges
8. `MainActivity` - 6 edges
9. `metaApiProvider` - 6 edges
10. `_KillswitchScreenState` - 6 edges

## Surprising Connections (you probably didn't know these)
- `PipLockAccessibilityService` --inherits--> `AccessibilityService`  [EXTRACTED]
  android/app/src/main/kotlin/com/piplock/piplock_ai/PipLockAccessibilityService.kt → lib/services/accessibility_service.dart
- `build` --references--> `authProvider`  [EXTRACTED]
  lib/screens/dashboard/dashboard_screen.dart → lib/providers/auth_provider.dart
- `_DashboardScreenState` --references--> `authProvider`  [EXTRACTED]
  lib/screens/dashboard/dashboard_screen.dart → lib/providers/auth_provider.dart
- `build` --references--> `authProvider`  [EXTRACTED]
  lib/screens/killswitch/killswitch_screen.dart → lib/providers/auth_provider.dart
- `_KillswitchScreenState` --references--> `authProvider`  [EXTRACTED]
  lib/screens/killswitch/killswitch_screen.dart → lib/providers/auth_provider.dart

## Import Cycles
- None detected.

## Communities (53 total, 5 thin omitted)

### Community 0 - "notifications_screen.dart"
Cohesion: 0.05
Nodes (46): ForgotPasswordScreen, _ForgotPasswordScreenState, _allEnabled, build, _challengeReminders, createState, event, _fomoAlerts (+38 more)

### Community 1 - "killswitch_screen.dart"
Cohesion: 0.06
Nodes (39): Animation, AnimationController, Duration, killswitchProvider, build, _countdownTimer, createState, dispose (+31 more)

### Community 2 - "metaapi_provider.dart"
Cohesion: 0.05
Nodes (38): accountId, balance, _checkLimits, connect, copyWith, currency, dailyLossPct, dailyLossUsd (+30 more)

### Community 3 - "checkin_modal.dart"
Cohesion: 0.06
Nodes (35): bool?, Color, CustomPainter, dart:math, build, _buildMoodStep, _buildResultStep, _buildSetupStep (+27 more)

### Community 4 - "personal_rules.dart"
Cohesion: 0.06
Nodes (32): double?, int?, challengeReminders, copyWith, fcmToken, fomoAlerts, fromJson, mock (+24 more)

### Community 5 - "personal_rules_screen.dart"
Cohesion: 0.06
Nodes (32): _back, _brokerController, build, _buildProgressBar, _buildStep1, _buildStep2, _buildStep3, _buildStep4 (+24 more)

### Community 6 - "challenge_setup_screen.dart"
Cohesion: 0.07
Nodes (30): _accountSize, _accountSizes, _back, build, _buildProgressBar, _buildStep1, _buildStep2, _buildStep3 (+22 more)

### Community 7 - "supabase_service.dart"
Cohesion: 0.07
Nodes (28): authStateChanges, _client, consumeToken, currentUser, currentUserId, ensureProfile, getActiveChallenge, getKillswitchHistory (+20 more)

### Community 8 - "purchase_service.dart"
Cohesion: 0.08
Nodes (20): AccessibilityEvent, PipLockAccessibilityService, AccessibilityService, _events, isEnabled, isRunning, _method, openSettings (+12 more)

### Community 9 - "ai_planner_screen.dart"
Cohesion: 0.07
Nodes (27): _addBotMessage, build, _buildChatBubble, _buildEmptyChat, _buildInput, _buildPlanCard, _buildTypingIndicator, _challenge (+19 more)

### Community 10 - "app_colors.dart"
Cohesion: 0.08
Nodes (24): accent, accentDark, AppColors, background, border, cardBg, cardBg2, danger (+16 more)

### Community 11 - "broker_screen.dart"
Cohesion: 0.08
Nodes (23): _buildConnectedView, _buildConnectionForm, color, _connect, connected, controller, createState, dispose (+15 more)

### Community 12 - "main.dart"
Cohesion: 0.09
Nodes (21): app.dart, appLinks, groqKey, initialize, load, main, _brokerChannel, _client (+13 more)

### Community 13 - "help_faq_screen.dart"
Cohesion: 0.09
Nodes (22): answer, build, _buildContactCard, _buildEmptySearch, _buildFaqCard, _buildSearchBar, _buildSectionHeader, createState (+14 more)

### Community 14 - "auth_screen.dart"
Cohesion: 0.09
Nodes (21): build, _buildRegisterForm, _buildTextField, createState, dispose, _friendlyError, initState, _login (+13 more)

### Community 15 - "history_screen.dart"
Cohesion: 0.10
Nodes (21): _barGroup, build, _buildChartView, _buildEmptyPlaceholder, _buildEventCard, _buildListView, _buildToggle, _colorForReason (+13 more)

### Community 16 - "challenge.dart"
Cohesion: 0.10
Nodes (20): accountSize, aiPlan, Challenge, copyWith, currentDay, durationDays, fromJson, id (+12 more)

### Community 17 - "dashboard_screen.dart"
Cohesion: 0.10
Nodes (20): _buildCheckinRow, _buildDevToggle, _buildHeroCard, _buildRecentActivity, _buildStatsRow, _checkinDone, _checkinScore, createState (+12 more)

### Community 18 - "metaapi_service.dart"
Cohesion: 0.10
Nodes (20): balance, _clientBase, currency, deployAccount, equity, freeMargin, fromJson, getAccountInfo (+12 more)

### Community 19 - "notification_service.dart"
Cohesion: 0.10
Nodes (20): actual, country, estimate, event, _fcmToken, fetchEconomicEvents, _finnhubKey, fromJson (+12 more)

### Community 20 - "main_nav_screen.dart"
Cohesion: 0.11
Nodes (19): ../ai_planner/ai_planner_screen.dart, ../dashboard/dashboard_screen.dart, ../history/history_screen.dart, accessibilityWatcherProvider, realtimeProvider, createState, _currentIndex, initState (+11 more)

### Community 21 - "app.dart"
Cohesion: 0.11
Nodes (18): build, _buildTheme, screens/account/account_screen.dart, screens/ai_planner/ai_planner_screen.dart, screens/auth/auth_screen.dart, screens/auth/forgot_password_screen.dart, screens/broker/broker_screen.dart, screens/history/history_screen.dart (+10 more)

### Community 22 - "killswitch_provider.dart"
Cohesion: 0.11
Nodes (18): activate, activateAndSave, activatedAt, activateWithDurationString, copyWith, deactivate, _durationFromString, eventId (+10 more)

### Community 23 - "rules_provider.dart"
Cohesion: 0.12
Nodes (17): PersonalRules, copyWith, isKillswitchTriggered, isLoading, _loadRules, lossToday, _ref, reload (+9 more)

### Community 24 - "auth_provider.dart"
Cohesion: 0.12
Nodes (16): bool get, AuthNotifier, AuthState, consumeToken, copyWith, _init, isLoading, isLoggedIn (+8 more)

### Community 25 - "ai_service.dart"
Cohesion: 0.12
Nodes (16): dart:convert, AiService, _apiKey, _baseUrl, chat, generateChallengePlan, _headers, _mockChatResponse (+8 more)

### Community 26 - "killswitch_event.dart"
Cohesion: 0.12
Nodes (15): accountMode, fromJson, id, isActive, KillswitchEvent, lockDurationMinutes, mockList, reason (+7 more)

### Community 27 - "currentUserIdProvider"
Cohesion: 0.15
Nodes (16): currentUserIdProvider, rulesProvider, _generatePlan, _loadActiveChallenge, build, _buildDevSection, DashboardScreen, _DashboardScreenState (+8 more)

### Community 28 - "permissions_screen.dart"
Cohesion: 0.13
Nodes (14): IconData, actionButton, activeLabel, build, createState, description, icon, iconColor (+6 more)

### Community 29 - "privacy_policy_screen.dart"
Cohesion: 0.13
Nodes (14): body, build, _buildScrollableContent, _buildTabBar, createState, dispose, initState, _PolicySection (+6 more)

### Community 30 - "ConsumerState"
Cohesion: 0.21
Nodes (14): ConsumerState, ConsumerStatefulWidget, AuthScreen, _AuthScreenState, HelpFaqScreen, _HelpFaqScreenState, PrivacyPolicyScreen, _PrivacyPolicyScreenState (+6 more)

### Community 31 - "accessibility_provider.dart"
Cohesion: 0.14
Nodes (13): dart:async, AccessibilityWatcher, dispose, _durationMinutes, _ref, _sessionTrades, _startListening, _sub (+5 more)

### Community 32 - "profile.dart"
Cohesion: 0.14
Nodes (13): DateTime, accountMode, copyWith, createdAt, fromJson, id, mock, Profile (+5 more)

### Community 33 - "splash_screen.dart"
Cohesion: 0.15
Nodes (12): Future, _authResolved, build, createState, _ctrl, dispose, _fade, initState (+4 more)

### Community 34 - "package:flutter/material.dart"
Cohesion: 0.20
Nodes (10): ../config/app_colors.dart, ../help/help_faq_screen.dart, ../help/privacy_policy_screen.dart, _settingsTile, _comparisonTable, createState, _purchaseCard, package:flutter/material.dart (+2 more)

### Community 35 - "StatelessWidget"
Cohesion: 0.17
Nodes (12): _AuthCallbackScreen, PipLockApp, _FormField, _MetricCard, _MetricsGrid, _SecurityNote, _StatusBadge, _EconomicEventTile (+4 more)

### Community 36 - "EventChannel"
Cohesion: 0.33
Nodes (4): MainActivity, EventChannel, FlutterActivity, FlutterEngine

### Community 37 - "build"
Cohesion: 0.22
Nodes (10): _buildSubscriptionCard, _buildHeader, build, MaterialPageRoute, Route /account, Route /broker, Route /notifications, Route /permissions (+2 more)

### Community 38 - "realtime_provider.dart"
Cohesion: 0.22
Nodes (8): auth_provider.dart, killswitch_provider.dart, dispose, _init, _ref, _startRealtime, Ref, ../services/realtime_service.dart

### Community 39 - "account_screen.dart"
Cohesion: 0.22
Nodes (8): ../config/constants.dart, _actionTile, _buildProfileHero, _copyToClipboard, _infoTile, _modeCard, _sectionLabel, _showDeleteDialog

### Community 40 - "authProvider"
Cohesion: 0.25
Nodes (9): ConsumerWidget, authProvider, AccountScreen, build, _buildLoginForm, SettingsScreen, _navigate, build (+1 more)

### Community 41 - "package:google_fonts/google_fonts.dart"
Cohesion: 0.22
Nodes (8): build, createState, dispose, _emailController, _isLoading, _sendReset, _showMessage, package:google_fonts/google_fonts.dart

### Community 43 - "metaApiProvider"
Cohesion: 0.40
Nodes (5): metaApiProvider, BrokerScreen, _BrokerScreenState, build, _disconnect

### Community 44 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.40
Nodes (4): package:flutter_riverpod/flutter_riverpod.dart, package:flutter_test/flutter_test.dart, package:piplock_ai/app.dart, main

### Community 45 - "StateNotifier"
Cohesion: 0.50
Nodes (4): MetaApiNotifier, MetaApiState, RealtimeNotifier, StateNotifier

## Knowledge Gaps
- **604 isolated node(s):** `build`, `_buildTheme`, `AppColors`, `background`, `surface` (+599 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **5 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `build` connect `build` to `authProvider`, `package:flutter/material.dart`?**
  _High betweenness centrality (0.012) - this node is a cross-community bridge._
- **What connects `build`, `_buildTheme`, `AppColors` to the rest of the system?**
  _604 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `notifications_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.04609929078014184 - nodes in this community are weakly interconnected._
- **Should `killswitch_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.05609756097560976 - nodes in this community are weakly interconnected._
- **Should `metaapi_provider.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.05128205128205128 - nodes in this community are weakly interconnected._
- **Should `checkin_modal.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.05855855855855856 - nodes in this community are weakly interconnected._
- **Should `personal_rules.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.058823529411764705 - nodes in this community are weakly interconnected._