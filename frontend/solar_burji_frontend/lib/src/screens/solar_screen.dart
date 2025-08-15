import 'package:flutter/material.dart';
import '../api_client.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../pdf/export_pdf.dart';
import 'package:printing/printing.dart';
import '../ui/components.dart';

class SolarScreen extends StatefulWidget {
  const SolarScreen({super.key});
  @override
  State<SolarScreen> createState() => _SolarScreenState();
}

class _SolarScreenState extends State<SolarScreen> {
  final ApiClient _api = ApiClient();
  DateTime _selected = DateTime.now();
  String _period = 'day';
  final _importCtrl = TextEditingController();
  final _exportCtrl = TextEditingController();
  final _genCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
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
        '/solar.php',
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
      'reading_date': _dateStr,
      'import_kwh': double.tryParse(_importCtrl.text) ?? 0,
      'export_kwh': double.tryParse(_exportCtrl.text) ?? 0,
      'generation_kwh': double.tryParse(_genCtrl.text) ?? 0,
      'notes': _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
    };
    setState(() => _loading = true);
    try {
      await _api.post('/solar.php', body);
      await _forceRefresh();
      _importCtrl.clear();
      _exportCtrl.clear();
      _genCtrl.clear();
      _notesCtrl.clear();
      _showSuccess('Reading saved successfully!');
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteSolar(String readingDate) async {
    final ok = await confirm(
      context,
      'Delete Reading',
      'Delete solar reading for $readingDate?',
    );
    if (!ok) return;
    setState(() => _loading = true);
    try {
      await _api.delete('/solar.php', query: {'reading_date': readingDate});
      await _forceRefresh();
      _showSuccess('Reading deleted successfully!');
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

  @override
  Widget build(BuildContext context) {
    final days =
        (_report?['days'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final totalImport = _report?['total_import_kwh'] ?? 0;
    final totalExport = _report?['total_export_kwh'] ?? 0;
    final totalGen = _report?['total_generation_kwh'] ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Solar Power'), elevation: 0),
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
                        title: 'Import',
                        value: '${formatNumber0(totalImport)} kWh',
                        color: const Color(0xFFF59E0B),
                        icon: Icons.download,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        title: 'Export',
                        value: '${formatNumber0(totalExport)} kWh',
                        color: const Color(0xFF3B82F6),
                        icon: Icons.upload,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        title: 'Generation',
                        value: '${formatNumber0(totalGen)} kWh',
                        color: const Color(0xFF10B981),
                        icon: Icons.solar_power,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Power Trend',
                child: SizedBox(
                  height: 240,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 10,
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
                            interval: 10,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toInt()}',
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
                            interval: (days.length / 6).clamp(1, 6).toDouble(),
                            getTitlesWidget: (v, meta) {
                              final i = v.toInt();
                              if (i < 0 || i >= days.length) {
                                return const SizedBox.shrink();
                              }
                              final dd = days[i]['reading_date'] as String;
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
                        _line(
                          'Import',
                          days,
                          'import_kwh',
                          const Color(0xFFF59E0B),
                        ),
                        _line(
                          'Export',
                          days,
                          'export_kwh',
                          const Color(0xFF3B82F6),
                        ),
                        _line(
                          'Generation',
                          days,
                          'generation_kwh',
                          const Color(0xFF10B981),
                        ),
                      ],
                    ),
                  ),
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
                                  '/solar.php',
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
                                final bytes = await PdfExporter.solarReport(
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
                title: 'Add Reading',
                child: Column(
                  children: [
                    _numField(_importCtrl, 'Import (kWh)', Icons.download),
                    const SizedBox(height: 12),
                    _numField(_exportCtrl, 'Export (kWh)', Icons.upload),
                    const SizedBox(height: 12),
                    _numField(_genCtrl, 'Generation (kWh)', Icons.solar_power),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
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
                            : const Text('Save Reading'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Recent Readings',
                child: days.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'No readings found for this period',
                            style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: days
                            .map((d) => _buildReadingTile(d))
                            .toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numField(TextEditingController c, String label, IconData icon) =>
      TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      );

  Widget _buildReadingTile(Map<String, dynamic> d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  d['reading_date'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () {
                      _importCtrl.text = (d['import_kwh']).toString();
                      _exportCtrl.text = (d['export_kwh']).toString();
                      _genCtrl.text = (d['generation_kwh']).toString();
                      _notesCtrl.text = (d['notes'] as String?) ?? '';
                      setState(
                        () => _selected = DateTime.parse(
                          d['reading_date'] as String,
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => _deleteSolar(d['reading_date'] as String),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ModernChip(
                label: 'Import: ${formatNumber0(d['import_kwh'])} kWh',
                backgroundColor: const Color(0xFFFEF3C7),
                textColor: const Color(0xFF92400E),
                icon: Icons.download,
              ),
              ModernChip(
                label: 'Export: ${formatNumber0(d['export_kwh'])} kWh',
                backgroundColor: const Color(0xFFDBEAFE),
                textColor: const Color(0xFF1E40AF),
                icon: Icons.upload,
              ),
              ModernChip(
                label: 'Gen: ${formatNumber0(d['generation_kwh'])} kWh',
                backgroundColor: const Color(0xFFD1FAE5),
                textColor: const Color(0xFF065F46),
                icon: Icons.solar_power,
              ),
            ],
          ),
          if ((d['notes'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Text(
                d['notes'] as String,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  double _asDouble(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;

  LineChartBarData _line(
    String label,
    List<Map<String, dynamic>> days,
    String key,
    Color color,
  ) {
    final spots = <FlSpot>[];
    for (var i = 0; i < days.length; i++) {
      final v = _asDouble(days[i][key]);
      spots.add(FlSpot(i.toDouble(), v));
    }
    return LineChartBarData(
      isCurved: true,
      color: color,
      barWidth: 3,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 4,
            color: color,
            strokeWidth: 2,
            strokeColor: Colors.white,
          );
        },
      ),
      spots: spots,
    );
  }
}
