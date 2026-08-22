import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// OANDA REST API v3 service — polls account summary every 5 seconds.
/// Docs: https://developer.oanda.com/rest-live-v20/account-ep/
class OandaService {
  static String? _apiKey;
  static String? _accountId;
  static bool _isDemo = false;

  static String get _baseUrl => _isDemo
      ? 'https://api-fxpractice.oanda.com/v3'
      : 'https://api-fxtrade.oanda.com/v3';

  /// Configure the service before polling.
  static void configure(
    String apiKey,
    String accountId, {
    bool isDemo = false,
  }) {
    _apiKey = apiKey.isNotEmpty ? apiKey : null;
    _accountId = accountId.isNotEmpty ? accountId : null;
    _isDemo = isDemo;
  }

  /// GET /v3/accounts/{accountId}/summary
  /// Returns a map with: equity, balance, unrealizedPL, openPositionCount, currency
  /// Returns null on any failure.
  static Future<Map<String, dynamic>?> fetchAccountSummary() async {
    if (_apiKey == null || _accountId == null) return null;
    try {
      final uri = Uri.parse('$_baseUrl/accounts/$_accountId/summary');
      final resp = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final account = body['account'] as Map<String, dynamic>?;
        if (account == null) return null;

        final balance = double.tryParse(account['balance']?.toString() ?? '');
        final nav = double.tryParse(account['NAV']?.toString() ?? '');
        final unrealizedPL =
            double.tryParse(account['unrealizedPL']?.toString() ?? '');
        final openPositionCount =
            (account['openPositionCount'] as num?)?.toInt();
        final currency = account['currency'] as String?;

        return {
          'equity': nav,
          'balance': balance,
          'unrealizedPL': unrealizedPL,
          'openPositionCount': openPositionCount,
          'currency': currency,
        };
      }

      debugPrint(
          '[OandaService] fetchAccountSummary HTTP ${resp.statusCode}');
      return null;
    } catch (e) {
      debugPrint('[OandaService] fetchAccountSummary error: $e');
      return null;
    }
  }
}
