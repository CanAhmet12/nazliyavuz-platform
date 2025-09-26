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
          // Sadece ana kategorileri göster
          _categories = categories.where((cat) => cat.parentId == null).toList();
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
      backgroundColor: const Color(0xFFF8FAFC),
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
                // Enhanced App Bar
                _buildSliverAppBar(),
                
                // Quick Stats Cards
                if (_statistics.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildQuickStatsCards(),
                  ),
                
                // Enhanced Search Section
                SliverToBoxAdapter(
                  child: _buildEnhancedSearchSection(),
                ),
                
                // Category Filter Chips
                SliverToBoxAdapter(
                  child: _buildCategoryChips(),
                ),
                
                // Featured Teachers Carousel
                if (_featuredTeachers.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildFeaturedTeachersCarousel(),
                  ),
                
                // Sort and View Toggle
                SliverToBoxAdapter(
                  child: _buildSortAndViewToggle(),
                ),
                
                // Enhanced Results
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
                            : _buildEnhancedResultsSliver(),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _buildEnhancedFloatingActionButton(),
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
            color: Colors.white.withOpacity( 0.8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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


  Widget _buildFeaturedTeacherCard(Teacher teacher) {
    return GestureDetector(
      onTap: () => _navigateToTeacherDetail(teacher),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity( 0.1),
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
                    AppTheme.primaryBlue.withOpacity( 0.1),
                    AppTheme.primaryBlue.withOpacity( 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.primaryBlue.withOpacity( 0.2),
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



  // Enhanced UI Components
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Öğretmenler',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryBlue.withOpacity( 0.1),
                AppTheme.accentGreen.withOpacity( 0.1),
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(_isGridView ? Icons.view_list : Icons.view_module),
          onPressed: () {
            setState(() {
              _isGridView = !_isGridView;
            });
            HapticFeedback.lightImpact();
          },
          tooltip: _isGridView ? 'Liste Görünümü' : 'Izgara Görünümü',
        ),
        IconButton(
          icon: const Icon(Icons.tune),
          onPressed: _showAdvancedFilters,
          tooltip: 'Filtreler',
        ),
      ],
    );
  }

  Widget _buildQuickStatsCards() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Toplam Öğretmen',
              _statistics['total_teachers']?.toString() ?? '0',
              Icons.school,
              AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Online Öğretmen',
              _statistics['online_teachers']?.toString() ?? '0',
              Icons.online_prediction,
              AppTheme.accentGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Ortalama Puan',
              _statistics['average_rating']?.toString() ?? '0.0',
              Icons.star,
              AppTheme.premiumGold,
            ),
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity( 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity( 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedSearchSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity( 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Öğretmen ara...',
            prefixIcon: Icon(
              Icons.search_rounded,
              color: AppTheme.primaryBlue,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                      _applyFilters();
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.grey[50],
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
    );
  }

  Widget _buildCategoryChips() {
    if (_categories.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildCategoryChip(
              'Tümü',
              '',
              _selectedCategory.isEmpty,
            );
          }

          final category = _categories[index - 1];
          return _buildCategoryChip(
            category.name,
            category.slug,
            _selectedCategory == category.slug,
          );
        },
      ),
    );
  }

  Widget _buildCategoryChip(String label, String value, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedCategory = selected ? value : '';
            _currentPage = 1;
          });
          _loadTeachers();
        },
        backgroundColor: Colors.white,
        selectedColor: AppTheme.primaryBlue.withOpacity( 0.1),
        checkmarkColor: AppTheme.primaryBlue,
        labelStyle: TextStyle(
          color: isSelected ? AppTheme.primaryBlue : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        side: BorderSide(
          color: isSelected ? AppTheme.primaryBlue : Colors.grey[300]!,
        ),
      ),
    );
  }

  Widget _buildFeaturedTeachersCarousel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.star_rounded,
                color: AppTheme.premiumGold,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Öne Çıkan Öğretmenler',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _featuredTeachers.length,
            itemBuilder: (context, index) {
              return _buildFeaturedTeacherCard(_featuredTeachers[index]);
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }


  Widget _buildSortAndViewToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_teachers.length} öğretmen bulundu',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              // Sort Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sortBy,
                    isDense: true,
                    items: _sortOptions.map((option) {
                      return DropdownMenuItem<String>(
                        value: option['value'],
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              option['icon'],
                              size: 16,
                              color: AppTheme.primaryBlue,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              option['label'],
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _sortBy = value;
                          _currentPage = 1;
                        });
                        _loadTeachers();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              
              // View Toggle
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    _buildViewToggleButton(
                      Icons.view_list,
                      !_isGridView,
                      () => setState(() => _isGridView = false),
                    ),
                    _buildViewToggleButton(
                      Icons.view_module,
                      _isGridView,
                      () => setState(() => _isGridView = true),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggleButton(IconData icon, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue.withOpacity( 0.1) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isSelected ? AppTheme.primaryBlue : Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildEnhancedResultsSliver() {
    return _isGridView ? _buildEnhancedGridSliver() : _buildEnhancedListSliver();
  }

  Widget _buildEnhancedListSliver() {
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
              bottom: index == _teachers.length - 1 ? 100 : 8,
            ),
            child: RepaintBoundary(
              child: _buildEnhancedTeacherCard(_teachers[index]),
            ),
          );
        },
        childCount: _teachers.length + (_isLoadingMore ? 1 : 0),
      ),
    );
  }

  Widget _buildEnhancedGridSliver() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index >= _teachers.length) {
              return const Center(child: CircularProgressIndicator());
            }
            
            return RepaintBoundary(
              child: _buildEnhancedGridTeacherCard(_teachers[index]),
            );
          },
          childCount: _teachers.length + (_isLoadingMore ? 2 : 0),
        ),
      ),
    );
  }

  Widget _buildEnhancedTeacherCard(Teacher teacher) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _navigateToTeacherDetail(teacher),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Profile Image
              Stack(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppTheme.primaryBlue.withOpacity( 0.1),
                    backgroundImage: teacher.user?.profilePhotoUrl != null
                        ? NetworkImage(teacher.user!.profilePhotoUrl!)
                        : null,
                    child: teacher.user?.profilePhotoUrl == null
                        ? Text(
                            (teacher.user?.name?.isNotEmpty == true ? teacher.user!.name[0].toUpperCase() : '?'),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryBlue,
                            ),
                          )
                        : null,
                  ),
                  if (teacher.onlineAvailable)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppTheme.accentGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              
              // Teacher Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teacher.user?.name ?? 'İsimsiz Öğretmen',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (teacher.bio?.isNotEmpty == true)
                      Text(
                        teacher.bio!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    
                    // Rating and Categories
                    Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: AppTheme.premiumGold,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          teacher.ratingAvg.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${teacher.ratingCount} değerlendirme)',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    
                    // Categories
                    if (teacher.categories?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        children: teacher.categories!.take(2).map((category) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withOpacity( 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              category.name,
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.primaryBlue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Price and Action
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${teacher.priceHour?.toInt() ?? 0}₺',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const Text(
                    '/saat',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Detay',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedGridTeacherCard(Teacher teacher) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _navigateToTeacherDetail(teacher),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with image
            Container(
              height: 80,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryBlue.withOpacity( 0.7),
                    AppTheme.accentGreen.withOpacity( 0.7),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.white,
                      backgroundImage: teacher.user?.profilePhotoUrl != null
                          ? NetworkImage(teacher.user!.profilePhotoUrl!)
                          : null,
                      child: teacher.user?.profilePhotoUrl == null
                          ? Text(
                              (teacher.user?.name?.isNotEmpty == true ? teacher.user!.name[0].toUpperCase() : '?'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlue,
                              ),
                            )
                          : null,
                    ),
                  ),
                  if (teacher.onlineAvailable)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppTheme.accentGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teacher.user?.name ?? 'İsimsiz Öğretmen',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    
                    // Rating
                    Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: AppTheme.premiumGold,
                          size: 14,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          teacher.ratingAvg.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    
                    const Spacer(),
                    
                    // Price
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${teacher.priceHour?.toInt() ?? 0}₺/saat',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: Colors.grey[400],
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

  Widget _buildEnhancedFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: _showAdvancedFilters,
      backgroundColor: AppTheme.primaryBlue,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.tune),
      label: const Text('Filtrele'),
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
              color: Colors.black.withOpacity( 0.08),
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
                    AppTheme.primaryBlue.withOpacity( 0.1),
                    AppTheme.primaryBlue.withOpacity( 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: CircleAvatar(
                  radius: 25,
                  backgroundColor: AppTheme.primaryBlue.withOpacity( 0.2),
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
              color: AppTheme.errorColor.withOpacity( 0.5),
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
