import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Servizio MetaAPI REST — polling ogni 30s
/// Docs: https://metaapi.cloud/docs/client/
class MetaApiService {
  static const _baseUrl =
      'https://mt-client-api-v1.london.agiliumtrade.ai';
  static String? _token;

  static void setToken(String t) => _token = t.isNotEmpty ? t : null;

  // ── Account information ─────────────────────────────────────────────────────

  /// GET /users/current/accounts/{accountId}/account-information
  /// Ritorna la mappa grezza con balance, equity, currency, margin, freeMargin.
  static Future<Map<String, dynamic>?> fetchAccountInfo(
      String accountId) async {
    if (_token == null) return null;
    try {
      final uri = Uri.parse(
          '$_baseUrl/users/current/accounts/$accountId/account-information');
      final resp = await http
          .get(uri, headers: {'token': _token!})
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      debugPrint(
          '[MetaApiService] fetchAccountInfo HTTP ${resp.statusCode}');
      return null;
    } catch (e) {
      debugPrint('[MetaApiService] fetchAccountInfo error: $e');
      return null;
    }
  }

  // ── Posizioni aperte ────────────────────────────────────────────────────────

  /// GET /users/current/accounts/{accountId}/positions
  /// Ritorna la lista grezza delle posizioni aperte.
  static Future<List<dynamic>> fetchPositions(String accountId) async {
    if (_token == null) return [];
    try {
      final uri = Uri.parse(
          '$_baseUrl/users/current/accounts/$accountId/positions');
      final resp = await http
          .get(uri, headers: {'token': _token!})
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as List<dynamic>;
      }
      debugPrint(
          '[MetaApiService] fetchPositions HTTP ${resp.statusCode}');
      return [];
    } catch (e) {
      debugPrint('[MetaApiService] fetchPositions error: $e');
      return [];
    }
  }

  // ── Dati combinati ──────────────────────────────────────────────────────────

  /// Combina account-information + positions in un'unica mappa normalizzata:
  /// { equity, balance, currency, openPositions, dailyPnl }
  /// dailyPnl = equity - balance (floating P&L semplificato).
  /// Ritorna null in caso di errore.
  static Future<Map<String, dynamic>?> fetchFullData(
      String accountId) async {
    try {
      final results = await Future.wait([
        fetchAccountInfo(accountId),
        fetchPositions(accountId),
      ]);

      final info = results[0] as Map<String, dynamic>?;
      if (info == null) return null;

      final positions = results[1] as List<dynamic>;

      final equity = (info['equity'] as num?)?.toDouble();
      final balance = (info['balance'] as num?)?.toDouble();
      final currency = info['currency'] as String?;
      final openPositions = positions.length;

      // Floating P&L semplificato: equity - balance
      final dailyPnl =
          (equity != null && balance != null) ? equity - balance : null;

      return {
        'equity': equity,
        'balance': balance,
        'currency': currency,
        'openPositions': openPositions,
        'dailyPnl': dailyPnl,
      };
    } catch (e) {
      debugPrint('[MetaApiService] fetchFullData error: $e');
      return null;
    }
  }
}
