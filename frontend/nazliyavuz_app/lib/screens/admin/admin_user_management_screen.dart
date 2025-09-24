import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/user.dart';

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() => _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  final ApiService _apiService = ApiService();
  List<User> _users = [];
  bool _isLoading = true;
  String? _error;
  String _selectedRole = 'all';
  String _selectedStatus = 'all';

  final List<Map<String, String>> _roleFilters = [
    {'value': 'all', 'label': 'Tümü'},
    {'value': 'student', 'label': 'Öğrenciler'},
    {'value': 'teacher', 'label': 'Öğretmenler'},
    {'value': 'admin', 'label': 'Adminler'},
  ];

  final List<Map<String, String>> _statusFilters = [
    {'value': 'all', 'label': 'Tümü'},
    {'value': 'active', 'label': 'Aktif'},
    {'value': 'inactive', 'label': 'Pasif'},
    {'value': 'pending', 'label': 'Beklemede'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final users = await _apiService.getAdminUsers(
        role: _selectedRole == 'all' ? null : _selectedRole,
        status: _selectedStatus == 'all' ? null : _selectedStatus,
      );
      if (mounted) {
        setState(() {
          _users = users;
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

  Future<void> _updateUserStatus(User user, String status) async {
    try {
      await _apiService.updateUserStatus(user.id, status);
      
      setState(() {
        final index = _users.indexWhere((u) => u.id == user.id);
        if (index != -1) {
          // Update user status locally
          _users[index] = user.copyWith(
            teacherStatus: status == 'approved' ? 'approved' : 
                          status == 'rejected' ? 'rejected' : 
                          user.teacherStatus,
          );
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name} durumu güncellendi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Güncelleme hatası: $e'),
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
        title: const Text('Kullanıcı Yönetimi'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtreler
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Rol Filtresi
                Row(
                  children: [
                    const Text('Rol:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _roleFilters.map((filter) {
                            final isSelected = _selectedRole == filter['value'];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(filter['label']!),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedRole = filter['value']!;
                                  });
                                  _loadUsers();
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Durum Filtresi
                Row(
                  children: [
                    const Text('Durum:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _statusFilters.map((filter) {
                            final isSelected = _selectedStatus == filter['value'];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(filter['label']!),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedStatus = filter['value']!;
                                  });
                                  _loadUsers();
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Kullanıcı Listesi
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Hata: $_error',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUsers,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Kullanıcı bulunamadı',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        return _buildUserCard(user);
      },
    );
  }

  Widget _buildUserCard(User user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: _getRoleColor(user.role),
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildRoleChip(user.role),
                          const SizedBox(width: 8),
                          _buildStatusChip(user),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => _updateUserStatus(user, value),
                  itemBuilder: (context) => [
                    if (user.role == 'teacher' && user.isTeacherPending)
                      const PopupMenuItem(
                        value: 'approved',
                        child: Row(
                          children: [
                            Icon(Icons.check, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Onayla'),
                          ],
                        ),
                      ),
                    if (user.role == 'teacher' && user.isTeacherPending)
                      const PopupMenuItem(
                        value: 'rejected',
                        child: Row(
                          children: [
                            Icon(Icons.close, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Reddet'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'suspend',
                      child: Row(
                        children: [
                          Icon(Icons.pause, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Askıya Al'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'activate',
                      child: Row(
                        children: [
                          Icon(Icons.play_arrow, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Aktifleştir'),
                        ],
                      ),
                    ),
                  ],
                  child: const Icon(Icons.more_vert),
                ),
              ],
            ),
            
            // Ek Bilgiler
            if (user.role == 'teacher') ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Kayıt: ${user.createdAt != null ? _formatDate(user.createdAt!) : 'Bilinmiyor'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  if (user.approvedAt != null) ...[
                    Icon(Icons.check_circle, size: 16, color: Colors.green[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Onay: ${_formatDate(user.approvedAt!)}',
                      style: TextStyle(
                        color: Colors.green[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRoleChip(String role) {
    Color color;
    String label;
    
    switch (role) {
      case 'admin':
        color = Colors.red;
        label = 'Admin';
        break;
      case 'teacher':
        color = Colors.blue;
        label = 'Öğretmen';
        break;
      case 'student':
        color = Colors.green;
        label = 'Öğrenci';
        break;
      default:
        color = Colors.grey;
        label = role;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildStatusChip(User user) {
    Color color;
    String label;
    IconData icon;
    
    if (user.role == 'teacher') {
      if (user.isTeacherApproved) {
        color = Colors.green;
        label = 'Onaylı';
        icon = Icons.check_circle;
      } else if (user.isTeacherPending) {
        color = Colors.orange;
        label = 'Beklemede';
        icon = Icons.access_time;
      } else if (user.isTeacherRejected) {
        color = Colors.red;
        label = 'Reddedildi';
        icon = Icons.close;
      } else {
        color = Colors.grey;
        label = 'Bilinmiyor';
        icon = Icons.help;
      }
    } else {
      color = Colors.blue;
      label = 'Aktif';
      icon = Icons.check_circle;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'teacher':
        return Colors.blue;
      case 'student':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
