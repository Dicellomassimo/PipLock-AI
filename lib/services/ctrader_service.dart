import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// cTrader REST API service — access token-based polling.
///
/// Users generate an access token from their broker's cTrader platform:
/// Settings → API → Generate Access Token
///
/// The REST endpoint varies by broker. This service uses a configurable
/// base URL defaulting to https://api.ctrader.com.
class CTraderService {
  static String? _accessToken;
  static String? _accountId;
  static String _baseUrl = 'https://api.ctrader.com';

  /// Configure the service before polling.
  static void configure(
    String accessToken,
    String accountId, {
    String baseUrl = 'https://api.ctrader.com',
  }) {
    _accessToken = accessToken.isNotEmpty ? accessToken : null;
    _accountId = accountId.isNotEmpty ? accountId : null;
    _baseUrl = baseUrl.isNotEmpty ? baseUrl : 'https://api.ctrader.com';
  }

  /// GET {baseUrl}/v1/account/{ctraderId}/summary
  /// Returns a map with: equity, balance, unrealizedPL, openPositions, currency
  /// Returns null on any failure.
  static Future<Map<String, dynamic>?> fetchAccountData() async {
    if (_accessToken == null || _accountId == null) return null;
    try {
      final uri = Uri.parse('$_baseUrl/v1/account/$_accountId/summary');
      final resp = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;

        // Normalize common cTrader response field names
        final equity = _parseDouble(body['equity'] ?? body['netEquity']);
        final balance = _parseDouble(body['balance']);
        final unrealizedPL =
            _parseDouble(body['unrealizedPL'] ?? body['unrealizedGrossProfit']);
        final openPositions =
            (body['openPositions'] ?? body['openPositionCount'] as num?)
                ?.toInt();
        final currency = body['currency'] as String?;

        return {
          'equity': equity,
          'balance': balance,
          'unrealizedPL': unrealizedPL,
          'openPositions': openPositions,
          'currency': currency,
        };
      }

      debugPrint(
          '[CTraderService] fetchAccountData HTTP ${resp.statusCode}');
      return null;
    } catch (e) {
      debugPrint('[CTraderService] fetchAccountData error: $e');
      return null;
    }
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
