import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_widgets.dart';
import '../../widgets/teacher_card.dart';
import '../../models/teacher.dart';
import '../../models/user.dart';
import '../../models/category.dart';
import 'advanced_search_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  List<Teacher> _teachers = [];
  List<Teacher> _filteredTeachers = [];
  bool _isLoading = false;
  bool _isGridView = false;
  String _selectedCategory = '';
  double _minPrice = 0;
  double _maxPrice = 1000;
  double _minRating = 0;
  bool _onlineOnly = false;
  String _sortBy = 'rating';

  final List<String> _categories = [
    'Matematik',
    'Fizik',
    'Kimya',
    'Biyoloji',
    'Türkçe',
    'İngilizce',
    'Tarih',
    'Coğrafya',
    'Felsefe',
    'Müzik',
    'Resim',
    'Spor',
    'Yazılım',
    'Tasarım',
    'Dans',
    'Sınava Hazırlık',
  ];

  final List<Map<String, dynamic>> _sortOptions = [
    {'value': 'rating', 'label': 'En Yüksek Puan'},
    {'value': 'price_low', 'label': 'En Düşük Fiyat'},
    {'value': 'price_high', 'label': 'En Yüksek Fiyat'},
    {'value': 'recent', 'label': 'En Yeni'},
    {'value': 'popular', 'label': 'En Popüler'},
  ];

  @override
  void initState() {
    super.initState();
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
    
    _animationController.forward();
    _loadTeachers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _loadTeachers() {
    setState(() {
      _isLoading = true;
    });
    
    // Simulate API call
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _teachers = _generateMockTeachers();
        _filteredTeachers = _teachers;
        _isLoading = false;
      });
    });
  }

  List<Teacher> _generateMockTeachers() {
    // Mock data generation
    return List.generate(20, (index) {
      return Teacher(
        userId: index + 1,
        id: index + 1,
        user: User(
          id: index + 1,
          name: 'Öğretmen ${index + 1}',
          email: 'teacher${index + 1}@example.com',
          role: 'teacher',
        ),
        bio: 'Deneyimli ${_categories[index % _categories.length]} öğretmeni',
        priceHour: 50.0 + (index * 10),
        ratingAvg: 3.5 + (index % 15) * 0.1,
        ratingCount: 10 + (index * 5),
        onlineAvailable: index % 3 == 0,
        categories: [
          Category(
            id: index + 1,
            name: _categories[index % _categories.length],
            slug: _categories[index % _categories.length].toLowerCase().replaceAll(' ', '-'),
          )
        ],
      );
    });
  }

  void _filterTeachers() {
    setState(() {
      _filteredTeachers = _teachers.where((teacher) {
        // Search filter
        if (_searchController.text.isNotEmpty) {
          final searchTerm = _searchController.text.toLowerCase();
          final userName = (teacher.user?.name ?? '').toLowerCase();
          final bioText = (teacher.bio ?? '').toLowerCase();
          if (!userName.contains(searchTerm) && !bioText.contains(searchTerm)) {
            return false;
          }
        }
        
        // Category filter
        if (_selectedCategory.isNotEmpty) {
          if (!(teacher.categories?.any((cat) => cat.name == _selectedCategory) ?? false)) {
            return false;
          }
        }
        
        // Price filter
        if ((teacher.priceHour ?? 0) < _minPrice || (teacher.priceHour ?? 0) > _maxPrice) {
          return false;
        }
        
        // Rating filter
        if (teacher.ratingAvg < _minRating) {
          return false;
        }
        
        // Online filter
        if (_onlineOnly && !teacher.onlineAvailable) {
          return false;
        }
        
        return true;
      }).toList();
      
      // Sort teachers
      _sortTeachers();
    });
  }

  void _sortTeachers() {
    switch (_sortBy) {
      case 'rating':
        _filteredTeachers.sort((a, b) => b.ratingAvg.compareTo(a.ratingAvg));
        break;
      case 'price_low':
        _filteredTeachers.sort((a, b) => (a.priceHour ?? 0).compareTo(b.priceHour ?? 0));
        break;
      case 'price_high':
        _filteredTeachers.sort((a, b) => (b.priceHour ?? 0).compareTo(a.priceHour ?? 0));
        break;
      case 'recent':
        _filteredTeachers.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
        break;
      case 'popular':
        _filteredTeachers.sort((a, b) => b.ratingCount.compareTo(a.ratingCount));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            children: [
              // Search and Filters
              _buildSearchAndFilters(),
              
              // Results
              Expanded(
                child: _isLoading
                    ? CustomWidgets.customLoading(message: 'Öğretmenler yükleniyor...')
                    : _filteredTeachers.isEmpty
                        ? _buildEmptyState()
                        : _buildResults(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Öğretmen Ara'),
      centerTitle: true,
      elevation: 0,
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

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: AppTheme.grey200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search Bar
          CustomWidgets.customTextField(
            label: 'Öğretmen ara',
            hintText: 'İsim, konu veya beceri ara',
            controller: _searchController,
            prefixIcon: const Icon(Icons.search_rounded),
          ),
          
          const SizedBox(height: 16),
          
          // Quick Filters
          _buildQuickFilters(),
          
          const SizedBox(height: 16),
          
          // Advanced Filters Button
          _buildAdvancedFiltersButton(),
        ],
      ),
    );
  }

  Widget _buildQuickFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(
            'Tümü',
            _selectedCategory.isEmpty,
            () {
              setState(() {
                _selectedCategory = '';
              });
              _filterTeachers();
            },
          ),
          const SizedBox(width: 8),
          ..._categories.take(6).map((category) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildFilterChip(
                category,
                _selectedCategory == category,
                () {
                  setState(() {
                    _selectedCategory = _selectedCategory == category ? '' : category;
                  });
                  _filterTeachers();
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue : AppTheme.grey100,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? null
              : Border.all(color: AppTheme.grey300),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.grey700,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildAdvancedFiltersButton() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _showAdvancedFilters,
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('Gelişmiş Filtreler'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppTheme.grey300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: _showSortOptions,
          icon: const Icon(Icons.sort_rounded, size: 18),
          label: Text(_sortOptions.firstWhere((option) => option['value'] == _sortBy)['label']),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppTheme.grey300),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildResults() {
    return Column(
      children: [
        // Results Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_filteredTeachers.length} öğretmen bulundu',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.grey700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _selectedCategory = '';
                    _minPrice = 0;
                    _maxPrice = 1000;
                    _minRating = 0;
                    _onlineOnly = false;
                    _sortBy = 'rating';
                  });
                  _filterTeachers();
                },
                child: Text(
                  'Temizle',
                  style: TextStyle(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Teachers List/Grid
        Expanded(
          child: _isGridView
              ? _buildGridView()
              : _buildListView(),
        ),
      ],
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredTeachers.length,
      itemBuilder: (context, index) {
        final teacher = _filteredTeachers[index];
        return TeacherCard(
          teacher: teacher,
          onTap: () {
            HapticFeedback.lightImpact();
            // TODO: Navigate to teacher profile
          },
          onFavoriteToggle: () {
            HapticFeedback.lightImpact();
            // TODO: Toggle favorite
          },
        );
      },
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _filteredTeachers.length,
      itemBuilder: (context, index) {
        final teacher = _filteredTeachers[index];
        return TeacherGridCard(
          teacher: teacher,
          onTap: () {
            HapticFeedback.lightImpact();
            // TODO: Navigate to teacher profile
          },
          onFavoriteToggle: () {
            HapticFeedback.lightImpact();
            // TODO: Toggle favorite
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'Öğretmen bulunamadı',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Arama kriterlerinizi değiştirerek tekrar deneyin',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _selectedCategory = '';
                  _minPrice = 0;
                  _maxPrice = 1000;
                  _minRating = 0;
                  _onlineOnly = false;
                });
                _filterTeachers();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Filtreleri Temizle'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAdvancedFilters() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdvancedSearchScreen()),
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.grey300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                Text(
                  'Sıralama Seçenekleri',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.grey900,
                  ),
                ),
                const SizedBox(height: 24),
                
                ..._sortOptions.map((option) {
                  final isSelected = _sortBy == option['value'];
                  return ListTile(
                    title: Text(
                      option['label'],
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? AppTheme.primaryBlue : AppTheme.grey900,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_rounded,
                            color: AppTheme.primaryBlue,
                          )
                        : null,
                    onTap: () {
                      setState(() {
                        _sortBy = option['value'];
                      });
                      _filterTeachers();
                      Navigator.pop(context);
                      HapticFeedback.lightImpact();
                    },
                  );
                }),
                
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}