import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:moto_passenger/design_system/design_system.dart';

class TravelHistoryPage extends StatefulWidget {
  const TravelHistoryPage({super.key});

  @override
  State<TravelHistoryPage> createState() => _TravelHistoryPageState();
}

class _TravelHistoryPageState extends State<TravelHistoryPage> {
  List<Map<String, dynamic>> _travels = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final dio = Modular.get<Dio>();
      final response = await dio.get('/api/travels/passenger?pageSize=50');
      setState(() {
        _travels = (response.data['items'] as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Viagens'),
        foregroundColor: context.moto.textSecondary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Erro ao carregar: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadHistory, child: const Text('Tentar novamente')),
                    ],
                  ),
                )
              : _travels.isEmpty
                  ? const Center(child: Text('Nenhuma viagem encontrada'))
                  : RefreshIndicator(
                      onRefresh: _loadHistory,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _travels.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (_, i) => ListTile(
                          leading: Icon(
                            _statusIcon(_travels[i]['status'] as String?),
                            color: _statusColor(context, _travels[i]['status'] as String?),
                          ),
                          title: Text(_travels[i]['driverName'] as String? ?? 'Motorista'),
                          subtitle: Text('Status: ${_travels[i]['status']}'),
                          trailing: Text(
                            _formatDate(_travels[i]['createdAt'] as String?),
                            style: TextStyle(fontSize: 12, color: context.moto.textSecondary),
                          ),
                        ),
                      ),
                    ),
    );
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'Completed': return Icons.task_alt;
      case 'Cancelled': return Icons.cancel;
      case 'InProgress': return Icons.directions_car;
      default: return Icons.access_time;
    }
  }

  Color _statusColor(BuildContext context, String? status) {
    switch (status) {
      case 'Completed': return context.moto.success;
      case 'Cancelled': return context.moto.danger;
      case 'InProgress': return context.moto.accent;
      default: return context.moto.warning;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
