import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
// import 'package:open_file/open_file.dart'; // Temporarily unused
import '../../services/api_service.dart';
import '../../widgets/custom_widgets.dart';
import '../../models/user.dart';
import '../../models/assignment.dart';

class AssignmentScreen extends StatefulWidget {
  final User otherUser;
  final int? reservationId;
  final bool isTeacher;

  const AssignmentScreen({
    super.key,
    required this.otherUser,
    this.reservationId,
    required this.isTeacher,
  });

  @override
  State<AssignmentScreen> createState() => _AssignmentScreenState();
}

class _AssignmentScreenState extends State<AssignmentScreen> {
  final ApiService _apiService = ApiService();
  List<Assignment> _assignments = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  Future<void> _loadAssignments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.getAssignments(
        widget.otherUser.id,
        widget.reservationId,
      );

      setState(() {
        _assignments = (response['assignments'] as List)
            .map((json) => Assignment.fromJson(json))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _createAssignment() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateAssignmentScreen(
          receiverId: widget.otherUser.id,
          reservationId: widget.reservationId,
        ),
      ),
    );

    if (result == true) {
      _loadAssignments();
    }
  }

  Future<void> _submitAssignment(Assignment assignment) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        
        // Show notes dialog
        final notes = await _showNotesDialog();
        
        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Ödev teslim ediliyor...'),
              ],
            ),
          ),
        );

        try {
          await _apiService.submitAssignment(
            assignment.id,
            file.path!,
            notes ?? '',
          );

          Navigator.pop(context); // Close loading dialog
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ödev başarıyla teslim edildi'),
              backgroundColor: Colors.green,
            ),
          );

          _loadAssignments();
        } catch (e) {
          Navigator.pop(context); // Close loading dialog
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ödev teslim edilirken hata: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dosya seçilirken hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _gradeAssignment(Assignment assignment) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GradeAssignmentScreen(assignment: assignment),
      ),
    );

    if (result == true) {
      _loadAssignments();
    }
  }

  Future<String?> _showNotesDialog() async {
    final controller = TextEditingController();
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notlar Ekle'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Ödev hakkında notlar (isteğe bağlı)',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Atla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isTeacher ? 'Ödev Yönetimi' : 'Ödevlerim'),
        actions: [
          if (widget.isTeacher)
            IconButton(
              icon: const Icon(Icons.add_task_rounded),
              onPressed: _createAssignment,
              tooltip: 'Yeni Ödev',
            ),
        ],
      ),
      body: _isLoading
          ? CustomWidgets.customLoading(message: 'Ödevler yükleniyor...')
          : _error != null
              ? CustomWidgets.errorWidget(
                  errorMessage: _error!,
                  onRetry: _loadAssignments,
                )
              : _assignments.isEmpty
                  ? CustomWidgets.emptyState(
                      message: widget.isTeacher
                          ? 'Henüz ödev oluşturulmadı.'
                          : 'Henüz size atanmış bir ödev yok.',
                      icon: Icons.assignment_rounded,
                    )
                  : RefreshIndicator(
                      onRefresh: _loadAssignments,
                      child: ListView.builder(
                        itemCount: _assignments.length,
                        itemBuilder: (context, index) {
                          final assignment = _assignments[index];
                          return _buildAssignmentCard(assignment);
                        },
                      ),
                    ),
    );
  }

  Widget _buildAssignmentCard(Assignment assignment) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Text(
          assignment.title,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Son Teslim: ${_formatDate(assignment.dueDate)}'),
            Row(
              children: [
                _buildStatusChip(assignment.status),
                const SizedBox(width: 8),
                _buildDifficultyChip(assignment.difficulty),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (assignment.description.isNotEmpty) ...[
                  Text(
                    'Açıklama:',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(assignment.description),
                  const SizedBox(height: 16),
                ],
                
                _buildAssignmentInfo(assignment),
                
                if (assignment.submissionFileName != null) ...[
                  const SizedBox(height: 16),
                  _buildSubmissionInfo(assignment),
                ],
                
                if (assignment.grade != null) ...[
                  const SizedBox(height: 16),
                  _buildGradeInfo(assignment),
                ],
                
                const SizedBox(height: 16),
                _buildActionButtons(assignment),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String text;
    
    switch (status) {
      case 'pending':
        color = Colors.orange;
        text = 'Bekliyor';
        break;
      case 'submitted':
        color = Colors.blue;
        text = 'Teslim Edildi';
        break;
      case 'graded':
        color = Colors.green;
        text = 'Değerlendirildi';
        break;
      case 'overdue':
        color = Colors.red;
        text = 'Gecikti';
        break;
      default:
        color = Colors.grey;
        text = status;
    }
    
    return Chip(
      label: Text(text),
      backgroundColor: color.withValues(alpha: 0.1),
      labelStyle: TextStyle(color: color, fontSize: 12),
    );
  }

  Widget _buildDifficultyChip(String difficulty) {
    Color color;
    String text;
    
    switch (difficulty) {
      case 'easy':
        color = Colors.green;
        text = 'Kolay';
        break;
      case 'medium':
        color = Colors.orange;
        text = 'Orta';
        break;
      case 'hard':
        color = Colors.red;
        text = 'Zor';
        break;
      default:
        color = Colors.grey;
        text = difficulty;
    }
    
    return Chip(
      label: Text(text),
      backgroundColor: color.withValues(alpha: 0.1),
      labelStyle: TextStyle(color: color, fontSize: 12),
    );
  }

  Widget _buildAssignmentInfo(Assignment assignment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ödev Bilgileri:',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.person, size: 16),
            const SizedBox(width: 8),
            Text('Öğretmen: ${assignment.teacherName}'),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.schedule, size: 16),
            const SizedBox(width: 8),
            Text('Teslim Tarihi: ${_formatDate(assignment.dueDate)}'),
          ],
        ),
      ],
    );
  }

  Widget _buildSubmissionInfo(Assignment assignment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Teslim Bilgileri:',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.attach_file, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(assignment.submissionFileName!)),
          ],
        ),
        if (assignment.submissionNotes != null && assignment.submissionNotes!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Notlar: ${assignment.submissionNotes}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (assignment.submittedAt != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.access_time, size: 16),
              const SizedBox(width: 8),
              Text('Teslim Tarihi: ${_formatDate(assignment.submittedAt!)}'),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildGradeInfo(Assignment assignment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Değerlendirme:',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.grade, size: 16),
            const SizedBox(width: 8),
            Text('Not: ${assignment.grade}'),
          ],
        ),
        if (assignment.feedback != null && assignment.feedback!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Geri Bildirim: ${assignment.feedback}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (assignment.gradedAt != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.access_time, size: 16),
              const SizedBox(width: 8),
              Text('Değerlendirme Tarihi: ${_formatDate(assignment.gradedAt!)}'),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons(Assignment assignment) {
    if (widget.isTeacher) {
      if (assignment.status == 'submitted') {
        return ElevatedButton.icon(
          onPressed: () => _gradeAssignment(assignment),
          icon: const Icon(Icons.grade_rounded),
          label: const Text('Ödevi Değerlendir'),
        );
      } else {
        return Text(
          'Öğrenci henüz teslim etmedi',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey,
          ),
        );
      }
    } else {
      if (assignment.status == 'pending' || assignment.status == 'overdue') {
        return ElevatedButton.icon(
          onPressed: () => _submitAssignment(assignment),
          icon: const Icon(Icons.upload_rounded),
          label: const Text('Ödevi Teslim Et'),
        );
      } else if (assignment.status == 'submitted') {
        return Text(
          'Ödev değerlendiriliyor...',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.blue,
          ),
        );
      } else {
        return Text(
          'Ödev tamamlandı',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.green,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// Create Assignment Screen
class CreateAssignmentScreen extends StatefulWidget {
  final int receiverId;
  final int? reservationId;

  const CreateAssignmentScreen({
    super.key,
    required this.receiverId,
    this.reservationId,
  });

  @override
  State<CreateAssignmentScreen> createState() => _CreateAssignmentScreenState();
}

class _CreateAssignmentScreenState extends State<CreateAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dueDateController = TextEditingController();
  String _selectedDifficulty = 'medium';
  DateTime? _selectedDate;
  bool _isLoading = false;

  final ApiService _apiService = ApiService();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        setState(() {
          _selectedDate = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
          _dueDateController.text = _formatDateTime(_selectedDate!);
        });
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _createAssignment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen teslim tarihi seçin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _apiService.createAssignment({
        'receiver_id': widget.receiverId,
        'title': _titleController.text,
        'description': _descriptionController.text,
        'due_date': _selectedDate!.toIso8601String(),
        'difficulty': _selectedDifficulty,
        if (widget.reservationId != null) 'reservation_id': widget.reservationId,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ödev başarıyla oluşturuldu'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ödev oluşturulurken hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Ödev'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createAssignment,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Oluştur'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Ödev Başlığı',
                hintText: 'Ödev başlığını girin',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Başlık gerekli';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Açıklama',
                hintText: 'Ödev açıklamasını girin',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _dueDateController,
              decoration: const InputDecoration(
                labelText: 'Teslim Tarihi',
                hintText: 'Teslim tarihini seçin',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              readOnly: true,
              onTap: _selectDate,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Teslim tarihi gerekli';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            DropdownButtonFormField<String>(
              value: _selectedDifficulty,
              decoration: const InputDecoration(
                labelText: 'Zorluk Seviyesi',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'easy', child: Text('Kolay')),
                DropdownMenuItem(value: 'medium', child: Text('Orta')),
                DropdownMenuItem(value: 'hard', child: Text('Zor')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedDifficulty = value!;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Grade Assignment Screen
class GradeAssignmentScreen extends StatefulWidget {
  final Assignment assignment;

  const GradeAssignmentScreen({
    super.key,
    required this.assignment,
  });

  @override
  State<GradeAssignmentScreen> createState() => _GradeAssignmentScreenState();
}

class _GradeAssignmentScreenState extends State<GradeAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _feedbackController = TextEditingController();
  String _selectedGrade = 'A';
  bool _isLoading = false;

  final ApiService _apiService = ApiService();

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _gradeAssignment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _apiService.gradeAssignment(
        widget.assignment.id,
        _selectedGrade,
        _feedbackController.text,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ödev başarıyla değerlendirildi'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ödev değerlendirilirken hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ödev Değerlendir'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _gradeAssignment,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Değerlendir'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.assignment.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('Öğrenci: ${widget.assignment.studentName}'),
                    const SizedBox(height: 8),
                    Text('Teslim: ${widget.assignment.submissionFileName}'),
                    if (widget.assignment.submissionNotes != null && widget.assignment.submissionNotes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Notlar: ${widget.assignment.submissionNotes}'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            DropdownButtonFormField<String>(
              value: _selectedGrade,
              decoration: const InputDecoration(
                labelText: 'Not',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'A+', child: Text('A+')),
                DropdownMenuItem(value: 'A', child: Text('A')),
                DropdownMenuItem(value: 'B+', child: Text('B+')),
                DropdownMenuItem(value: 'B', child: Text('B')),
                DropdownMenuItem(value: 'C+', child: Text('C+')),
                DropdownMenuItem(value: 'C', child: Text('C')),
                DropdownMenuItem(value: 'D+', child: Text('D+')),
                DropdownMenuItem(value: 'D', child: Text('D')),
                DropdownMenuItem(value: 'F', child: Text('F')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedGrade = value!;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Not seçin';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _feedbackController,
              decoration: const InputDecoration(
                labelText: 'Geri Bildirim',
                hintText: 'Öğrenciye geri bildirim verin',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }
}