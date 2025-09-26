import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/api_service.dart';
import '../../models/assignment.dart';
import '../../theme/app_theme.dart';

class AssignmentDetailScreen extends StatefulWidget {
  final Assignment assignment;
  final bool isTeacher;

  const AssignmentDetailScreen({
    super.key,
    required this.assignment,
    this.isTeacher = false,
  });

  @override
  State<AssignmentDetailScreen> createState() => _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState extends State<AssignmentDetailScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _notesController = TextEditingController();
  
  bool _isSubmitting = false;
  PlatformFile? _selectedFile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Ödev Detayı'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAssignmentInfo(),
            const SizedBox(height: 24),
            _buildDescription(),
            const SizedBox(height: 24),
            _buildSubmissionSection(),
            if (widget.assignment.grade != null) ...[
              const SizedBox(height: 24),
              _buildGradeSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentInfo() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.assignment.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusChip(widget.assignment.status),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              Icons.person,
              'Öğretmen',
              widget.assignment.teacherName,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.schedule,
              'Son Teslim Tarihi',
              _formatDate(widget.assignment.dueDate),
              isOverdue: _isOverdue(widget.assignment.dueDate),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.signal_cellular_alt,
              'Zorluk',
              _getDifficultyText(widget.assignment.difficulty),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.calendar_today,
              'Verilme Tarihi',
              _formatCreatedDate(widget.assignment.createdAt),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool isOverdue = false}) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isOverdue ? Colors.red : Colors.grey[600],
        ),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: isOverdue ? Colors.red : Colors.black87,
              fontSize: 14,
              fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    if (widget.assignment.description.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ödev Açıklaması',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.assignment.description,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmissionSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ödev Teslimi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            if (widget.assignment.status == 'pending') ...[
              _buildSubmissionForm(),
            ] else ...[
              _buildSubmissionInfo(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubmissionForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dosya Seçin',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickFile,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[50],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.upload_file,
                  color: AppTheme.primaryBlue,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedFile?.name ?? 'Dosya seçmek için tıklayın',
                    style: TextStyle(
                      color: _selectedFile != null ? Colors.black87 : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Notlar (İsteğe Bağlı)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Ödev hakkında notlarınız...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _selectedFile != null && !_isSubmitting ? _submitAssignment : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isSubmitting
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('Teslim Ediliyor...'),
                    ],
                  )
                : const Text(
                    'Ödevi Teslim Et',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmissionInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green[50],
            border: Border.all(color: Colors.green[200]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green[600],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ödev Teslim Edildi',
                      style: TextStyle(
                        color: Colors.green[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.assignment.submittedAt != null)
                      Text(
                        'Teslim Tarihi: ${_formatCreatedDate(widget.assignment.submittedAt!)}',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (widget.assignment.submissionFileName != null) ...[
          const SizedBox(height: 16),
          const Text(
            'Teslim Edilen Dosya',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.insert_drive_file,
                  color: AppTheme.primaryBlue,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(widget.assignment.submissionFileName!),
                ),
              ],
            ),
          ),
        ],
        if (widget.assignment.submissionNotes != null && 
            widget.assignment.submissionNotes!.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Teslim Notları',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[50],
            ),
            child: Text(widget.assignment.submissionNotes!),
          ),
        ],
      ],
    );
  }

  Widget _buildGradeSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Değerlendirme',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.grade,
                  color: _getGradeColor(widget.assignment.grade!),
                  size: 32,
                ),
                const SizedBox(width: 12),
                Text(
                  'Not: ${widget.assignment.grade}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _getGradeColor(widget.assignment.grade!),
                  ),
                ),
              ],
            ),
            if (widget.assignment.feedback != null && 
                widget.assignment.feedback!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Öğretmen Geri Bildirimi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[50],
                ),
                child: Text(
                  widget.assignment.feedback!,
                  style: const TextStyle(height: 1.5),
                ),
              ),
            ],
            if (widget.assignment.gradedAt != null) ...[
              const SizedBox(height: 12),
              Text(
                'Değerlendirme Tarihi: ${_formatCreatedDate(widget.assignment.gradedAt!)}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String text;
    IconData icon;

    switch (status) {
      case 'pending':
        color = Colors.orange;
        text = 'Bekliyor';
        icon = Icons.pending_actions;
        break;
      case 'submitted':
        color = Colors.blue;
        text = 'Teslim Edildi';
        icon = Icons.check_circle;
        break;
      case 'graded':
        color = Colors.green;
        text = 'Değerlendirildi';
        icon = Icons.grade;
        break;
      default:
        color = Colors.grey;
        text = 'Bilinmeyen';
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null) {
        setState(() {
          _selectedFile = result.files.first;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dosya seçilirken hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitAssignment() async {
    if (_selectedFile == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _apiService.submitAssignment(
        widget.assignment.id,
        _selectedFile!,
        _notesController.text.trim(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ödev başarıyla teslim edildi!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ödev teslim edilirken hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.inDays > 0) {
      return '${difference.inDays} gün kaldı';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat kaldı';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} dakika kaldı';
    } else {
      return 'Süresi doldu';
    }
  }

  String _formatCreatedDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getDifficultyText(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return 'Kolay';
      case 'medium':
        return 'Orta';
      case 'hard':
        return 'Zor';
      default:
        return 'Bilinmeyen';
    }
  }

  bool _isOverdue(DateTime dueDate) {
    return DateTime.now().isAfter(dueDate);
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'A+':
      case 'A':
        return Colors.green;
      case 'B+':
      case 'B':
        return Colors.blue;
      case 'C+':
      case 'C':
        return Colors.orange;
      case 'D+':
      case 'D':
        return Colors.red;
      case 'F':
        return Colors.red[800]!;
      default:
        return Colors.grey;
    }
  }
}
