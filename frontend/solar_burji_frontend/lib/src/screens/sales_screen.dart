import 'package:flutter/material.dart';
import '../api_client.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../pdf/export_pdf.dart';
import 'package:printing/printing.dart';
import '../ui/components.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});
  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final ApiClient _api = ApiClient();
  DateTime _selected = DateTime.now();
  String _period = 'day';
  final _amountCtrl = TextEditingController();
  String _method = 'cash';
  final _noteCtrl = TextEditingController();
  Map<String, dynamic>? _report;
  bool _loading = false;

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selected);

  @override
  void initState() {
    super.initState();
    _fetch(_period);
  }

  Future<void> _fetch(String period) async {
    setState(() {
      _loading = true;
      _report = null; // Clear old data to force refresh
    });
    try {
      // Force a small delay to ensure UI updates
      await Future.delayed(const Duration(milliseconds: 100));

      final data = await _api.get(
        '/sales.php',
        query: {'period': period, 'date': _dateStr},
      );
      setState(() => _report = data);
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _forceRefresh() async {
    setState(() {
      _loading = true;
      _report = null;
    });
    await _fetch(_period);
  }

  Future<void> _submit() async {
    final body = {
      'txn_date': _dateStr,
      'amount': double.tryParse(_amountCtrl.text) ?? 0,
      'payment_method': _method,
      'note': _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
    };
    setState(() => _loading = true);
    try {
      await _api.post('/sales.php', body);
      await _forceRefresh();
      _amountCtrl.clear();
      _noteCtrl.clear();
      _showSuccess('Sale saved successfully!');
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _deleteSale(int id) async {
    final ok = await confirm(context, 'Delete Sale', 'Delete this sale entry?');
    if (!ok) return;
    setState(() => _loading = true);
    try {
      await _api.delete('/sales.php', query: {'id': '$id'});
      await _forceRefresh();
      _showSuccess('Sale deleted successfully!');
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _editSale(BuildContext context, Map<String, dynamic> t) async {
    final amountCtrl = TextEditingController(text: (t['amount']).toString());
    String method = t['payment_method'] as String;
    final noteCtrl = TextEditingController(text: (t['note'] as String?) ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Sale'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: method,
              decoration: const InputDecoration(
                labelText: 'Payment Method',
                prefixIcon: Icon(Icons.payment),
              ),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'online', child: Text('Online')),
              ],
              onChanged: (v) => method = v ?? method,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note',
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != true) return;
    setState(() => _loading = true);
    try {
      final updateData = {
        'id': t['id'],
        'amount': double.tryParse(amountCtrl.text) ?? t['amount'],
        'payment_method': method,
        'note': noteCtrl.text,
      };
      await _api.put('/sales.php', updateData);
      await _forceRefresh();
      _showSuccess('Sale updated successfully!');
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final txns =
        (_report?['transactions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final total = _report?['total_amount'] ?? 0;
    final cash = _report?['cash_amount'] ?? 0;
    final online = _report?['online_amount'] ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Sales'), elevation: 0),
      body: RefreshIndicator(
        onRefresh: () => _forceRefresh(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilterBar(
                date: _selected,
                period: _period,
                loading: _loading,
                onPickDate: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _selected,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setState(() => _selected = d);
                },
                onChangePeriod: (next) {
                  setState(() => _period = next);
                  _fetch(next);
                },
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        title: 'Total Sales',
                        value: formatCurrency0(total),
                        color: const Color(0xFF0EA5AA),
                        icon: Icons.trending_up,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        title: 'Cash',
                        value: formatCurrency0(cash),
                        color: const Color(0xFFF59E0B),
                        icon: Icons.money,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        title: 'Online',
                        value: formatCurrency0(online),
                        color: const Color(0xFF3B82F6),
                        icon: Icons.credit_card,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _loading
                            ? null
                            : () {
                                final uri = _api.buildUri(
                                  '/sales.php',
                                  query: {
                                    'period': _period,
                                    'date': _dateStr,
                                    'format': 'csv',
                                  },
                                );
                                _showError('Download: $uri');
                              },
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Export CSV'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _report == null
                            ? null
                            : () async {
                                final bytes = await PdfExporter.salesReport(
                                  report: _report!,
                                );
                                await Printing.layoutPdf(
                                  onLayout: (_) async => bytes,
                                );
                              },
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        label: const Text('Export PDF'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Sales Trend',
                child: SizedBox(
                  height: 240,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 1000,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: const Color(0xFFE5E7EB),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 50,
                            interval: 1000,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '₹${value.toInt()}',
                                style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: (txns.length / 6).clamp(1, 6).toDouble(),
                            getTitlesWidget: (v, meta) {
                              final i = v.toInt();
                              if (i < 0 || i >= txns.length) {
                                return const SizedBox.shrink();
                              }
                              final dd = txns[i]['txn_date'] as String;
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  dd.substring(5),
                                  style: const TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          isCurved: true,
                          color: const Color(0xFF0EA5AA),
                          barWidth: 3,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 4,
                                color: const Color(0xFF0EA5AA),
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              );
                            },
                          ),
                          spots: [
                            for (var i = 0; i < txns.length; i++)
                              FlSpot(
                                i.toDouble(),
                                _toDouble(txns[i]['amount']),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Add Sale',
                child: Column(
                  children: [
                    TextField(
                      controller: _amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount (₹)',
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _method,
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                        prefixIcon: Icon(Icons.payment),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('Cash')),
                        DropdownMenuItem(
                          value: 'online',
                          child: Text('Online'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _method = v ?? 'cash'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _noteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Note',
                        prefixIcon: Icon(Icons.note),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Save Sale'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Recent Transactions',
                child: txns.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'No transactions found for this period',
                            style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: _groupBy(txns, (t) => t['txn_date'] as String)
                            .entries
                            .expand((entry) {
                              final date = entry.key;
                              final items = entry.value;
                              final dayTotal = items.fold<num>(
                                0,
                                (p, t) => p + _toDouble(t['amount']),
                              );
                              return [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 8,
                                    bottom: 4,
                                  ),
                                  child: Text(
                                    date,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                ),
                                ...items.map((t) => _buildTransactionTile(t)),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 12,
                                    right: 12,
                                    bottom: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      const Spacer(),
                                      ModernChip(
                                        label:
                                            'Subtotal: ${formatCurrency0(dayTotal)}',
                                        backgroundColor: const Color(
                                          0xFF0EA5AA,
                                        ),
                                        textColor: Colors.white,
                                      ),
                                    ],
                                  ),
                                ),
                              ];
                            })
                            .toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionTile(Map<String, dynamic> t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          ModernChip(
            label: t['payment_method'] == 'cash' ? 'Cash' : 'Online',
            backgroundColor: (t['payment_method'] == 'cash'
                ? const Color(0xFFFEF3C7)
                : const Color(0xFFDBEAFE)),
            textColor: (t['payment_method'] == 'cash'
                ? const Color(0xFF92400E)
                : const Color(0xFF1E40AF)),
            icon: t['payment_method'] == 'cash'
                ? Icons.money
                : Icons.credit_card,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatCurrency0(t['amount']),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Color(0xFF1F2937),
                  ),
                ),
                if ((t['note'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Text(
                      t['note'] as String,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                onPressed: () => _editSale(context, t),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: () => _deleteSale(t['id'] as int),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _toDouble(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;

  Map<K, List<T>> _groupBy<T, K>(List<T> items, K Function(T) keyOf) {
    final map = <K, List<T>>{};
    for (final item in items) {
      final k = keyOf(item);
      map.putIfAbsent(k, () => []).add(item);
    }
    return map;
  }
}
