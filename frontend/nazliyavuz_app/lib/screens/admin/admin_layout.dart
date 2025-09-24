import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../theme/app_theme.dart';
import 'admin_dashboard_screen.dart';
import 'admin_teacher_approval_screen.dart';
import 'admin_user_management_screen.dart';
import 'admin_analytics_screen.dart';
import '../analytics/advanced_analytics_screen.dart';

class AdminLayout extends StatefulWidget {
  final User user;

  const AdminLayout({super.key, required this.user});

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  int _currentIndex = 0;
  bool _isSidebarExpanded = true;

  final List<AdminMenuItem> _menuItems = [
    AdminMenuItem(
      title: 'Dashboard',
      icon: Icons.dashboard,
      screen: AdminDashboardScreen(),
    ),
    AdminMenuItem(
      title: 'Öğretmen Onayları',
      icon: Icons.school,
      screen: AdminTeacherApprovalScreen(),
    ),
    AdminMenuItem(
      title: 'Kullanıcı Yönetimi',
      icon: Icons.people,
      screen: AdminUserManagementScreen(),
    ),
    AdminMenuItem(
      title: 'Analitikler',
      icon: Icons.analytics,
      screen: AdminAnalyticsScreen(),
    ),
    AdminMenuItem(
      title: 'Gelişmiş Analitikler',
      icon: Icons.bar_chart,
      screen: AdvancedAnalyticsScreen(),
    ),
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: AppTheme.premiumGold,
        foregroundColor: AppTheme.grey900,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            setState(() {
              _isSidebarExpanded = !_isSidebarExpanded;
            });
          },
        ),
        actions: [
          if (!isMobile)
            IconButton(
              icon: Icon(_isSidebarExpanded ? Icons.chevron_left : Icons.chevron_right),
              onPressed: () {
                setState(() {
                  _isSidebarExpanded = !_isSidebarExpanded;
                });
              },
            ),
        ],
      ),
      body: Row(
        children: [
          // Sidebar
          Container(
            width: isMobile 
                ? (_isSidebarExpanded ? screenWidth * 0.6 : 0)
                : (_isSidebarExpanded ? 220 : 60),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: _isSidebarExpanded || isMobile ? Column(
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(_isSidebarExpanded ? 20 : 12),
                  decoration: BoxDecoration(
                    gradient: AppTheme.premiumGradient,
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: _isSidebarExpanded ? 30 : 20,
                        backgroundColor: Colors.white,
                        child: Text(
                          widget.user.name.isNotEmpty 
                              ? widget.user.name[0].toUpperCase() 
                              : 'A',
                          style: TextStyle(
                            fontSize: _isSidebarExpanded ? 24 : 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      if (_isSidebarExpanded) ...[
                        const SizedBox(height: 12),
                        Text(
                          widget.user.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Admin',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Menu Items
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _menuItems.length,
                    itemBuilder: (context, index) {
                      final item = _menuItems[index];
                      final isSelected = _currentIndex == index;
                      
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        child: _isSidebarExpanded 
                            ? ListTile(
                                leading: Icon(
                                  item.icon,
                                  color: isSelected 
                                      ? AppTheme.premiumGold
                                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                                title: Text(
                                  item.title,
                                  style: TextStyle(
                                    color: isSelected 
                                        ? AppTheme.premiumGold
                                        : Theme.of(context).colorScheme.onSurface,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  ),
                                ),
                                selected: isSelected,
                                selectedTileColor: AppTheme.premiumGoldLight,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                onTap: () {
                                  setState(() {
                                    _currentIndex = index;
                                    if (isMobile) {
                                      _isSidebarExpanded = false;
                                    }
                                  });
                                  setState(() {
                                    _currentIndex = index;
                                  });
                                },
                              )
                            : Tooltip(
                                message: item.title,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Material(
                                    color: isSelected 
                                        ? AppTheme.premiumGoldLight
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () {
                                        setState(() {
                                          _currentIndex = index;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        child: Icon(
                                          item.icon,
                                          color: isSelected 
                                              ? AppTheme.premiumGold
                                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      );
                    },
                  ),
                ),
                
                // Footer
                if (_isSidebarExpanded) Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Divider(),
                      const SizedBox(height: 8),
                      ListTile(
                        leading: const Icon(Icons.settings),
                        title: const Text('Ayarlar'),
                        onTap: () {
                          // Settings functionality
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.logout),
                        title: const Text('Çıkış'),
                        onTap: () {
                          // Logout functionality
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ) : const SizedBox.shrink(),
          ),
          
          // Main Content
          Expanded(
            child: Stack(
              children: [
                IndexedStack(
                  index: _currentIndex,
                  children: _menuItems.map((item) => item.screen).toList(),
                ),
                
                // Mobile overlay
                if (isMobile && _isSidebarExpanded)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isSidebarExpanded = false;
                        });
                      },
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.5),
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
}

class AdminMenuItem {
  final String title;
  final IconData icon;
  final Widget screen;

  AdminMenuItem({
    required this.title,
    required this.icon,
    required this.screen,
  });
}
