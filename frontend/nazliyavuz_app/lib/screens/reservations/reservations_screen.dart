import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/reservation.dart';

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen>
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

      print('🔄 Rezervasyonlar yükleniyor...');
      final reservations = await _apiService.getStudentReservations();
      print('✅ Rezervasyonlar yüklendi: ${reservations.length} adet');
      
      if (mounted) {
        setState(() {
          _reservations = reservations;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Rezervasyon yükleme hatası: $e');
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
        title: const Text('Rezervasyonlar'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Tümü'),
            Tab(text: 'Beklemede'),
            Tab(text: 'Onaylandı'),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Bir hata oluştu',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadReservations,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildReservationsList(_reservations),
        _buildReservationsList(_reservations.where((r) => r.isPending).toList()),
        _buildReservationsList(_reservations.where((r) => r.isAccepted).toList()),
      ],
    );
  }

  Widget _buildReservationsList(List<Reservation> reservations) {
    if (reservations.isEmpty) {
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
              'Henüz rezervasyon yok',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Öğretmenlerden ders rezervasyonu yapabilirsiniz',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReservations,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: reservations.length,
        itemBuilder: (context, index) {
          final reservation = reservations[index];
          return _buildReservationCard(reservation);
        },
      ),
    );
  }

  Widget _buildReservationCard(Reservation reservation) {
    print('📋 Rezervasyon kartı oluşturuluyor: ${reservation.subject}');
    print('   - Durum: ${reservation.status}');
    print('   - Öğretmen: ${reservation.teacher?.name ?? 'Bilinmiyor'}');
    print('   - Tarih: ${reservation.proposedDatetime}');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık ve Durum
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    reservation.subject,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(reservation.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      reservation.statusText,
                      style: TextStyle(
                        color: _getStatusColor(reservation.status),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Öğretmen Bilgisi
            if (reservation.teacher != null) ...[
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    backgroundImage: reservation.teacher!.user?.profilePhotoUrl != null
                        ? NetworkImage(reservation.teacher!.user!.profilePhotoUrl!)
                        : null,
                    child: reservation.teacher!.user?.profilePhotoUrl == null
                        ? Text(
                            (reservation.teacher!.name ?? 'Ö')[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reservation.teacher!.name ?? 'Bilinmeyen Öğretmen',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Tarih ve Saat
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatDateTime(reservation.proposedDatetime),
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  reservation.formattedDuration,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Fiyat
            Row(
              children: [
                Icon(
                  Icons.attach_money,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    reservation.formattedPrice,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // Notlar
            if (reservation.notes != null && reservation.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  reservation.notes!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],

            // Aksiyon Butonları
            if (reservation.canBeCancelled) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      _showCancelDialog(reservation);
                    },
                    child: const Text('İptal Et'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reservationDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (reservationDate == today) {
      return 'Bugün ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (reservationDate == today.add(const Duration(days: 1))) {
      return 'Yarın ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  void _showCancelDialog(Reservation reservation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rezervasyonu İptal Et'),
        content: const Text('Bu rezervasyonu iptal etmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hayır'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              try {
                await _apiService.updateReservation(reservation.id, {
                  'status': 'cancelled',
                });
                _loadReservations();
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Rezervasyon iptal edildi'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Hata: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Evet'),
          ),
        ],
      ),
    );
  }
}
