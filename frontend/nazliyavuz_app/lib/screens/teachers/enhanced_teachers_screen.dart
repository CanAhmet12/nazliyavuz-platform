import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../../models/teacher.dart';
import '../../models/category.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_widgets.dart';
import '../../widgets/teacher_card.dart';
import 'teacher_detail_screen.dart';
import 'teacher_filters_screen.dart';

class EnhancedTeachersScreen extends StatefulWidget {
  const EnhancedTeachersScreen({super.key});

  @override
  State<EnhancedTeachersScreen> createState() => _EnhancedTeachersScreenState();
}

class _EnhancedTeachersScreenState extends State<EnhancedTeachersScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  List<Teacher> _teachers = [];
  List<Teacher> _featuredTeachers = [];
  List<Category> _categories = [];
  Map<String, dynamic> _statistics = {};
  
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isGridView = false;
  String? _error;
  
  // Filters
  String _selectedCategory = '';
  double _minPrice = 0;
  double _maxPrice = 1000;
  double _minRating = 0;
  bool _onlineOnly = false;
  String _sortBy = 'rating';
  String _searchQuery = '';
  
  int _currentPage = 1;
  bool _hasMorePages = true;

  final List<Map<String, dynamic>> _sortOptions = [
    {'value': 'rating', 'label': 'En Yüksek Puan', 'icon': Icons.star_rounded},
    {'value': 'price_low', 'label': 'En Düşük Fiyat', 'icon': Icons.attach_money_rounded},
    {'value': 'price_high', 'label': 'En Yüksek Fiyat', 'icon': Icons.monetization_on_rounded},
    {'value': 'recent', 'label': 'En Yeni', 'icon': Icons.schedule_rounded},
    {'value': 'popular', 'label': 'En Popüler', 'icon': Icons.trending_up_rounded},
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
      duration: const Duration(milliseconds: 400), // Reduced duration
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut, // Simplified curve
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1), // Reduced offset
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut, // Simplified curve
    ));
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMoreTeachers();
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
        _loadTeachers(),
        _loadFeaturedTeachers(),
        _loadStatistics(),
        _loadCategories(),
      ]);

      if (mounted) {
        // Start animation after build for better performance
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _animationController.forward();
          }
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

  Future<void> _loadTeachers() async {
    try {
      final teachers = await _apiService.getTeachers(
        page: _currentPage,
        category: _selectedCategory.isNotEmpty ? _selectedCategory : null,
        minRating: _minRating > 0 ? _minRating : null,
        onlineOnly: _onlineOnly,
        sortBy: _sortBy,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      if (mounted) {
        setState(() {
          if (_currentPage == 1) {
            _teachers = teachers;
          } else {
            _teachers.addAll(teachers);
          }
          _isLoading = false;
          _isLoadingMore = false;
          _hasMorePages = teachers.isNotEmpty;
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

  Future<void> _loadFeaturedTeachers() async {
    try {
      final featured = await _apiService.getFeaturedTeachers();
      if (mounted) {
        setState(() {
          _featuredTeachers = featured;
        });
      }
    } catch (e) {
      // Featured teachers loading error: $e
    }
  }

  Future<void> _loadStatistics() async {
    try {
      final stats = await _apiService.getTeacherStatistics();
      if (mounted) {
        setState(() {
          _statistics = stats;
        });
      }
    } catch (e) {
      // Statistics loading error: $e
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _apiService.getCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
        });
      }
    } catch (e) {
      // Categories loading error: $e
    }
  }

  Future<void> _loadMoreTeachers() async {
    if (_isLoadingMore || !_hasMorePages) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    _currentPage++;
    await _loadTeachers();
  }

  Future<void> _refreshData() async {
    _currentPage = 1;
    _hasMorePages = true;
    await _loadInitialData();
  }

  void _applyFilters() {
    _currentPage = 1;
    _hasMorePages = true;
    _loadTeachers();
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = '';
      _minPrice = 0;
      _maxPrice = 1000;
      _minRating = 0;
      _onlineOnly = false;
      _sortBy = 'rating';
      _searchQuery = '';
    });
    _applyFilters();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
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
          child: RefreshIndicator(
            onRefresh: _refreshData,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Statistics Banner
                if (_statistics.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildStatisticsBanner(),
                  ),
                
                // Search and Filters
                SliverToBoxAdapter(
                  child: _buildSearchAndFilters(),
                ),
                
                // Featured Teachers
                if (_featuredTeachers.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildFeaturedSection(),
                  ),
                
                // Results
                _isLoading
                    ? SliverFillRemaining(
                        child: CustomWidgets.customLoading(message: 'Öğretmenler yükleniyor...'),
                      )
                    : _error != null
                        ? SliverFillRemaining(
                            child: _buildErrorState(),
                          )
                        : _teachers.isEmpty
                            ? SliverFillRemaining(
                                child: _buildEmptyState(),
                              )
                            : _buildResultsSliver(),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Öğretmenler',
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
              label: 'Toplam Öğretmen',
              value: '${_statistics['total_teachers'] ?? 0}',
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          Expanded(
            child: _buildStatItem(
              icon: Icons.online_prediction_rounded,
              label: 'Online',
              value: '${_statistics['online_teachers'] ?? 0}',
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
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Öğretmen ara...',
                hintStyle: TextStyle(color: AppTheme.grey500),
                prefixIcon: Icon(Icons.search_rounded, color: AppTheme.grey500),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, color: AppTheme.grey500),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                          _applyFilters();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              onSubmitted: (value) {
                _applyFilters();
              },
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Filters Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'Kategori',
                  value: _selectedCategory.isNotEmpty ? _selectedCategory : 'Tümü',
                  onTap: _showCategoryFilter,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Fiyat',
                  value: '₺${_minPrice.toInt()}-₺${_maxPrice.toInt()}',
                  onTap: _showPriceFilter,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Puan',
                  value: _minRating > 0 ? '${_minRating.toStringAsFixed(1)}+' : 'Tümü',
                  onTap: _showRatingFilter,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Sırala',
                  value: _sortOptions.firstWhere((opt) => opt['value'] == _sortBy)['label'],
                  onTap: _showSortFilter,
                ),
                if (_onlineOnly || _selectedCategory.isNotEmpty || _minRating > 0 || _minPrice > 0 || _maxPrice < 1000)
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
        ],
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

  Widget _buildFeaturedSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '⭐ Öne Çıkan Öğretmenler',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = '';
                    _minRating = 4.0;
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
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _featuredTeachers.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 160,
                  margin: EdgeInsets.only(right: index == _featuredTeachers.length - 1 ? 0 : 12),
                  child: _buildFeaturedTeacherCard(_featuredTeachers[index]),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFeaturedTeacherCard(Teacher teacher) {
    return GestureDetector(
      onTap: () => _navigateToTeacherDetail(teacher),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Image
            Container(
              height: 100,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryBlue.withValues(alpha: 0.1),
                    AppTheme.primaryBlue.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.2),
                  child: Text(
                        (teacher.user?.name?.substring(0, 1).toUpperCase()) ?? '?',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
              ),
            ),
            
            // Teacher Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teacher.user?.name ?? 'İsimsiz',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      teacher.categories?.isNotEmpty == true 
                          ? teacher.categories!.first.name 
                          : 'Genel',
                      style: TextStyle(
                        color: AppTheme.grey600,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  teacher.ratingAvg?.toStringAsFixed(1) ?? '0.0',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: Text(
                            '₺${teacher.priceHour?.toInt() ?? 0}/sa',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryBlue,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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

  Widget _buildResultsSliver() {
    return _isGridView ? _buildGridSliver() : _buildListSliver();
  }


  Widget _buildListSliver() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= _teachers.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: index == _teachers.length - 1 ? 100 : 16,
            ),
            child: TeacherCard(
              teacher: _teachers[index],
              onTap: () => _navigateToTeacherDetail(_teachers[index]),
            ),
          );
        },
        childCount: _teachers.length + (_isLoadingMore ? 1 : 0),
      ),
    );
  }


  Widget _buildGridSliver() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.8,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index >= _teachers.length) {
              return const Center(child: CircularProgressIndicator());
            }
            
            return _buildGridTeacherCard(_teachers[index]);
          },
          childCount: _teachers.length + (_isLoadingMore ? 2 : 0),
        ),
      ),
    );
  }


  Widget _buildGridTeacherCard(Teacher teacher) {
    return GestureDetector(
      onTap: () => _navigateToTeacherDetail(teacher),
      child: Container(
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
            // Profile Image
            Container(
              height: 100,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryBlue.withValues(alpha: 0.1),
                    AppTheme.primaryBlue.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: CircleAvatar(
                  radius: 25,
                  backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.2),
                  child: Text(
                        (teacher.user?.name?.substring(0, 1).toUpperCase()) ?? '?',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
              ),
            ),
            
            // Teacher Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teacher.user?.name ?? 'İsimsiz',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      teacher.categories?.isNotEmpty == true 
                          ? teacher.categories!.first.name 
                          : 'Genel',
                      style: TextStyle(
                        color: AppTheme.grey600,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                            const SizedBox(width: 2),
                            Text(
                              teacher.ratingAvg?.toStringAsFixed(1) ?? '0.0',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '₺${teacher.priceHour?.toInt() ?? 0}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ],
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
              Icons.search_off_rounded,
              size: 64,
              color: AppTheme.grey400,
            ),
            const SizedBox(height: 16),
            Text(
              'Öğretmen bulunamadı',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Arama kriterlerinizi değiştirerek tekrar deneyin',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.grey600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear_rounded),
              label: const Text('Filtreleri Temizle'),
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
      onPressed: _showAdvancedFilters,
      backgroundColor: AppTheme.primaryBlue,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.tune_rounded),
      label: const Text('Gelişmiş Filtreler'),
    );
  }

  void _navigateToTeacherDetail(Teacher teacher) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeacherDetailScreen(teacher: teacher),
      ),
    );
  }

  void _showCategoryFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
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
                    'Kategori Seç',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedCategory = '';
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
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _selectedCategory == category.slug;
                  
                  return ListTile(
                    title: Text(category.name),
                    trailing: isSelected ? const Icon(Icons.check_rounded, color: AppTheme.primaryBlue) : null,
                    selected: isSelected,
                    onTap: () {
                      setState(() {
                        _selectedCategory = isSelected ? '' : category.slug;
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

  void _showPriceFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fiyat Aralığı'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('₺${_minPrice.toInt()} - ₺${_maxPrice.toInt()}'),
              RangeSlider(
                values: RangeValues(_minPrice, _maxPrice),
                min: 0,
                max: 1000,
                divisions: 100,
                onChanged: (values) {
                  setState(() {
                    _minPrice = values.start;
                    _maxPrice = values.end;
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              _applyFilters();
              Navigator.pop(context);
            },
            child: const Text('Uygula'),
          ),
        ],
      ),
    );
  }

  void _showRatingFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Minimum Puan'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${_minRating.toStringAsFixed(1)}+ Yıldız'),
              Slider(
                value: _minRating,
                min: 0,
                max: 5,
                divisions: 50,
                onChanged: (value) {
                  setState(() {
                    _minRating = value;
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _minRating = 0;
              });
              _applyFilters();
              Navigator.pop(context);
            },
            child: const Text('Temizle'),
          ),
          ElevatedButton(
            onPressed: () {
              _applyFilters();
              Navigator.pop(context);
            },
            child: const Text('Uygula'),
          ),
        ],
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

  void _showAdvancedFilters() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeacherFiltersScreen(
          selectedCategory: _selectedCategory,
          minPrice: _minPrice,
          maxPrice: _maxPrice,
          minRating: _minRating,
          onlineOnly: _onlineOnly,
          sortBy: _sortBy,
          onFiltersApplied: (filters) {
            setState(() {
              _selectedCategory = filters['category'] ?? '';
              _minPrice = filters['minPrice'] ?? 0;
              _maxPrice = filters['maxPrice'] ?? 1000;
              _minRating = filters['minRating'] ?? 0;
              _onlineOnly = filters['onlineOnly'] ?? false;
              _sortBy = filters['sortBy'] ?? 'rating';
            });
            _applyFilters();
          },
        ),
      ),
    );
  }
}
