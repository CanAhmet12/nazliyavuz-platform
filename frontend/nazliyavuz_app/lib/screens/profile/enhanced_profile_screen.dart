import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../main.dart';
import 'profile_edit_screen.dart';
import 'password_change_screen.dart';
import 'notification_preferences_screen.dart';
import 'activity_history_screen.dart';
import 'account_settings_screen.dart';

class EnhancedProfileScreen extends StatefulWidget {
  const EnhancedProfileScreen({super.key});

  @override
  State<EnhancedProfileScreen> createState() => _EnhancedProfileScreenState();
}

class _EnhancedProfileScreenState extends State<EnhancedProfileScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  Map<String, dynamic> _userProfile = {};
  Map<String, dynamic> _statistics = {};
  Map<String, dynamic> _notificationPreferences = {};
  
  bool _isLoading = true;
  bool _isUpdatingPhoto = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadInitialData();
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

  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Paralel olarak veri yükle
      await Future.wait([
        _loadUserProfile(),
        _loadStatistics(),
        _loadNotificationPreferences(),
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

  Future<void> _loadUserProfile() async {
    try {
      final profile = await _apiService.getUserProfile();
      if (mounted) {
        setState(() {
          _userProfile = profile;
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

  Future<void> _loadStatistics() async {
    try {
      final stats = await _apiService.getUserStatistics();
      if (mounted) {
        setState(() {
          _statistics = stats;
        });
      }
    } catch (e) {
      print('Statistics loading error: $e');
    }
  }

  Future<void> _loadNotificationPreferences() async {
    try {
      final preferences = await _apiService.getNotificationPreferences();
      if (mounted) {
        setState(() {
          _notificationPreferences = preferences;
        });
      }
    } catch (e) {
      print('Notification preferences loading error: $e');
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      setState(() => _isUpdatingPhoto = true);
      
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      
      if (image != null) {
        // Burada gerçek upload implementasyonu yapılacak
        // Şimdilik mock data
        setState(() {
          _userProfile['profile_photo_url'] = image.path;
        });
        
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Profil fotoğrafı güncellendi!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingPhoto = false);
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RepaintBoundary(
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: RefreshIndicator(
                      onRefresh: _loadInitialData,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          // Enhanced Profile Header
                          _buildEnhancedSliverAppBar(),
                          
                          // Content
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  // Enhanced Statistics Cards
                                  if (_statistics.isNotEmpty) _buildEnhancedStatisticsSection(),
                                  
                                  const SizedBox(height: 24),
                                  
                                  // Enhanced Quick Actions
                                  _buildEnhancedQuickActions(),
                                  
                                  const SizedBox(height: 24),
                                  
                                  // Enhanced Profile Sections
                                  _buildEnhancedProfileSections(),
                                  
                                  const SizedBox(height: 24),
                                  
                                  // Enhanced Settings Sections
                                  _buildEnhancedSettingsSections(),
                                  
                                  const SizedBox(height: 24),
                                  
                                  // Enhanced Danger Zone
                                  _buildEnhancedDangerZone(),
                                  
                                  const SizedBox(height: 32),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Profil',
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
          icon: const Icon(Icons.edit_rounded),
          onPressed: () => _navigateToEditProfile(),
        ),
      ],
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBlue,
            AppTheme.primaryBlue.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Profile Photo
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: _userProfile['profile_photo_url'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(50),
                        child: Image.network(
                          _userProfile['profile_photo_url'],
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.person_rounded,
                              size: 50,
                              color: Colors.white,
                            );
                          },
                        ),
                      )
                    : const Icon(
                        Icons.person_rounded,
                        size: 50,
                        color: Colors.white,
                      ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _isUpdatingPhoto ? null : _pickAndUploadPhoto,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _isUpdatingPhoto
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.camera_alt_rounded,
                            size: 16,
                            color: AppTheme.primaryBlue,
                          ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // User Info
          Text(
            _userProfile['name'] ?? 'İsimsiz',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _userProfile['email'] ?? '',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getRoleText(_userProfile['role']),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          
          // Email Verification Status
          if (_userProfile['email_verified_at'] == null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_rounded, size: 16, color: Colors.orange),
                  const SizedBox(width: 4),
                  const Text(
                    'E-posta doğrulanmamış',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatisticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'İstatistikler',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildStatCard(
              icon: Icons.school_rounded,
              title: 'Toplam Ders',
              value: '${_statistics['total_reservations'] ?? 0}',
              color: AppTheme.primaryBlue,
            ),
            _buildStatCard(
              icon: Icons.check_circle_rounded,
              title: 'Tamamlanan',
              value: '${_statistics['completed_lessons'] ?? 0}',
              color: Colors.green,
            ),
            _buildStatCard(
              icon: Icons.timer_rounded,
              title: 'Toplam Süre',
              value: '${(_statistics['total_duration'] ?? 0) ~/ 60}sa',
              color: Colors.orange,
            ),
            _buildStatCard(
              icon: Icons.star_rounded,
              title: 'Ortalama Puan',
              value: '${(_statistics['average_rating'] ?? 0).toStringAsFixed(1)}',
              color: Colors.amber,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
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
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.grey600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hızlı İşlemler',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.edit_rounded,
                title: 'Profili Düzenle',
                color: AppTheme.primaryBlue,
                onTap: () => _navigateToEditProfile(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.lock_rounded,
                title: 'Şifre Değiştir',
                color: Colors.orange,
                onTap: () => _navigateToPasswordChange(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSections() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Profil Bilgileri',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          children: [
            _buildSectionItem(
              icon: Icons.person_rounded,
              title: 'Kişisel Bilgiler',
              subtitle: 'Ad, e-posta ve iletişim bilgileri',
              onTap: () => _navigateToEditProfile(),
            ),
            _buildDivider(),
            _buildSectionItem(
              icon: Icons.school_rounded,
              title: 'Eğitim Bilgileri',
              subtitle: 'Uzmanlık alanları ve sertifikalar',
              onTap: () => _navigateToEditProfile(),
            ),
            if (_userProfile['role'] == 'teacher') ...[
              _buildDivider(),
              _buildSectionItem(
                icon: Icons.work_rounded,
                title: 'Öğretmen Profili',
                subtitle: 'Bio, fiyat ve müsaitlik bilgileri',
                onTap: () => _navigateToEditProfile(),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildSettingsSections() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ayarlar',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          children: [
            _buildSectionItem(
              icon: Icons.notifications_rounded,
              title: 'Bildirim Tercihleri',
              subtitle: 'E-posta ve push bildirim ayarları',
              onTap: () => _navigateToNotificationPreferences(),
            ),
            _buildDivider(),
            _buildSectionItem(
              icon: Icons.history_rounded,
              title: 'Aktivite Geçmişi',
              subtitle: 'Hesap aktivitelerini görüntüle',
              onTap: () => _navigateToActivityHistory(),
            ),
            _buildDivider(),
            _buildSectionItem(
              icon: Icons.security_rounded,
              title: 'Güvenlik Ayarları',
              subtitle: 'Şifre ve güvenlik tercihleri',
              onTap: () => _navigateToAccountSettings(),
            ),
            _buildDivider(),
            _buildSectionItem(
              icon: Icons.download_rounded,
              title: 'Verilerimi İndir',
              subtitle: 'Hesap verilerini dışa aktar',
              onTap: _exportUserData,
            ),
          ],
        ),
      ],
    );
  }

  // Enhanced Profile Components
  Widget _buildEnhancedSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryBlue.withValues(alpha: 0.8),
                AppTheme.accentGreen.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                
                // Profile Photo
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white,
                      backgroundImage: _userProfile['profile_photo_url'] != null
                          ? NetworkImage(_userProfile['profile_photo_url'])
                          : null,
                      child: _userProfile['profile_photo_url'] == null
                          ? Text(
                              _userProfile['name']?.isNotEmpty == true
                                  ? _userProfile['name'][0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlue,
                              ),
                            )
                          : null,
                    ),
                    
                    // Edit Photo Button
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickAndUploadPhoto,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: _isUpdatingPhoto
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt,
                                  size: 16,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // User Info
                Text(
                  _userProfile['name'] ?? 'İsimsiz Kullanıcı',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                
                const SizedBox(height: 4),
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getUserRoleText(_userProfile['role'] ?? 'student'),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: _navigateToEditProfile,
          tooltip: 'Profil Düzenle',
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: _navigateToAccountSettings,
          tooltip: 'Ayarlar',
        ),
      ],
    );
  }

  Widget _buildEnhancedStatisticsSection() {
    final stats = [
      {
        'title': 'Toplam Ders',
        'value': _statistics['total_lessons']?.toString() ?? '0',
        'icon': Icons.school,
        'color': AppTheme.primaryBlue,
      },
      {
        'title': 'Tamamlanan',
        'value': _statistics['completed_lessons']?.toString() ?? '0',
        'icon': Icons.check_circle,
        'color': AppTheme.accentGreen,
      },
      {
        'title': 'Ortalama Puan',
        'value': _statistics['average_rating']?.toString() ?? '0.0',
        'icon': Icons.star,
        'color': AppTheme.premiumGold,
      },
      {
        'title': 'Bu Ay',
        'value': _statistics['monthly_lessons']?.toString() ?? '0',
        'icon': Icons.calendar_today,
        'color': AppTheme.accentOrange,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'İstatistikler',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemCount: stats.length,
          itemBuilder: (context, index) {
            final stat = stats[index];
            return _buildEnhancedStatCard(
              stat['title'] as String,
              stat['value'] as String,
              stat['icon'] as IconData,
              stat['color'] as Color,
            );
          },
        ),
      ],
    );
  }

  Widget _buildEnhancedStatCard(String title, String value, IconData icon, Color color) {
    return Container(
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
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
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedQuickActions() {
    final actions = [
      {
        'title': 'Profil Düzenle',
        'subtitle': 'Kişisel bilgilerinizi güncelleyin',
        'icon': Icons.edit_rounded,
        'color': AppTheme.primaryBlue,
        'onTap': _navigateToEditProfile,
      },
      {
        'title': 'Şifre Değiştir',
        'subtitle': 'Hesap güvenliğinizi artırın',
        'icon': Icons.lock_rounded,
        'color': AppTheme.accentOrange,
        'onTap': _navigateToPasswordChange,
      },
      {
        'title': 'Etkinlik Geçmişi',
        'subtitle': 'Geçmiş aktivitelerinizi görün',
        'icon': Icons.history_rounded,
        'color': AppTheme.accentGreen,
        'onTap': _navigateToActivityHistory,
      },
      {
        'title': 'Bildirim Ayarları',
        'subtitle': 'Bildirimleri özelleştirin',
        'icon': Icons.notifications_rounded,
        'color': AppTheme.premiumGold,
        'onTap': _navigateToNotificationPreferences,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hızlı İşlemler',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final action = actions[index];
            return _buildEnhancedActionCard(action);
          },
        ),
      ],
    );
  }

  Widget _buildEnhancedActionCard(Map<String, dynamic> action) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: action['onTap'],
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: action['color'].withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  action['icon'],
                  color: action['color'],
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                action['title'],
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                action['subtitle'],
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedProfileSections() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.person_rounded,
                  color: AppTheme.primaryBlue,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Profil Bilgileri',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          _buildEnhancedSectionItem(
            icon: Icons.email_rounded,
            title: 'E-posta Adresi',
            subtitle: _userProfile['email'] ?? 'Belirtilmemiş',
            trailing: _userProfile['email_verified_at'] != null
                ? Icon(Icons.verified, color: AppTheme.accentGreen, size: 20)
                : Icon(Icons.warning, color: AppTheme.accentOrange, size: 20),
            onTap: _navigateToEditProfile,
          ),
          _buildDivider(),
          _buildEnhancedSectionItem(
            icon: Icons.phone_rounded,
            title: 'Telefon Numarası',
            subtitle: _userProfile['phone'] ?? 'Eklenmemiş',
            onTap: _navigateToEditProfile,
          ),
          _buildDivider(),
          _buildEnhancedSectionItem(
            icon: Icons.location_on_rounded,
            title: 'Konum',
            subtitle: _userProfile['location'] ?? 'Belirtilmemiş',
            onTap: _navigateToEditProfile,
          ),
          if (_userProfile['role'] == 'teacher') ...[
            _buildDivider(),
            _buildEnhancedSectionItem(
              icon: Icons.school_rounded,
              title: 'Öğretmen Profili',
              subtitle: 'Uzmanlık alanları ve deneyim',
              onTap: _navigateToEditProfile,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEnhancedSectionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: AppTheme.primaryBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
            if (onTap != null)
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedSettingsSections() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.settings_rounded,
                  color: AppTheme.primaryBlue,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Ayarlar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          _buildEnhancedSectionItem(
            icon: Icons.notifications_rounded,
            title: 'Bildirim Ayarları',
            subtitle: 'Push bildirimler ve e-posta tercihleri',
            onTap: _navigateToNotificationPreferences,
          ),
          _buildDivider(),
          _buildEnhancedSectionItem(
            icon: Icons.security_rounded,
            title: 'Güvenlik',
            subtitle: 'Şifre değiştir ve iki faktörlü doğrulama',
            onTap: _navigateToPasswordChange,
          ),
          _buildDivider(),
          _buildEnhancedSectionItem(
            icon: Icons.privacy_tip_rounded,
            title: 'Gizlilik',
            subtitle: 'Veri kullanımı ve gizlilik ayarları',
            onTap: _navigateToAccountSettings,
          ),
          _buildDivider(),
          _buildEnhancedSectionItem(
            icon: Icons.help_rounded,
            title: 'Yardım ve Destek',
            subtitle: 'SSS, iletişim ve geri bildirim',
            onTap: () {
              // TODO: Navigate to help screen
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedDangerZone() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.warning_rounded,
                  color: AppTheme.accentRed,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Tehlikeli İşlemler',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          _buildEnhancedSectionItem(
            icon: Icons.logout_rounded,
            title: 'Çıkış Yap',
            subtitle: 'Hesabınızdan güvenli şekilde çıkış yapın',
            onTap: _logout,
          ),
          _buildDivider(),
          _buildEnhancedSectionItem(
            icon: Icons.delete_forever_rounded,
            title: 'Hesabı Sil',
            subtitle: 'Hesabınızı kalıcı olarak silin',
            onTap: _deleteAccount,
          ),
        ],
      ),
    );
  }

  String _getUserRoleText(String role) {
    switch (role) {
      case 'student':
        return 'Öğrenci';
      case 'teacher':
        return 'Öğretmen';
      case 'admin':
        return 'Yönetici';
      default:
        return 'Kullanıcı';
    }
  }

  Widget _buildDangerZone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tehlikeli Bölge',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.errorColor,
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          color: AppTheme.errorColor.withValues(alpha: 0.1),
          borderColor: AppTheme.errorColor.withValues(alpha: 0.3),
          children: [
            _buildSectionItem(
              icon: Icons.delete_forever_rounded,
              title: 'Hesabı Sil',
              subtitle: 'Hesabınızı kalıcı olarak silin',
              iconColor: AppTheme.errorColor,
              textColor: AppTheme.errorColor,
              onTap: _showDeleteAccountDialog,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required List<Widget> children,
    Color? color,
    Color? borderColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor ?? AppTheme.grey300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSectionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? AppTheme.primaryBlue,
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textColor ?? AppTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 14,
          color: AppTheme.grey600,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16,
        color: AppTheme.grey400,
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppTheme.grey200,
      indent: 56,
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
              onPressed: _loadInitialData,
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

  String _getRoleText(String? role) {
    switch (role) {
      case 'student':
        return 'Öğrenci';
      case 'teacher':
        return 'Öğretmen';
      case 'admin':
        return 'Yönetici';
      default:
        return 'Kullanıcı';
    }
  }

  void _navigateToEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileEditScreen(userProfile: _userProfile),
      ),
    ).then((_) => _loadInitialData());
  }

  void _navigateToPasswordChange() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PasswordChangeScreen(),
      ),
    );
  }

  void _navigateToNotificationPreferences() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotificationPreferencesScreen(preferences: _notificationPreferences),
      ),
    ).then((_) => _loadNotificationPreferences());
  }

  void _navigateToActivityHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ActivityHistoryScreen(),
      ),
    );
  }

  void _navigateToAccountSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AccountSettingsScreen(),
      ),
    );
  }

  void _exportUserData() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      await _apiService.exportUserData();
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verileriniz hazırlandı!'),
            backgroundColor: Colors.green,
          ),
        );
        // Burada dosya indirme işlemi yapılacak
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Çıkış Yap'),
        content: const Text('Hesabınızdan çıkış yapmak istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // AuthBloc'a logout event'i gönder
              context.read<AuthBloc>().add(const AuthLogout());
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.accentRed,
            ),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
  }

  void _deleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.warning_rounded,
              color: AppTheme.accentRed,
            ),
            const SizedBox(width: 8),
            const Text('Hesabı Sil'),
          ],
        ),
        content: const Text(
          'Hesabınızı silmek istediğinizden emin misiniz? Bu işlem geri alınamaz ve tüm verileriniz silinecektir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Show loading dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  content: Row(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(width: 20),
                      const Text('Hesap siliniyor...'),
                    ],
                  ),
                ),
              );
              
              try {
                await _apiService.deleteUserAccount(
                  password: 'user_confirmation', // Bu gerçek uygulamada kullanıcıdan alınmalı
                  confirmation: 'DELETE_MY_ACCOUNT',
                );
                if (mounted) {
                  Navigator.pop(context); // Loading dialog'u kapat
                  context.read<AuthBloc>().add(const AuthLogout());
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context); // Loading dialog'u kapat
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Hata: $e'),
                      backgroundColor: AppTheme.accentRed,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.accentRed,
            ),
            child: const Text('Hesabı Sil'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hesabı Sil'),
        content: const Text(
          'Bu işlem geri alınamaz. Tüm verileriniz kalıcı olarak silinecektir. Emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToAccountSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}
