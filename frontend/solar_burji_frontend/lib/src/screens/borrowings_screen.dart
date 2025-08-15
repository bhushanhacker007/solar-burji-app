import 'package:flutter/material.dart';
import '../api_client.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../pdf/export_pdf.dart';
import 'package:printing/printing.dart';
import '../ui/components.dart';

class BorrowingsScreen extends StatefulWidget {
  const BorrowingsScreen({super.key});
  @override
  State<BorrowingsScreen> createState() => _BorrowingsScreenState();
}

class _BorrowingsScreenState extends State<BorrowingsScreen> {
  final ApiClient _api = ApiClient();
  DateTime _selected = DateTime.now();
  String _period = 'day';
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _isRepayment = false;
  final _noteCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
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
        '/borrowings.php',
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
      'customer_name': _nameCtrl.text,
      'amount': double.tryParse(_amountCtrl.text) ?? 0,
      'is_repayment': _isRepayment ? 1 : 0,
      'note': _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
    };
    setState(() => _loading = true);
    try {
      await _api.post('/borrowings.php', body);
      await _forceRefresh();
      _nameCtrl.clear();
      _amountCtrl.clear();
      _noteCtrl.clear();
      setState(() => _isRepayment = false);
      _showSuccess('Borrowing saved successfully!');
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

  Future<void> _deleteBorrow(int id) async {
    final ok = await confirm(
      context,
      'Delete Entry',
      'Delete this borrowing/repayment entry?',
    );
    if (!ok) return;
    setState(() => _loading = true);
    try {
      await _api.delete('/borrowings.php', query: {'id': '$id'});
      await _forceRefresh();
      _showSuccess('Entry deleted successfully!');
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _editBorrow(BuildContext context, Map<String, dynamic> e) async {
    final nameCtrl = TextEditingController(text: e['customer_name'] as String);
    final amountCtrl = TextEditingController(text: (e['amount']).toString());
    bool repay = (e['is_repayment'] as int) == 1;
    final noteCtrl = TextEditingController(text: (e['note'] as String?) ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Entry'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Customer Name',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
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
            SwitchListTile(
              title: const Text('Repayment?'),
              value: repay,
              onChanged: (v) => repay = v,
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
        'id': e['id'],
        'customer_name': nameCtrl.text,
        'amount': double.tryParse(amountCtrl.text) ?? e['amount'],
        'is_repayment': repay ? 1 : 0,
        'note': noteCtrl.text,
      };
      await _api.put('/borrowings.php', updateData);
      await _forceRefresh();
      _showSuccess('Entry updated successfully!');
    } catch (err) {
      _showError(err.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries =
        (_report?['entries'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? entries
        : entries
              .where(
                (e) => (e['customer_name'] as String).toLowerCase().contains(
                  query,
                ),
              )
              .toList();
    final borrowTotal = _report?['borrow_total'] ?? 0;
    final repayTotal = _report?['repayment_total'] ?? 0;
    final net = _report?['net_outstanding_change'] ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Borrowings'), elevation: 0),
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
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Search by customer name',
                    hintText: 'Enter customer name...',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        title: 'Borrowed',
                        value: formatCurrency0(borrowTotal),
                        color: const Color(0xFFEF4444),
                        icon: Icons.trending_down,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        title: 'Repaid',
                        value: formatCurrency0(repayTotal),
                        color: const Color(0xFF10B981),
                        icon: Icons.trending_up,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        title: 'Net Change',
                        value: formatCurrency0(net),
                        color: net >= 0
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF10B981),
                        icon: net >= 0 ? Icons.remove : Icons.add,
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
                                  '/borrowings.php',
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
                                final bytes =
                                    await PdfExporter.borrowingsReport(
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
                title: 'Borrow vs Repay Trend',
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
                            interval: (entries.length / 6)
                                .clamp(1, 6)
                                .toDouble(),
                            getTitlesWidget: (v, meta) {
                              final i = v.toInt();
                              if (i < 0 || i >= entries.length) {
                                return const SizedBox.shrink();
                              }
                              final dd = entries[i]['txn_date'] as String;
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
                          color: const Color(0xFFEF4444),
                          barWidth: 3,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 4,
                                color: const Color(0xFFEF4444),
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              );
                            },
                          ),
                          spots: [
                            for (var i = 0; i < entries.length; i++)
                              if ((entries[i]['is_repayment'] as int) == 0)
                                FlSpot(
                                  i.toDouble(),
                                  _toDouble(entries[i]['amount']),
                                ),
                          ],
                        ),
                        LineChartBarData(
                          isCurved: true,
                          color: const Color(0xFF10B981),
                          barWidth: 3,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 4,
                                color: const Color(0xFF10B981),
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              );
                            },
                          ),
                          spots: [
                            for (var i = 0; i < entries.length; i++)
                              if ((entries[i]['is_repayment'] as int) == 1)
                                FlSpot(
                                  i.toDouble(),
                                  _toDouble(entries[i]['amount']),
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
                title: 'Add Borrowing / Repayment',
                child: Column(
                  children: [
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Customer Name',
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 12),
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
                    SwitchListTile(
                      title: const Text('Repayment?'),
                      subtitle: const Text('Toggle if this is a repayment'),
                      value: _isRepayment,
                      onChanged: (v) => setState(() => _isRepayment = v),
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
                            : Text(
                                _isRepayment
                                    ? 'Save Repayment'
                                    : 'Save Borrowing',
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Recent Entries',
                child: filtered.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'No entries found for this period',
                            style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children:
                            _groupBy(
                              filtered,
                              (e) => e['txn_date'] as String,
                            ).entries.expand((entry) {
                              final date = entry.key;
                              final items = entry.value;
                              final dayBorrow = items
                                  .where((e) => (e['is_repayment'] as int) == 0)
                                  .fold<num>(
                                    0,
                                    (p, e) => p + _toDouble(e['amount']),
                                  );
                              final dayRepay = items
                                  .where((e) => (e['is_repayment'] as int) == 1)
                                  .fold<num>(
                                    0,
                                    (p, e) => p + _toDouble(e['amount']),
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
                                ...items.map((e) => _buildEntryTile(e)),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 12,
                                    right: 12,
                                    bottom: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      const Spacer(),
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          ModernChip(
                                            label:
                                                'Borrow: ${formatCurrency0(dayBorrow)}',
                                            backgroundColor: const Color(
                                              0xFFFEE2E2,
                                            ),
                                            textColor: const Color(0xFF991B1B),
                                          ),
                                          ModernChip(
                                            label:
                                                'Repay: ${formatCurrency0(dayRepay)}',
                                            backgroundColor: const Color(
                                              0xFFD1FAE5,
                                            ),
                                            textColor: const Color(0xFF065F46),
                                          ),
                                          ModernChip(
                                            label:
                                                'Net: ${formatCurrency0(dayBorrow - dayRepay)}',
                                            backgroundColor:
                                                (dayBorrow - dayRepay) >= 0
                                                ? const Color(0xFFFEE2E2)
                                                : const Color(0xFFD1FAE5),
                                            textColor:
                                                (dayBorrow - dayRepay) >= 0
                                                ? const Color(0xFF991B1B)
                                                : const Color(0xFF065F46),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ];
                            }).toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEntryTile(Map<String, dynamic> e) {
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
            label: e['is_repayment'] == 1 ? 'Repay' : 'Borrow',
            backgroundColor: (e['is_repayment'] == 1
                ? const Color(0xFFD1FAE5)
                : const Color(0xFFFEE2E2)),
            textColor: (e['is_repayment'] == 1
                ? const Color(0xFF065F46)
                : const Color(0xFF991B1B)),
            icon: e['is_repayment'] == 1
                ? Icons.trending_up
                : Icons.trending_down,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e['customer_name'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Color(0xFF1F2937),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Text(
                  formatCurrency0(e['amount']),
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                if ((e['note'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Text(
                      e['note'] as String,
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
                onPressed: () => _editBorrow(context, e),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: () => _deleteBorrow(e['id'] as int),
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
