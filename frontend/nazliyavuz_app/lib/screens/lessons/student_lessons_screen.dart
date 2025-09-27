import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../models/lesson.dart';
import 'lesson_detail_screen.dart';

class StudentLessonsScreen extends StatefulWidget {
  const StudentLessonsScreen({super.key});

  @override
  State<StudentLessonsScreen> createState() => _StudentLessonsScreenState();
}

class _StudentLessonsScreenState extends State<StudentLessonsScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  
  late AnimationController _animationController;
  late AnimationController _cardAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  
  List<dynamic> _lessons = [];
  List<dynamic> _upcomingLessons = [];
  Map<String, dynamic> _statistics = {};
  
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isListView = true;
  String? _error;
  
  // Filters
  String _selectedStatus = '';
  
  bool _hasMorePages = true;

  final List<Map<String, dynamic>> _statusOptions = [
    {'value': '', 'label': 'Tümü', 'icon': Icons.all_inclusive_rounded, 'color': AppTheme.primaryBlue},
    {'value': 'upcoming', 'label': 'Yaklaşan', 'icon': Icons.schedule_rounded, 'color': AppTheme.accentOrange},
    {'value': 'in_progress', 'label': 'Devam Eden', 'icon': Icons.play_circle_rounded, 'color': AppTheme.accentGreen},
    {'value': 'completed', 'label': 'Tamamlanan', 'icon': Icons.check_circle_rounded, 'color': AppTheme.primaryBlue},
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
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _animationController.forward();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoadingMore && _hasMorePages) {
          _loadMoreLessons();
        }
      }
    });
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadLessons(),
      _loadStatistics(),
    ]);
  }

  Future<void> _loadLessons() async {
    if (_isLoading) {
      setState(() {
        _error = null;
      });
    }

    try {
      final lessons = await _apiService.getUserLessons();
      
      if (mounted) {
        setState(() {
          _lessons = lessons;
          _upcomingLessons = lessons.where((lesson) {
            final scheduledAt = DateTime.parse(lesson['scheduled_at']);
            return scheduledAt.isAfter(DateTime.now()) && 
                   lesson['status'] == 'scheduled';
          }).toList();
          _isLoading = false;
          _isLoadingMore = false;
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

  Future<void> _loadStatistics() async {
    try {
      final stats = await _apiService.getUserStatistics();
      if (mounted) {
        setState(() {
          _statistics = stats;
        });
      }
    } catch (e) {
      print('Error loading statistics: $e');
    }
  }

  Future<void> _loadMoreLessons() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final moreLessons = await _apiService.getUserLessons();
      
      if (mounted) {
        setState(() {
          _lessons.addAll(moreLessons);
          _hasMorePages = moreLessons.length >= 20;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _hasMorePages = true;
    });
    await _loadInitialData();
  }

  List<dynamic> _getFilteredLessons() {
    if (_selectedStatus.isEmpty) return _lessons;
    
    return _lessons.where((lesson) {
      switch (_selectedStatus) {
        case 'upcoming':
          final scheduledAt = DateTime.parse(lesson['scheduled_at']);
          return scheduledAt.isAfter(DateTime.now()) && lesson['status'] == 'scheduled';
        case 'in_progress':
          return lesson['status'] == 'in_progress';
        case 'completed':
          return lesson['status'] == 'completed';
        default:
          return true;
      }
    }).toList();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cardAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: RefreshIndicator(
            onRefresh: _refreshData,
            color: AppTheme.primaryBlue,
            backgroundColor: Colors.white,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Modern Hero App Bar
                _buildModernHeroAppBar(),
                
                // Statistics Cards
                if (_statistics.isNotEmpty)
                  SliverToBoxAdapter(
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: _buildStatisticsSection(),
                    ),
                  ),
                
                // Upcoming Lessons
                if (_upcomingLessons.isNotEmpty)
                  SliverToBoxAdapter(
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: _buildUpcomingLessonsSection(),
                    ),
                  ),
                
                // Filter Section
                SliverToBoxAdapter(
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: _buildFilterSection(),
                  ),
                ),
                
                // Results Header
                SliverToBoxAdapter(
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: _buildResultsHeader(),
                  ),
                ),
                
                // Lessons List
                _isLoading
                    ? SliverToBoxAdapter(
                        child: _buildLoadingState(),
                      )
                    : _error != null
                        ? SliverToBoxAdapter(
                            child: _buildErrorState(),
                          )
                        : _getFilteredLessons().isEmpty
                            ? SliverToBoxAdapter(
                                child: _buildEmptyState(),
                              )
                            : _buildLessonsList(),
                
                // Load More Indicator
                if (_isLoadingMore)
                  SliverToBoxAdapter(
                    child: _buildLoadMoreIndicator(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernHeroAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryBlue,
                AppTheme.primaryBlue.withOpacity(0.8),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.book_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Derslerim',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Öğrenci dersleri ve ilerleme',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'İstatistikler',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.grey900,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Toplam Ders',
                  '${_statistics['total_lessons'] ?? 0}',
                  Icons.book_rounded,
                  AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Tamamlanan',
                  '${_statistics['completed_lessons'] ?? 0}',
                  Icons.check_circle_rounded,
                  AppTheme.accentGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Yaklaşan',
                  '${_statistics['upcoming_lessons'] ?? 0}',
                  Icons.schedule_rounded,
                  AppTheme.accentOrange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.grey600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingLessonsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Yaklaşan Dersler',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.grey900,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _upcomingLessons.length,
              itemBuilder: (context, index) {
                final lesson = _upcomingLessons[index];
                return Container(
                  width: 280,
                  margin: EdgeInsets.only(
                    right: index < _upcomingLessons.length - 1 ? 12 : 0,
                  ),
                  child: _buildUpcomingLessonCard(lesson),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingLessonCard(Map<String, dynamic> lesson) {
    final scheduledAt = DateTime.parse(lesson['scheduled_at']);
    final teacher = lesson['teacher'];
    
    return GestureDetector(
      onTap: () => _navigateToLessonDetail(lesson),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryBlue.withOpacity(0.1),
              AppTheme.primaryBlue.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryBlue.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                  backgroundImage: teacher?['profile_photo_url'] != null
                      ? NetworkImage(teacher['profile_photo_url'])
                      : null,
                  child: teacher?['profile_photo_url'] == null
                      ? Text(
                          teacher?['name']?.substring(0, 1).toUpperCase() ?? '?',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryBlue,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    teacher?['name'] ?? 'Bilinmiyor',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.grey900,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              lesson['subject'] ?? 'Ders',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.grey900,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 14,
                  color: AppTheme.grey600,
                ),
                const SizedBox(width: 4),
                Text(
                  '${scheduledAt.day}/${scheduledAt.month} ${scheduledAt.hour}:${scheduledAt.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
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

  Widget _buildFilterSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filtrele',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.grey900,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _statusOptions.length,
              itemBuilder: (context, index) {
                final option = _statusOptions[index];
                final isSelected = _selectedStatus == option['value'];
                
                return Container(
                  margin: EdgeInsets.only(
                    right: index < _statusOptions.length - 1 ? 8 : 0,
                  ),
                  child: FilterChip(
                    label: Text(
                      option['label'],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : option['color'],
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedStatus = selected ? option['value'] : '';
                      });
                      HapticFeedback.lightImpact();
                    },
                    backgroundColor: Colors.white,
                    selectedColor: option['color'],
                    checkmarkColor: Colors.white,
                    side: BorderSide(
                      color: isSelected ? option['color'] : AppTheme.grey300,
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsHeader() {
    final filteredLessons = _getFilteredLessons();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${filteredLessons.length} ders bulundu',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.grey600,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _isListView = true;
                  });
                  HapticFeedback.lightImpact();
                },
                icon: Icon(
                  Icons.list_rounded,
                  color: _isListView ? AppTheme.primaryBlue : AppTheme.grey400,
                  size: 20,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _isListView = false;
                  });
                  HapticFeedback.lightImpact();
                },
                icon: Icon(
                  Icons.grid_view_rounded,
                  color: !_isListView ? AppTheme.primaryBlue : AppTheme.grey400,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLessonsList() {
    final filteredLessons = _getFilteredLessons();
    
    if (_isListView) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final lesson = filteredLessons[index];
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: _buildLessonCard(lesson),
            );
          },
          childCount: filteredLessons.length,
        ),
      );
    } else {
      return SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.8,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final lesson = filteredLessons[index];
              return _buildLessonCard(lesson, isGrid: true);
            },
            childCount: filteredLessons.length,
          ),
        ),
      );
    }
  }

  Widget _buildLessonCard(Map<String, dynamic> lesson, {bool isGrid = false}) {
    final scheduledAt = DateTime.parse(lesson['scheduled_at']);
    final teacher = lesson['teacher'];
    final status = lesson['status'];
    
    return GestureDetector(
      onTap: () => _navigateToLessonDetail(lesson),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: isGrid ? 12 : 16,
                  backgroundColor: _getStatusColor(status).withOpacity(0.1),
                  backgroundImage: teacher?['profile_photo_url'] != null
                      ? NetworkImage(teacher['profile_photo_url'])
                      : null,
                  child: teacher?['profile_photo_url'] == null
                      ? Text(
                          teacher?['name']?.substring(0, 1).toUpperCase() ?? '?',
                          style: TextStyle(
                            fontSize: isGrid ? 10 : 12,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(status),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacher?['name'] ?? 'Bilinmiyor',
                        style: TextStyle(
                          fontSize: isGrid ? 12 : 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.grey900,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!isGrid) ...[
                        const SizedBox(height: 2),
                        Text(
                          lesson['subject'] ?? 'Ders',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.grey600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getStatusText(status),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(status),
                    ),
                  ),
                ),
              ],
            ),
            if (isGrid) ...[
              const SizedBox(height: 8),
              Text(
                lesson['subject'] ?? 'Ders',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.grey900,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
            const Spacer(),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 14,
                  color: AppTheme.grey600,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${scheduledAt.day}/${scheduledAt.month} ${scheduledAt.hour}:${scheduledAt.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.grey600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: const Center(
        child: CircularProgressIndicator(
          color: AppTheme.primaryBlue,
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppTheme.grey400,
          ),
          const SizedBox(height: 16),
          Text(
            'Dersler yüklenirken hata oluştu',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.grey600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Bilinmeyen hata',
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.grey500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshData,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.book_outlined,
            size: 48,
            color: AppTheme.grey400,
          ),
          const SizedBox(height: 16),
          const Text(
            'Henüz ders bulunmuyor',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.grey600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Öğretmenlerinizden ders rezervasyonu yaparak başlayabilirsiniz.',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.grey500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Center(
        child: CircularProgressIndicator(
          color: AppTheme.primaryBlue,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'scheduled':
        return AppTheme.primaryBlue;
      case 'in_progress':
        return AppTheme.accentOrange;
      case 'completed':
        return AppTheme.accentGreen;
      case 'cancelled':
        return Colors.red[600]!;
      default:
        return AppTheme.grey600;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'scheduled':
        return 'Planlandı';
      case 'in_progress':
        return 'Devam Eden';
      case 'completed':
        return 'Tamamlandı';
      case 'cancelled':
        return 'İptal';
      default:
        return 'Bilinmiyor';
    }
  }

  void _navigateToLessonDetail(Map<String, dynamic> lesson) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LessonDetailScreen(lesson: Lesson.fromJson(lesson)),
      ),
    );
  }
}
