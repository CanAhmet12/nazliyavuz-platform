import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import '../../main.dart';
import '../../models/user.dart';
import '../teachers/enhanced_teachers_screen.dart';
import '../reservations/enhanced_reservations_screen.dart';
import '../profile/enhanced_profile_screen.dart';
import '../notifications/notification_screen.dart';
import '../lessons/enhanced_lessons_screen.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_widgets.dart';
import '../chat/chat_list_screen.dart';
import '../assignments/teacher_assignments_screen.dart';

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200), // Reduced duration
      vsync: this,
    );
    _fabAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeOut, // Simplified curve
    ));
    
    // Start animation after build for better performance
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fabAnimationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! AuthAuthenticated) {
          return Scaffold(
            body: CustomWidgets.customLoading(
              message: 'Yükleniyor...',
            ),
          );
        }

        final user = state.user;

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: [
              RepaintBoundary(child: _buildTeacherHomeTab(user)),
              const RepaintBoundary(child: EnhancedTeachersScreen()),
              const RepaintBoundary(child: EnhancedLessonsScreen()),
              const RepaintBoundary(child: EnhancedReservationsScreen()),
              const RepaintBoundary(child: EnhancedProfileScreen()),
            ],
          ),
          bottomNavigationBar: _buildTeacherBottomNavigationBar(),
          floatingActionButton: _buildTeacherFloatingActionButton(),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        );
      },
    );
  }

  Widget _buildTeacherBottomNavigationBar() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity( 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: AppTheme.grey200,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(child: _buildNavItem(0, Icons.home_outlined, Icons.home, 'Ana Sayfa')),
              Expanded(child: _buildNavItem(1, Icons.school_outlined, Icons.school, 'Öğretmenler')),
              const SizedBox(width: 16), // Space for FAB
              Expanded(child: _buildNavItem(2, Icons.book_outlined, Icons.book, 'Dersler')),
              Expanded(child: _buildNavItem(3, Icons.calendar_today_outlined, Icons.calendar_today, 'Derslerim')),
              Expanded(child: _buildNavItem(4, Icons.person_outlined, Icons.person, 'Profil')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _currentIndex == index;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
        HapticFeedback.lightImpact();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue.withOpacity( 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? Colors.white : AppTheme.grey500,
                size: 18,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.primaryBlue : AppTheme.grey500,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherFloatingActionButton() {
    return AnimatedBuilder(
      animation: _fabAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _fabAnimation.value,
          child: FloatingActionButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              _showTeacherQuickActions(context);
            },
            backgroundColor: AppTheme.premiumGold,
            foregroundColor: AppTheme.grey900,
            elevation: 12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.add_rounded,
              size: 28,
            ),
          ),
        );
      },
    );
  }

  void _showTeacherQuickActions(BuildContext context) {
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
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.grey300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                
                Text(
                  'Öğretmen İşlemleri',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.grey900,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Quick Actions Grid
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _buildQuickActionCard(
                      context,
                      icon: Icons.calendar_today_rounded,
                      title: 'Ders Ekle',
                      subtitle: 'Yeni ders planla',
                      color: AppTheme.accentGreen,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EnhancedReservationsScreen(),
                          ),
                        );
                      },
                    ),
                    _buildQuickActionCard(
                      context,
                      icon: Icons.chat_rounded,
                      title: 'Mesajlar',
                      subtitle: 'Öğrencilerle konuş',
                      color: AppTheme.accentPurple,
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Navigate to chat with proper user selection
                        // Navigator.push(
                        //   context,
                        //   MaterialPageRoute(
                        //     builder: (context) => const ChatScreen(),
                        //   ),
                        // );
                      },
                    ),
                    _buildQuickActionCard(
                      context,
                      icon: Icons.assignment_rounded,
                      title: 'Ödev Ver',
                      subtitle: 'Yeni ödev oluştur',
                      color: AppTheme.accentOrange,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TeacherAssignmentsScreen(),
                          ),
                        );
                      },
                    ),
                    _buildQuickActionCard(
                      context,
                      icon: Icons.analytics_rounded,
                      title: 'Raporlar',
                      subtitle: 'Performans analizi',
                      color: AppTheme.accentRed,
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Navigate to reports
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return CustomWidgets.customCard(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
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
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.grey900,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.grey600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherHomeTab(User user) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Custom App Bar
          _buildTeacherSliverAppBar(user),
          
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Section
                  _buildTeacherWelcomeSection(user),
                  
                  const SizedBox(height: 20),
                  
                  // Quick Actions Grid
                  _buildTeacherQuickActionsGrid(),
                  
                  const SizedBox(height: 20),
                  
                  // Teaching Stats
                  _buildTeachingStats(),
                  
                  const SizedBox(height: 20),
                  
                  // Today's Schedule
                  _buildTodaysSchedule(),
                  
                  const SizedBox(height: 20),
                  
                  // Recent Students
                  _buildRecentStudents(),
                  
                  const SizedBox(height: 100), // Bottom padding for FAB
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherSliverAppBar(User user) {
    return SliverAppBar(
      expandedHeight: 100,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.primaryBlue,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.premiumGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  // Profile Avatar
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity( 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: user.profilePhotoUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.network(
                              user.profilePhotoUrl!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(
                            Icons.person_rounded,
                            color: AppTheme.primaryBlue,
                            size: 20,
                          ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Welcome Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Merhaba Öğretmen,',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity( 0.8),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          user.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Action Buttons
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity( 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.notifications_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const NotificationScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity( 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.settings_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const EnhancedProfileScreen(),
                              ),
                            );
                          },
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

  Widget _buildTeacherWelcomeSection(User user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryBlue,
            AppTheme.accentPurple,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity( 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity( 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity( 0.3),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.school_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Merhaba, ${user.name}! 👨‍🏫',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Bugün kaç öğrenciye ders vereceksin?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity( 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.calendar_today_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EnhancedReservationsScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherQuickActionsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Öğretmen İşlemleri',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTeacherQuickActionCard(
                icon: Icons.calendar_today_rounded,
                title: 'Ders Takvimi',
                subtitle: 'Derslerimi görüntüle',
                color: const Color(0xFF3B82F6),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EnhancedReservationsScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTeacherQuickActionCard(
                icon: Icons.chat_rounded,
                title: 'Mesajlar',
                subtitle: 'Öğrencilerle konuş',
                color: const Color(0xFF10B981),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ChatListScreen(),
                          ),
                        );
                      },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTeacherQuickActionCard(
                icon: Icons.assignment_rounded,
                title: 'Ödev Ver',
                subtitle: 'Yeni ödev oluştur',
                color: const Color(0xFF8B5CF6),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TeacherAssignmentsScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTeacherQuickActionCard(
                icon: Icons.analytics_rounded,
                title: 'Raporlar',
                subtitle: 'Performans analizi',
                color: const Color(0xFFF59E0B),
                onTap: () {
                  // TODO: Navigate to reports
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTeacherQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity( 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
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
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeachingStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Öğretim İstatistikleri',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.28,
                child: _buildModernStatCard(
                  'Bugünkü Dersler',
                  '3',
                  Icons.today_rounded,
                  const Color(0xFF10B981),
                  'Saat 14:00',
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.28,
                child: _buildModernStatCard(
                  'Aktif Öğrenciler',
                  '12',
                  Icons.people_rounded,
                  const Color(0xFF3B82F6),
                  'Bu ay',
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.28,
                child: _buildModernStatCard(
                  'Toplam Ders',
                  '45',
                  Icons.school_rounded,
                  const Color(0xFF8B5CF6),
                  'Bu ay',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernStatCard(String label, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity( 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity( 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity( 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
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
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
              fontSize: 20,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTodaysSchedule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Bugünkü Program',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
                fontSize: 18,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EnhancedReservationsScreen(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity( 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Tümü',
                  style: TextStyle(
                    color: Color(0xFF3B82F6),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity( 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildModernActivityItem(
                'Matematik Dersi',
                'Ahmet Öğrenci',
                '14:00 - 15:00',
                Icons.calculate_rounded,
                const Color(0xFF3B82F6),
                'Yaklaşıyor',
                const Color(0xFFF59E0B),
              ),
              const SizedBox(height: 12),
              _buildModernActivityItem(
                'İngilizce Konuşma',
                'Ayşe Öğrenci',
                '16:00 - 17:00',
                Icons.chat_rounded,
                const Color(0xFF10B981),
                'Planlandı',
                const Color(0xFF3B82F6),
              ),
              const SizedBox(height: 12),
              _buildModernActivityItem(
                'Fizik Dersi',
                'Mehmet Öğrenci',
                '18:00 - 19:00',
                Icons.science_rounded,
                const Color(0xFF8B5CF6),
                'Planlandı',
                const Color(0xFF3B82F6),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernActivityItem(String title, String student, String time, IconData icon, Color iconColor, String status, Color statusColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withOpacity( 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  student,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity( 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                time,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentStudents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Son Öğrenciler',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
                fontSize: 18,
              ),
            ),
            GestureDetector(
              onTap: () {
                // TODO: Navigate to all students
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity( 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Tümü',
                  style: TextStyle(
                    color: Color(0xFF3B82F6),
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
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: 5,
            itemBuilder: (context, index) {
              return Container(
                width: 160,
                margin: EdgeInsets.only(right: index == 4 ? 0 : 16),
                child: _buildModernStudentCard(index),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildModernStudentCard(int index) {
    final colors = [
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFF8B5CF6),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
    ];
    
    final subjects = [
      'Matematik',
      'İngilizce',
      'Fizik',
      'Kimya',
      'Biyoloji',
    ];
    
    final students = [
      'Ahmet Yılmaz',
      'Ayşe Demir',
      'Mehmet Kaya',
      'Fatma Özkan',
      'Ali Çelik',
    ];
    
    final grades = ['9. Sınıf', '10. Sınıf', '11. Sınıf', '12. Sınıf', 'Lise'];
    final lessonCounts = [15, 12, 18, 8, 22];
    final progress = [85, 92, 78, 95, 88];
    
    final color = colors[index % colors.length];
    final subject = subjects[index % subjects.length];
    final student = students[index % students.length];
    final grade = grades[index % grades.length];
    final lessonCount = lessonCounts[index % lessonCounts.length];
    final studentProgress = progress[index % progress.length];
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        // TODO: Navigate to student detail
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced Header with gradient and pattern
            Container(
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color,
                    color.withOpacity( 0.8),
                    color.withOpacity( 0.6),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Stack(
                children: [
                  // Background Pattern
                  Positioned(
                    right: -30,
                    top: -30,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity( 0.1),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    left: -20,
                    bottom: -20,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity( 0.05),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  
                  // Student Avatar
                  Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity( 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        color: color,
                        size: 28,
                      ),
                    ),
                  ),
                  
                  // Grade Badge
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity( 0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        grade,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Enhanced Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and Subject
                  Text(
                    student,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subject,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Progress Bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'İlerleme',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            '%$studentProgress',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: color.withOpacity( 0.1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: studentProgress / 100,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [color, color.withOpacity( 0.8)],
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Stats Row
                  Row(
                    children: [
                      // Lesson Count
                      Expanded(
                        child: _buildQuickStat('$lessonCount', 'Ders', color),
                      ),
                      Expanded(
                        child: _buildQuickStat('%$studentProgress', 'Başarı', color),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildQuickStat(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity( 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
