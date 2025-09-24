import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/api_service.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  final ApiService _apiService = ApiService();
  
  Map<String, dynamic>? _analytics;
  bool _isLoading = true;
  String _selectedPeriod = '30';
  
  final List<String> _periods = ['7', '30', '90', '365'];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final analytics = await _apiService.getAdminAnalytics();
      if (mounted) {
        setState(() {
          _analytics = analytics;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analytics yüklenirken hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Analitikleri'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          DropdownButton<String>(
            value: _selectedPeriod,
            items: _periods.map((period) {
              String label;
              switch (period) {
                case '7':
                  label = 'Son 7 Gün';
                  break;
                case '30':
                  label = 'Son 30 Gün';
                  break;
                case '90':
                  label = 'Son 90 Gün';
                  break;
                case '365':
                  label = 'Son 1 Yıl';
                  break;
                default:
                  label = period;
              }
              return DropdownMenuItem(
                value: period,
                child: Text(label),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedPeriod = value!;
              });
              _loadAnalytics();
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: RepaintBoundary(
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _analytics == null
              ? const Center(child: Text('Veri bulunamadı'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOverviewCards(),
                      const SizedBox(height: 24),
                      _buildUserRegistrationsChart(),
                      const SizedBox(height: 24),
                      _buildReservationTrendsChart(),
                      const SizedBox(height: 24),
                      _buildRevenueChart(),
                      const SizedBox(height: 24),
                      _buildTeacherPerformance(),
                      const SizedBox(height: 24),
                      _buildCategoryPopularity(),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildOverviewCards() {
    final userActivity = _analytics!['user_activity'] as Map<String, dynamic>? ?? {};
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
      children: [
        _buildStatCard(
          'Aktif Kullanıcılar',
          userActivity['active_users'].toString(),
          Icons.people,
          Colors.blue,
        ),
        _buildStatCard(
          'Yeni Kullanıcılar',
          userActivity['new_users'].toString(),
          Icons.person_add,
          Colors.green,
        ),
        _buildStatCard(
          'Doğrulanmış',
          userActivity['verified_users'].toString(),
          Icons.verified,
          Colors.orange,
        ),
        _buildStatCard(
          'Doğrulanmamış',
          userActivity['unverified_users'].toString(),
          Icons.warning,
          Colors.red,
        ),
      ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserRegistrationsChart() {
    final registrations = _analytics!['user_registrations'] as List<dynamic>? ?? [];
    
    if (registrations.isEmpty) {
      return _buildEmptyChart('Kullanıcı Kayıtları', 'Veri bulunamadı');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kullanıcı Kayıtları',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: registrations.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), 
                            (entry.value['count'] as num).toDouble());
                      }).toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReservationTrendsChart() {
    final trends = _analytics!['reservation_trends'] as Map<String, dynamic>? ?? {};
    
    if (trends.isEmpty) {
      return _buildEmptyChart('Rezervasyon Trendleri', 'Veri bulunamadı');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rezervasyon Trendleri',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: trends.entries.map((entry) {
                    final status = entry.key;
                    final data = entry.value as List<dynamic>? ?? [];
                    
                    Color color;
                    switch (status) {
                      case 'completed':
                        color = Colors.green;
                        break;
                      case 'pending':
                        color = Colors.orange;
                        break;
                      case 'cancelled':
                        color = Colors.red;
                        break;
                      default:
                        color = Colors.blue;
                    }
                    
                    return LineChartBarData(
                      spots: data.asMap().entries.map((dataEntry) {
                        return FlSpot(dataEntry.key.toDouble(), 
                            (dataEntry.value['count'] as num).toDouble());
                      }).toList(),
                      isCurved: true,
                      color: color,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart() {
    final revenue = _analytics!['revenue_analytics'] as List<dynamic>? ?? [];
    
    if (revenue.isEmpty) {
      return _buildEmptyChart('Gelir Analizi', 'Veri bulunamadı');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gelir Analizi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  barGroups: revenue.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: (entry.value['revenue'] as num).toDouble(),
                          color: Colors.green,
                          width: 16,
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherPerformance() {
    final performance = _analytics!['teacher_performance'] as List<dynamic>? ?? [];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'En Başarılı Öğretmenler',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...performance.map((teacher) {
              final user = teacher['user'] as Map<String, dynamic>? ?? {};
              final completedReservations = teacher['completed_reservations'] as int;
              final avgRating = teacher['ratings_avg_rating'] as double? ?? 0.0;
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: user['profile_photo_url'] != null
                      ? NetworkImage(user['profile_photo_url'])
                      : null,
                  child: user['profile_photo_url'] == null
                      ? Text(user['name'][0].toUpperCase())
                      : null,
                ),
                title: Text(user['name']),
                subtitle: Text('$completedReservations tamamlanan ders'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(avgRating.toStringAsFixed(1)),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPopularity() {
    final categories = _analytics!['category_popularity'] as List<dynamic>? ?? [];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Popüler Kategoriler',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...categories.map((category) {
              final reservationsCount = category['reservations_count'] as int;
              final teachersCount = category['teachers_count'] as int;
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    category['name'][0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(category['name']),
                subtitle: Text('$reservationsCount rezervasyon, $teachersCount öğretmen'),
                trailing: Text(
                  '$reservationsCount',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChart(String title, String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Icon(
              Icons.bar_chart,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
