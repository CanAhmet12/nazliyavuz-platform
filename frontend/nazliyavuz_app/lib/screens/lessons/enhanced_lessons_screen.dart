import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../../models/teacher.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_widgets.dart';
import '../reservations/create_reservation_screen.dart';
import 'lesson_detail_screen.dart';

class EnhancedLessonsScreen extends StatefulWidget {
  const EnhancedLessonsScreen({super.key});

  @override
  State<EnhancedLessonsScreen> createState() => _EnhancedLessonsScreenState();
}

class _EnhancedLessonsScreenState extends State<EnhancedLessonsScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  List<dynamic> _lessons = [];
  List<dynamic> _upcomingLessons = [];
  Map<String, dynamic> _statistics = {};
  
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isGridView = false;
  String? _error;
  
  // Filters
  String _selectedStatus = '';
  String _selectedDateRange = '';
  String _sortBy = 'created_at';
  String _sortOrder = 'desc';
  
  int _currentPage = 1;
  bool _hasMorePages = true;

  final List<Map<String, dynamic>> _statusOptions = [
    {'value': '', 'label': 'Tümü', 'icon': Icons.all_inclusive_rounded, 'color': AppTheme.primaryBlue},
    {'value': 'not_started', 'label': 'Başlamamış', 'icon': Icons.schedule_rounded, 'color': Colors.orange},
    {'value': 'in_progress', 'label': 'Devam Ediyor', 'icon': Icons.play_circle_rounded, 'color': Colors.green},
    {'value': 'completed', 'label': 'Tamamlanmış', 'icon': Icons.check_circle_rounded, 'color': Colors.blue},
  ];

  final List<Map<String, dynamic>> _sortOptions = [
    {'value': 'created_at', 'label': 'En Yeni', 'icon': Icons.schedule_rounded},
    {'value': 'start_time', 'label': 'Başlangıç Zamanı', 'icon': Icons.access_time_rounded},
    {'value': 'duration_minutes', 'label': 'Süre', 'icon': Icons.timer_rounded},
    {'value': 'rating', 'label': 'Puan', 'icon': Icons.star_rounded},
  ];

  final List<Map<String, dynamic>> _dateRangeOptions = [
    {'value': '', 'label': 'Tüm Zamanlar', 'icon': Icons.calendar_today_rounded},
    {'value': 'today', 'label': 'Bugün', 'icon': Icons.today_rounded},
    {'value': 'week', 'label': 'Bu Hafta', 'icon': Icons.date_range_rounded},
    {'value': 'month', 'label': 'Bu Ay', 'icon': Icons.calendar_month_rounded},
    {'value': 'year', 'label': 'Bu Yıl', 'icon': Icons.calendar_today},
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadInitialData();
    _setupScrollListener();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMoreLessons();
      }
    });
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Paralel olarak veri yükle
      await Future.wait([
        _loadLessons(),
        _loadUpcomingLessons(),
        _loadStatistics(),
      ]);

      if (mounted) {
        _animationController.forward();
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

  Future<void> _loadLessons() async {
    try {
      final lessons = await _apiService.getUserLessons(
        status: _selectedStatus.isNotEmpty ? _selectedStatus : null,
        dateFrom: _getDateFrom(),
        dateTo: _getDateTo(),
        sortBy: _sortBy,
        sortOrder: _sortOrder,
        page: _currentPage,
        perPage: 20,
      );

      if (mounted) {
        setState(() {
          if (_currentPage == 1) {
            _lessons = lessons;
          } else {
            _lessons.addAll(lessons);
          }
          _isLoading = false;
          _isLoadingMore = false;
          _hasMorePages = lessons.isNotEmpty;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadUpcomingLessons() async {
    try {
      final upcoming = await _apiService.getUpcomingLessons();
      if (mounted) {
        setState(() {
          _upcomingLessons = upcoming;
        });
      }
    } catch (e) {
      print('Upcoming lessons loading error: $e');
    }
  }

  Future<void> _loadStatistics() async {
    try {
      final stats = await _apiService.getLessonStatistics();
      if (mounted) {
        setState(() {
          _statistics = stats;
        });
      }
    } catch (e) {
      print('Statistics loading error: $e');
    }
  }

  Future<void> _loadMoreLessons() async {
    if (_isLoadingMore || !_hasMorePages) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    _currentPage++;
    await _loadLessons();
  }

  Future<void> _refreshData() async {
    _currentPage = 1;
    _hasMorePages = true;
    await _loadInitialData();
  }

  void _applyFilters() {
    _currentPage = 1;
    _hasMorePages = true;
    _loadLessons();
  }

  void _clearFilters() {
    setState(() {
      _selectedStatus = '';
      _selectedDateRange = '';
      _sortBy = 'created_at';
      _sortOrder = 'desc';
    });
    _applyFilters();
  }

  String? _getDateFrom() {
    switch (_selectedDateRange) {
      case 'today':
        return DateTime.now().toIso8601String().split('T')[0];
      case 'week':
        return DateTime.now().subtract(const Duration(days: 7)).toIso8601String().split('T')[0];
      case 'month':
        return DateTime.now().subtract(const Duration(days: 30)).toIso8601String().split('T')[0];
      case 'year':
        return DateTime.now().subtract(const Duration(days: 365)).toIso8601String().split('T')[0];
      default:
        return null;
    }
  }

  String? _getDateTo() {
    return _selectedDateRange.isNotEmpty ? DateTime.now().toIso8601String().split('T')[0] : null;
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            children: [
              // Statistics Banner
              if (_statistics.isNotEmpty) _buildStatisticsBanner(),
              
              // Upcoming Lessons
              if (_upcomingLessons.isNotEmpty) _buildUpcomingSection(),
              
              // Filters
              _buildFilters(),
              
              // Results
              Expanded(
                child: _isLoading
                    ? CustomWidgets.customLoading(message: 'Dersler yükleniyor...')
                    : _error != null
                        ? _buildErrorState()
                        : _lessons.isEmpty
                            ? _buildEmptyState()
                            : _buildResults(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Derslerim',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 24,
        ),
      ),
      centerTitle: true,
      elevation: 0,
      backgroundColor: AppTheme.backgroundColor,
      foregroundColor: AppTheme.textPrimary,
      actions: [
        IconButton(
          icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
          onPressed: () {
            setState(() {
              _isGridView = !_isGridView;
            });
            HapticFeedback.lightImpact();
          },
        ),
      ],
    );
  }

  Widget _buildStatisticsBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBlue,
            AppTheme.primaryBlue.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              icon: Icons.school_rounded,
              label: 'Toplam Ders',
              value: '${_statistics['total_lessons'] ?? 0}',
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          Expanded(
            child: _buildStatItem(
              icon: Icons.check_circle_rounded,
              label: 'Tamamlanan',
              value: '${_statistics['completed_lessons'] ?? 0}',
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          Expanded(
            child: _buildStatItem(
              icon: Icons.timer_rounded,
              label: 'Toplam Süre',
              value: '${(_statistics['total_duration'] ?? 0) ~/ 60}sa',
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          Expanded(
            child: _buildStatItem(
              icon: Icons.star_rounded,
              label: 'Ortalama Puan',
              value: '${(_statistics['average_rating'] ?? 0).toStringAsFixed(1)}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildUpcomingSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '⏰ Yaklaşan Dersler',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedStatus = 'not_started';
                  });
                  _applyFilters();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Tümünü Gör',
                    style: TextStyle(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _upcomingLessons.length,
              itemBuilder: (context, index) {
                final lesson = _upcomingLessons[index];
                return Container(
                  width: 200,
                  margin: EdgeInsets.only(right: index == _upcomingLessons.length - 1 ? 0 : 12),
                  child: _buildUpcomingLessonCard(lesson),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildUpcomingLessonCard(dynamic lesson) {
    final reservation = lesson['reservation'];
    final teacher = lesson['teacher'];
    final category = reservation?['category'];
    
    return GestureDetector(
      onTap: () => _navigateToLessonDetail(lesson),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  child: Text(
                    teacher?['user']?['name']?.substring(0, 1).toUpperCase() ?? '?',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacher?['user']?['name'] ?? 'İsimsiz',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        category?['name'] ?? 'Genel',
                        style: TextStyle(
                          color: AppTheme.grey600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 14, color: AppTheme.grey600),
                const SizedBox(width: 4),
                Text(
                  _formatDateTime(reservation?['scheduled_at']),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.grey600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(
              label: 'Durum',
              value: _statusOptions.firstWhere((opt) => opt['value'] == _selectedStatus, orElse: () => _statusOptions.first)['label'],
              onTap: _showStatusFilter,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'Tarih',
              value: _dateRangeOptions.firstWhere((opt) => opt['value'] == _selectedDateRange, orElse: () => _dateRangeOptions.first)['label'],
              onTap: _showDateRangeFilter,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'Sırala',
              value: _sortOptions.firstWhere((opt) => opt['value'] == _sortBy)['label'],
              onTap: _showSortFilter,
            ),
            if (_selectedStatus.isNotEmpty || _selectedDateRange.isNotEmpty || _sortBy != 'created_at')
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: GestureDetector(
                  onTap: _clearFilters,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.clear_rounded, size: 16, color: AppTheme.errorColor),
                        const SizedBox(width: 4),
                        Text(
                          'Temizle',
                          style: TextStyle(
                            color: AppTheme.errorColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.grey300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: ',
              style: TextStyle(
                color: AppTheme.grey600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppTheme.grey500),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: _isGridView ? _buildGridView() : _buildListView(),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _lessons.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _lessons.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildLessonCard(_lessons[index]),
        );
      },
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: _lessons.length + (_isLoadingMore ? 2 : 0),
      itemBuilder: (context, index) {
        if (index >= _lessons.length) {
          return const Center(child: CircularProgressIndicator());
        }
        
        return _buildGridLessonCard(_lessons[index]);
      },
    );
  }

  Widget _buildLessonCard(dynamic lesson) {
    final reservation = lesson['reservation'];
    final teacher = lesson['teacher'];
    final category = reservation?['category'];
    final status = lesson['status'];
    
    return GestureDetector(
      onTap: () => _navigateToLessonDetail(lesson),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusText(status),
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                if (lesson['rating'] != null)
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        '${lesson['rating']}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Lesson Info
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  child: Text(
                    teacher?['user']?['name']?.substring(0, 1).toUpperCase() ?? '?',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacher?['user']?['name'] ?? 'İsimsiz Öğretmen',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        category?['name'] ?? 'Genel',
                        style: TextStyle(
                          color: AppTheme.grey600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 14, color: AppTheme.grey600),
                          const SizedBox(width: 4),
                          Text(
                            _formatDateTime(reservation?['scheduled_at']),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.grey600,
                            ),
                          ),
                          if (lesson['duration_minutes'] != null) ...[
                            const SizedBox(width: 16),
                            Icon(Icons.timer_rounded, size: 14, color: AppTheme.grey600),
                            const SizedBox(width: 4),
                            Text(
                              '${lesson['duration_minutes']} dk',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.grey600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppTheme.grey400,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridLessonCard(dynamic lesson) {
    final reservation = lesson['reservation'];
    final teacher = lesson['teacher'];
    final category = reservation?['category'];
    final status = lesson['status'];
    
    return GestureDetector(
      onTap: () => _navigateToLessonDetail(lesson),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getStatusText(status),
                style: TextStyle(
                  color: _getStatusColor(status),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Teacher Info
            Center(
              child: CircleAvatar(
                radius: 30,
                backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                child: Text(
                  teacher?['user']?['name']?.substring(0, 1).toUpperCase() ?? '?',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Details
            Text(
              teacher?['user']?['name'] ?? 'İsimsiz',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              category?['name'] ?? 'Genel',
              style: TextStyle(
                color: AppTheme.grey600,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            if (lesson['rating'] != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                  const SizedBox(width: 2),
                  Text(
                    '${lesson['rating']}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: AppTheme.errorColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Bir hata oluştu',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Bilinmeyen hata',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.grey600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar Dene'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 64,
              color: AppTheme.grey400,
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz ders yok',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'İlk dersinizi planlamak için rezervasyon oluşturun',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.grey600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _navigateToCreateReservation(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ders Planla'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: () => _navigateToCreateReservation(),
      backgroundColor: AppTheme.primaryBlue,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Yeni Ders'),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'not_started':
        return Colors.orange;
      case 'in_progress':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      default:
        return AppTheme.grey500;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'not_started':
        return 'Başlamamış';
      case 'in_progress':
        return 'Devam Ediyor';
      case 'completed':
        return 'Tamamlanmış';
      default:
        return 'Bilinmiyor';
    }
  }

  String _formatDateTime(String? dateTime) {
    if (dateTime == null) return 'Tarih belirtilmemiş';
    
    try {
      final date = DateTime.parse(dateTime);
      return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Geçersiz tarih';
    }
  }

  void _navigateToLessonDetail(dynamic lesson) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LessonDetailScreen(lesson: lesson),
      ),
    );
  }

  void _navigateToCreateReservation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateReservationScreen(teacher: Teacher(userId: 0)),
      ),
    );
  }

  void _showStatusFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Durum Seç',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedStatus = '';
                      });
                      _applyFilters();
                      Navigator.pop(context);
                    },
                    child: const Text('Temizle'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _statusOptions.length,
                itemBuilder: (context, index) {
                  final option = _statusOptions[index];
                  final isSelected = _selectedStatus == option['value'];
                  
                  return ListTile(
                    leading: Icon(option['icon'], color: option['color']),
                    title: Text(option['label']),
                    trailing: isSelected ? const Icon(Icons.check_rounded, color: AppTheme.primaryBlue) : null,
                    selected: isSelected,
                    onTap: () {
                      setState(() {
                        _selectedStatus = isSelected ? '' : option['value'];
                      });
                      _applyFilters();
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDateRangeFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Tarih Aralığı',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            ..._dateRangeOptions.map((option) => ListTile(
              leading: Icon(option['icon']),
              title: Text(option['label']),
              trailing: _selectedDateRange == option['value'] 
                  ? const Icon(Icons.check_rounded, color: AppTheme.primaryBlue)
                  : null,
              onTap: () {
                setState(() {
                  _selectedDateRange = option['value'];
                });
                _applyFilters();
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }

  void _showSortFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sıralama Seçenekleri',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            ..._sortOptions.map((option) => ListTile(
              leading: Icon(option['icon']),
              title: Text(option['label']),
              trailing: _sortBy == option['value'] 
                  ? const Icon(Icons.check_rounded, color: AppTheme.primaryBlue)
                  : null,
              onTap: () {
                setState(() {
                  _sortBy = option['value'];
                  _sortOrder = _sortOrder == 'desc' ? 'asc' : 'desc';
                });
                _applyFilters();
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }
}
