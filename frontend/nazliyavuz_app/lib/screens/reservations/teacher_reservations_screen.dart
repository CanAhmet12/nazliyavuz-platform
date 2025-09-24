import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/reservation.dart';

class TeacherReservationsScreen extends StatefulWidget {
  const TeacherReservationsScreen({super.key});

  @override
  State<TeacherReservationsScreen> createState() => _TeacherReservationsScreenState();
}

class _TeacherReservationsScreenState extends State<TeacherReservationsScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  List<Reservation> _reservations = [];
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadReservations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReservations() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      final reservations = await _apiService.getTeacherReservations();
      if (mounted) {
        setState(() {
          _reservations = reservations;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rezervasyonlarım'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Bekleyen'),
            Tab(text: 'Kabul Edilen'),
            Tab(text: 'Tamamlanan'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Hata: $_error',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadReservations,
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildReservationsList('pending'),
                    _buildReservationsList('accepted'),
                    _buildReservationsList('completed'),
                  ],
                ),
    );
  }

  Widget _buildReservationsList(String status) {
    final filteredReservations = _reservations
        .where((reservation) => reservation.status == status)
        .toList();

    if (filteredReservations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Bu kategoride rezervasyon bulunmuyor',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredReservations.length,
      itemBuilder: (context, index) {
        final reservation = filteredReservations[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(reservation.status),
              child: Icon(
                _getStatusIcon(reservation.status),
                color: Colors.white,
              ),
            ),
            title: Text(reservation.student?.name ?? 'Öğrenci'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Konu: ${reservation.subject}'),
                Text('Tarih: ${_formatDateTime(reservation.proposedDatetime)}'),
                Text('Süre: ${reservation.formattedDuration}'),
                Text('Fiyat: ${reservation.formattedPrice}'),
                Text('Durum: ${reservation.statusText}'),
              ],
            ),
            trailing: reservation.status == 'pending'
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () => _updateReservationStatus(reservation.id, 'accepted'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => _updateReservationStatus(reservation.id, 'rejected'),
                      ),
                    ],
                  )
                : null,
          ),
        );
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
      case 'confirmed':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'accepted':
      case 'confirmed':
        return Icons.check_circle;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  Future<void> _updateReservationStatus(int reservationId, String status) async {
    try {
      await _apiService.updateReservationStatus(reservationId, status);
      await _loadReservations();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rezervasyon durumu güncellendi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
