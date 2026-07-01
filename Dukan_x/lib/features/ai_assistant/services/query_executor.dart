import 'package:flutter/foundation.dart';
import '../../../core/database/app_database.dart';
import '../../../core/di/service_locator.dart';

/// QueryExecutor - Executes SQL queries against local Drift database
/// and formats results for natural language response.
class QueryExecutor {
  final AppDatabase _db;

  QueryExecutor() : _db = sl<AppDatabase>();

  /// Execute a SQL query and return formatted results
  Future<QueryResult> execute(String sql) async {
    try {
      debugPrint('📊 Executing SQL: $sql');

      // Use Drift's customSelect for raw SQL
      final results = await _db.customSelect(sql).get();

      final rows = results.map((row) => row.data).toList();

      debugPrint('📊 Query returned ${rows.length} rows');

      return QueryResult(
        success: true,
        rows: rows,
        formattedText: _formatResults(rows),
      );
    } catch (e) {
      debugPrint('❌ Query Error: $e');
      return QueryResult(
        success: false,
        rows: [],
        formattedText: 'Query failed: ${e.toString().split('\n').first}',
        error: e.toString(),
      );
    }
  }

  /// Format query results into natural language
  String _formatResults(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return 'No data found.';
    }

    // Single aggregation result (SUM, COUNT, etc.)
    if (rows.length == 1) {
      final row = rows.first;

      // Check for common aggregation patterns
      if (row.containsKey('total') || row.containsKey('total_sales')) {
        final value = row['total'] ?? row['total_sales'] ?? 0;
        return 'Total: ₹${_formatNumber(value)}';
      }
      if (row.containsKey('revenue')) {
        return 'Revenue: ₹${_formatNumber(row['revenue'])}';
      }
      if (row.containsKey('count')) {
        return 'Count: ${row['count']}';
      }

      // Single row with name + value
      if (row.containsKey('name')) {
        if (row.containsKey('total_dues')) {
          return '${row['name']}: ₹${_formatNumber(row['total_dues'])} dues';
        }
        if (row.containsKey('stock_quantity')) {
          return '${row['name']}: ${row['stock_quantity']} ${row['unit'] ?? 'units'} in stock';
        }
        if (row.containsKey('grand_total')) {
          return '${row['name']}: ₹${_formatNumber(row['grand_total'])}';
        }
      }

      // Generic single row
      final parts = row.entries
          .where((e) => e.value != null)
          .take(3)
          .map((e) => '${_formatKey(e.key)}: ${_formatValue(e.value)}')
          .toList();
      return parts.join(', ');
    }

    // Multiple rows - format as list
    final lines = <String>[];
    for (int i = 0; i < rows.length && i < 10; i++) {
      final row = rows[i];

      if (row.containsKey('name')) {
        String line = '${i + 1}. ${row['name']}';
        if (row.containsKey('total_dues')) {
          line += ': ₹${_formatNumber(row['total_dues'])}';
        } else if (row.containsKey('stock_quantity')) {
          line += ': ${row['stock_quantity']} ${row['unit'] ?? ''}';
        } else if (row.containsKey('grand_total')) {
          line += ': ₹${_formatNumber(row['grand_total'])}';
        }
        lines.add(line);
      } else if (row.containsKey('customer_name')) {
        lines.add('${i + 1}. ${row['customer_name']}');
      } else {
        // Generic formatting
        final first3 = row.entries
            .take(3)
            .map((e) => _formatValue(e.value))
            .join(', ');
        lines.add('${i + 1}. $first3');
      }
    }

    if (rows.length > 10) {
      lines.add('... and ${rows.length - 10} more');
    }

    return lines.join('\n');
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '0';
    final numValue = (value is num)
        ? value
        : double.tryParse(value.toString()) ?? 0;
    return numValue.toStringAsFixed(
      numValue.truncateToDouble() == numValue ? 0 : 2,
    );
  }

  String _formatKey(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '',
        )
        .join(' ');
  }

  String _formatValue(dynamic value) {
    if (value == null) return '-';
    if (value is double) return _formatNumber(value);
    return value.toString();
  }
}

/// Result model for query execution
class QueryResult {
  final bool success;
  final List<Map<String, dynamic>> rows;
  final String formattedText;
  final String? error;

  QueryResult({
    required this.success,
    required this.rows,
    required this.formattedText,
    this.error,
  });

  int get rowCount => rows.length;
  bool get isEmpty => rows.isEmpty;
  bool get hasData => rows.isNotEmpty;
}
