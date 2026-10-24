/// Client HTTP pour la base de données distribuée Turso (libSQL).
library;

import 'dart:convert';
import 'package:http/http.dart' as http;

class TursoException implements Exception {
  final String message;
  final String? code;
  const TursoException(this.message, [this.code]);

  @override
  String toString() => 'TursoException: $message (code: $code)';
}

/// Client officiel pour exécuter des requêtes sur l'API HTTP Pipeline de Turso.
class TursoClient {
  final String baseUrl;
  final String token;
  final http.Client _client;

  TursoClient({
    required String url,
    required this.token,
    http.Client? client,
  })  : baseUrl = _normalizeUrl(url),
        _client = client ?? http.Client();

  static String _normalizeUrl(String url) {
    var u = url.trim();
    if (u.startsWith('libsql://')) {
      u = 'https://${u.substring('libsql://'.length)}';
    } else if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'https://$u';
    }
    if (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (!u.endsWith('/v2/pipeline')) {
      u = '$u/v2/pipeline';
    }
    return u;
  }

  /// Convertit une valeur Dart en argument typé libSQL.
  static Map<String, dynamic> _toTursoArg(dynamic val) {
    if (val == null) {
      return {'type': 'null'};
    } else if (val is int) {
      return {'type': 'integer', 'value': val.toString()};
    } else if (val is double) {
      return {'type': 'float', 'value': val};
    } else if (val is bool) {
      return {'type': 'integer', 'value': val ? '1' : '0'};
    } else if (val is List<int>) {
      return {'type': 'blob', 'base64': base64Encode(val)};
    } else {
      return {'type': 'text', 'value': val.toString()};
    }
  }

  /// Extrait une valeur brute depuis un champ de réponse libSQL.
  static dynamic _fromTursoVal(Map<String, dynamic> v) {
    final type = v['type'];
    final val = v['value'];
    return switch (type) {
      'null'    => null,
      'integer' => int.tryParse(val?.toString() ?? '') ?? 0,
      'float'   => (val is num) ? val.toDouble() : double.tryParse(val?.toString() ?? '') ?? 0.0,
      'text'    => val?.toString() ?? '',
      'blob'    => v['base64'] != null ? base64Decode(v['base64']) : null,
      _         => val,
    };
  }

  /// Exécute une instruction SQL (INSERT, UPDATE, DELETE, etc.)
  Future<int> execute(String sql, [List<dynamic>? args]) async {
    final stmt = <String, dynamic>{'sql': sql};
    if (args != null && args.isNotEmpty) {
      stmt['args'] = args.map(_toTursoArg).toList();
    }

    final res = await _pipeline([{'type': 'execute', 'stmt': stmt}]);
    final first = res['results']?[0];
    if (first == null) return 0;
    if (first['type'] == 'error') {
      throw TursoException(
        first['error']?['message'] ?? 'Erreur SQLite',
        first['error']?['code'],
      );
    }
    final execRes = first['response']?['result'];
    return execRes?['affected_row_count'] ?? 0;
  }

  /// Exécute une requête SQL (SELECT) et retourne la liste des lignes mappées.
  Future<List<Map<String, dynamic>>> query(String sql, [List<dynamic>? args]) async {
    final stmt = <String, dynamic>{'sql': sql};
    if (args != null && args.isNotEmpty) {
      stmt['args'] = args.map(_toTursoArg).toList();
    }

    final res = await _pipeline([{'type': 'execute', 'stmt': stmt}]);
    final first = res['results']?[0];
    if (first == null) return const [];
    if (first['type'] == 'error') {
      throw TursoException(
        first['error']?['message'] ?? 'Erreur SQLite',
        first['error']?['code'],
      );
    }

    final execResult = first['response']?['result'];
    if (execResult == null) return const [];

    final cols = (execResult['cols'] as List?)
            ?.map((c) => c['name']?.toString() ?? '')
            .toList() ??
        const <String>[];
    final rows = (execResult['rows'] as List?) ?? const [];

    final out = <Map<String, dynamic>>[];
    for (final row in rows) {
      if (row is! List) continue;
      final map = <String, dynamic>{};
      for (int i = 0; i < cols.length && i < row.length; i++) {
        final colName = cols[i];
        final valObj = row[i];
        map[colName] = (valObj is Map<String, dynamic>)
            ? _fromTursoVal(valObj)
            : valObj;
      }
      out.add(map);
    }
    return out;
  }

  /// Exécute un lot de requêtes en pipeline (une seule requête HTTP).
  Future<List<Map<String, dynamic>>> batch(
      List<({String sql, List<dynamic>? args})> requests) async {
    final reqList = requests.map((r) {
      final stmt = <String, dynamic>{'sql': r.sql};
      if (r.args != null && r.args!.isNotEmpty) {
        stmt['args'] = r.args!.map(_toTursoArg).toList();
      }
      return {'type': 'execute', 'stmt': stmt};
    }).toList();

    final res = await _pipeline(reqList);
    final results = (res['results'] as List?) ?? const [];

    final out = <Map<String, dynamic>>[];
    for (final r in results) {
      if (r is! Map<String, dynamic>) continue;
      if (r['type'] == 'error') {
        throw TursoException(
          r['error']?['message'] ?? 'Erreur SQLite',
          r['error']?['code'],
        );
      }
      out.add(r);
    }
    return out;
  }

  Future<Map<String, dynamic>> _pipeline(List<Map<String, dynamic>> requests) async {
    final uri = Uri.parse(baseUrl);
    final body = jsonEncode({'requests': requests});

    final resp = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'User-Agent': 'Terebi-App/2.1',
      },
      body: body,
    );

    if (resp.statusCode != 200) {
      throw TursoException(
        'Erreur HTTP ${resp.statusCode}: ${resp.body}',
        resp.statusCode.toString(),
      );
    }

    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  void close() {
    _client.close();
  }
}
