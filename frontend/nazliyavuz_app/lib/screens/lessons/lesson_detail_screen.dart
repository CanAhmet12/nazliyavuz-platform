import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class LessonDetailScreen extends StatefulWidget {
  final dynamic lesson;

  const LessonDetailScreen({
    super.key,
    required this.lesson,
  });

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _feedbackController = TextEditingController();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  dynamic _lesson;
  bool _isLoading = false;
  int _selectedRating = 0;
  bool _isRatingLesson = false;

  @override
  void initState() {
    super.initState();
    _lesson = widget.lesson;
    _initializeAnimations();
    _loadLessonData();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300), // Reduced duration
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
    
    // Start animation after build for better performance
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  void _loadLessonData() {
    _notesController.text = _lesson['notes'] ?? '';
    _feedbackController.text = _lesson['feedback'] ?? '';
    _selectedRating = _lesson['rating'] ?? 0;
  }

  Future<void> _startLesson() async {
    try {
      setState(() => _isLoading = true);
      
      final result = await _apiService.startLesson(_lesson['reservation']['id']);
      
      if (mounted) {
        setState(() {
          _lesson['status'] = 'in_progress';
          _lesson['start_time'] = result['lesson']['start_time'];
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ders başlatıldı!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _endLesson() async {
    try {
      setState(() => _isLoading = true);
      
      final result = await _apiService.endLesson(
        _lesson['reservation']['id'],
        _notesController.text.isNotEmpty ? _notesController.text : '',
        0, // rating
        '', // feedback
      );
      
      if (mounted) {
        setState(() {
          _lesson['status'] = 'completed';
          _lesson['end_time'] = result['lesson']['end_time'];
          _lesson['duration_minutes'] = result['lesson']['duration_minutes'];
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ders tamamlandı!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateNotes() async {
    try {
      setState(() => _isLoading = true);
      
      await _apiService.updateLessonNotes(
        lessonId: _lesson['id'],
        notes: _notesController.text,
      );
      
      if (mounted) {
        setState(() {
          _lesson['notes'] = _notesController.text;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notlar güncellendi!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _rateLesson() async {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir puan seçin'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      setState(() => _isLoading = true);
      
      await _apiService.rateLesson(
        lessonId: _lesson['id'],
        rating: _selectedRating,
        feedback: _feedbackController.text.isNotEmpty ? _feedbackController.text : null,
      );
      
      if (mounted) {
        setState(() {
          _lesson['rating'] = _selectedRating;
          _lesson['feedback'] = _feedbackController.text;
          _isRatingLesson = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ders değerlendirildi!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _notesController.dispose();
    _feedbackController.dispose();
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
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Card
                      _buildStatusCard(),
                      
                      const SizedBox(height: 20),
                      
                      // Lesson Info
                      _buildLessonInfo(),
                      
                      const SizedBox(height: 20),
                      
                      // Teacher/Student Info
                      _buildParticipantInfo(),
                      
                      const SizedBox(height: 20),
                      
                      // Notes Section
                      _buildNotesSection(),
                      
                      const SizedBox(height: 20),
                      
                      // Rating Section
                      if (_lesson['status'] == 'completed') _buildRatingSection(),
                      
                      const SizedBox(height: 20),
                      
                      // Action Buttons
                      _buildActionButtons(),
                      
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Ders Detayı',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
      ),
      backgroundColor: AppTheme.backgroundColor,
      foregroundColor: AppTheme.textPrimary,
      elevation: 0,
    );
  }

  Widget _buildStatusCard() {
    final status = _lesson['status'];
    final statusColor = _getStatusColor(status);
    final statusText = _getStatusText(status);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(
            _getStatusIcon(status),
            size: 48,
            color: statusColor,
          ),
          const SizedBox(height: 12),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 8),
          if (_lesson['start_time'] != null)
            Text(
              'Başlangıç: ${_formatDateTime(_lesson['start_time'])}',
              style: TextStyle(
                color: AppTheme.grey600,
                fontSize: 14,
              ),
            ),
          if (_lesson['end_time'] != null)
            Text(
              'Bitiş: ${_formatDateTime(_lesson['end_time'])}',
              style: TextStyle(
                color: AppTheme.grey600,
                fontSize: 14,
              ),
            ),
          if (_lesson['duration_minutes'] != null)
            Text(
              'Süre: ${_lesson['duration_minutes']} dakika',
              style: TextStyle(
                color: AppTheme.grey600,
                fontSize: 14,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLessonInfo() {
    final reservation = _lesson['reservation'];
    final category = reservation?['category'];
    
    return Container(
      padding: const EdgeInsets.all(20),
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
          const Text(
            'Ders Bilgileri',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.category_rounded,
            label: 'Kategori',
            value: category?['name'] ?? 'Genel',
          ),
          _buildInfoRow(
            icon: Icons.schedule_rounded,
            label: 'Planlanan Tarih',
            value: _formatDateTime(reservation?['scheduled_at']),
          ),
          _buildInfoRow(
            icon: Icons.timer_rounded,
            label: 'Süre',
            value: '${reservation?['duration_minutes'] ?? 60} dakika',
          ),
          _buildInfoRow(
            icon: Icons.attach_money_rounded,
            label: 'Ücret',
            value: '₺${reservation?['price'] ?? 0}',
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantInfo() {
    final teacher = _lesson['teacher'];
    final student = _lesson['student'];
    
    return Container(
      padding: const EdgeInsets.all(20),
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
          const Text(
            'Katılımcılar',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildParticipantCard(
            icon: Icons.school_rounded,
            title: 'Öğretmen',
            name: teacher?['user']?['name'] ?? 'İsimsiz',
            email: teacher?['user']?['email'] ?? '',
          ),
          const SizedBox(height: 12),
          _buildParticipantCard(
            icon: Icons.person_rounded,
            title: 'Öğrenci',
            name: student?['user']?['name'] ?? 'İsimsiz',
            email: student?['user']?['email'] ?? '',
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantCard({
    required IconData icon,
    required String title,
    required String name,
    required String email,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryBlue,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.grey600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  email,
                  style: TextStyle(
                    color: AppTheme.grey600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ders Notları',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (_lesson['status'] == 'in_progress' || _lesson['status'] == 'completed')
                TextButton(
                  onPressed: _updateNotes,
                  child: const Text('Kaydet'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            maxLines: 4,
            enabled: _lesson['status'] == 'in_progress' || _lesson['status'] == 'completed',
            decoration: InputDecoration(
              hintText: 'Ders notlarınızı buraya yazın...',
              hintStyle: TextStyle(color: AppTheme.grey500),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.grey300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.grey300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryBlue),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSection() {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ders Değerlendirmesi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (_lesson['rating'] == null)
                TextButton(
                  onPressed: () => setState(() => _isRatingLesson = !_isRatingLesson),
                  child: Text(_isRatingLesson ? 'İptal' : 'Değerlendir'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (_lesson['rating'] != null) ...[
            Row(
              children: [
                const Text(
                  'Puanınız: ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                ...List.generate(5, (index) => Icon(
                  index < _lesson['rating'] ? Icons.star_rounded : Icons.star_border_rounded,
                  color: Colors.amber,
                  size: 24,
                )),
              ],
            ),
            if (_lesson['feedback'] != null && _lesson['feedback'].isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _lesson['feedback'],
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ] else if (_isRatingLesson) ...[
            const Text(
              'Dersi nasıl buldunuz?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: List.generate(5, (index) => GestureDetector(
                onTap: () => setState(() => _selectedRating = index + 1),
                child: Icon(
                  index < _selectedRating ? Icons.star_rounded : Icons.star_border_rounded,
                  color: Colors.amber,
                  size: 32,
                ),
              )),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _feedbackController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Geri bildiriminizi yazın (opsiyonel)...',
                hintStyle: TextStyle(color: AppTheme.grey500),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.grey300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.grey300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryBlue),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _isRatingLesson = false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('İptal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _rateLesson,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Gönder'),
                  ),
                ),
              ],
            ),
          ] else ...[
            const Text(
              'Bu dersi henüz değerlendirmediniz.',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.grey600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final status = _lesson['status'];
    
    return Column(
      children: [
        if (status == 'not_started') ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _startLesson,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Dersi Başlat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ] else if (status == 'in_progress') ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _endLesson,
              icon: const Icon(Icons.stop_rounded),
              label: const Text('Dersi Bitir'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppTheme.grey600,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              color: AppTheme.grey600,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
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

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'not_started':
        return Icons.schedule_rounded;
      case 'in_progress':
        return Icons.play_circle_rounded;
      case 'completed':
        return Icons.check_circle_rounded;
      default:
        return Icons.help_rounded;
    }
  }

  String _formatDateTime(String? dateTime) {
    if (dateTime == null) return 'Tarih belirtilmemiş';
    
    try {
      final date = DateTime.parse(dateTime);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Geçersiz tarih';
    }
  }
}
