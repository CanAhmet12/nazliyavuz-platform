import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _stats;
  List<dynamic>? _recentActivities;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.getAdminDashboard();
      setState(() {
        _stats = response['stats'];
        _recentActivities = response['recent_activities'];
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
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          RepaintBoundary(
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadDashboardData,
            ),
          ),
        ],
      ),
      body: RepaintBoundary(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildErrorWidget()
                : _buildDashboardContent(),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Hata Oluştu',
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
            onPressed: _loadDashboardData,
            child: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // İstatistik Kartları
          Text(
            'Genel İstatistikler',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.3,
            children: [
              _buildStatCard(
                'Toplam Kullanıcı',
                _stats!['total_users'].toString(),
                Icons.people,
                Colors.blue,
              ),
              _buildStatCard(
                'Öğretmenler',
                _stats!['total_teachers'].toString(),
                Icons.school,
                Colors.green,
              ),
              _buildStatCard(
                'Öğrenciler',
                _stats!['total_students'].toString(),
                Icons.person,
                Colors.orange,
              ),
              _buildStatCard(
                'Rezervasyonlar',
                _stats!['total_reservations'].toString(),
                Icons.calendar_today,
                Colors.purple,
              ),
              _buildStatCard(
                'Bekleyen',
                _stats!['pending_reservations'].toString(),
                Icons.pending,
                Colors.amber,
              ),
              _buildStatCard(
                'Tamamlanan',
                _stats!['completed_reservations'].toString(),
                Icons.check_circle,
                Colors.teal,
              ),
            ],
              );
            },
          ),
          const SizedBox(height: 32),

          // Son Aktiviteler
          Text(
            'Son Aktiviteler',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (_recentActivities!.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'Henüz aktivite bulunmuyor',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),
            )
          else
            ..._recentActivities!.map((activity) => _buildActivityCard(activity)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              child: Icon(
                _getActivityIcon(activity['action']),
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getActivityDescription(activity),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDateTime(DateTime.parse(activity['created_at'])),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getActivityIcon(String action) {
    switch (action) {
      case 'create_user':
        return Icons.person_add;
      case 'update_user_status':
        return Icons.edit;
      case 'create_reservation':
        return Icons.calendar_today;
      case 'create_category':
        return Icons.category;
      default:
        return Icons.info;
    }
  }

  String _getActivityDescription(Map<String, dynamic> activity) {
    final user = activity['user'];
    final userName = user != null ? user['name'] : 'Sistem';
    
    switch (activity['action']) {
      case 'create_user':
        return '$userName yeni kullanıcı oluşturdu';
      case 'update_user_status':
        return '$userName kullanıcı durumu güncelledi';
      case 'create_reservation':
        return '$userName rezervasyon oluşturdu';
      case 'create_category':
        return '$userName kategori oluşturdu';
      default:
        return '$userName ${activity['action']} işlemi yaptı';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} gün önce';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat önce';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} dakika önce';
    } else {
      return 'Az önce';
    }
  }
}
