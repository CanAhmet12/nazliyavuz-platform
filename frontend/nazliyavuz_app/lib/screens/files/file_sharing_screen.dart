import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
// import 'package:open_file/open_file.dart'; // Temporarily unused
import '../../services/api_service.dart';
import '../../widgets/custom_widgets.dart';
import '../../models/user.dart';
import '../../models/shared_file.dart';

class FileSharingScreen extends StatefulWidget {
  final User otherUser;
  final int? reservationId;

  const FileSharingScreen({
    super.key,
    required this.otherUser,
    this.reservationId,
  });

  @override
  State<FileSharingScreen> createState() => _FileSharingScreenState();
}

class _FileSharingScreenState extends State<FileSharingScreen> {
  final ApiService _apiService = ApiService();
  List<SharedFile> _sharedFiles = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSharedFiles();
  }

  Future<void> _loadSharedFiles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.getSharedFiles(
        widget.otherUser.id,
        widget.reservationId,
      );

      setState(() {
        _sharedFiles = (response['files'] as List)
            .map((json) => SharedFile.fromJson(json))
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

  Future<void> _pickAndUploadFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        
        // Show category selection dialog
        final category = await _showCategoryDialog();
        if (category == null) return;

        // Show description dialog
        final description = await _showDescriptionDialog();
        
        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Dosya yükleniyor...'),
              ],
            ),
          ),
        );

        try {
          await _apiService.uploadSharedFile(
            filePath: file.path!,
            fileName: file.name,
            receiverId: widget.otherUser.id,
            description: description ?? '',
            category: category,
            reservationId: widget.reservationId,
          );

          Navigator.pop(context); // Close loading dialog
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dosya başarıyla paylaşıldı'),
              backgroundColor: Colors.green,
            ),
          );

          _loadSharedFiles();
        } catch (e) {
          Navigator.pop(context); // Close loading dialog
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Dosya yüklenirken hata: $e'),
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

  Future<String?> _showCategoryDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kategori Seçin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCategoryOption('document', 'Döküman'),
            _buildCategoryOption('homework', 'Ödev'),
            _buildCategoryOption('notes', 'Notlar'),
            _buildCategoryOption('resource', 'Kaynak'),
            _buildCategoryOption('other', 'Diğer'),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryOption(String value, String label) {
    return ListTile(
      title: Text(label),
      onTap: () => Navigator.pop(context, value),
    );
  }

  Future<String?> _showDescriptionDialog() async {
    final controller = TextEditingController();
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Açıklama Ekle'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Dosya açıklaması (isteğe bağlı)',
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

  Future<void> _downloadFile(SharedFile file) async {
    try {
      // final response = await _apiService.downloadSharedFile(file.id);
      // final downloadUrl = response['download_url'];
      
      // Open the file
      // await OpenFile.open(downloadUrl); // Temporarily disabled
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dosya indirilirken hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteFile(SharedFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dosyayı Sil'),
        content: Text('${file.fileName} dosyasını silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.deleteSharedFile(file.id);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dosya başarıyla silindi'),
            backgroundColor: Colors.green,
          ),
        );

        _loadSharedFiles();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dosya silinirken hata: $e'),
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
        title: Text('${widget.otherUser.name} ile Dosyalar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            onPressed: _pickAndUploadFile,
            tooltip: 'Dosya Yükle',
          ),
        ],
      ),
      body: _isLoading
          ? CustomWidgets.customLoading(message: 'Dosyalar yükleniyor...')
          : _error != null
              ? CustomWidgets.errorWidget(
                  errorMessage: _error!,
                  onRetry: _loadSharedFiles,
                )
              : _sharedFiles.isEmpty
                  ? CustomWidgets.emptyState(
                      message: 'Henüz dosya paylaşılmadı.',
                      icon: Icons.folder_open_rounded,
                    )
                  : RefreshIndicator(
                      onRefresh: _loadSharedFiles,
                      child: ListView.builder(
                        itemCount: _sharedFiles.length,
                        itemBuilder: (context, index) {
                          final file = _sharedFiles[index];
                          return _buildFileCard(file);
                        },
                      ),
                    ),
    );
  }

  Widget _buildFileCard(SharedFile file) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(
            _getFileIcon(file.fileIcon),
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          file.fileName,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${file.categoryInTurkish} • ${file.fileSizeFormatted}'),
            Text(
              '${file.uploadedBy.name} • ${_formatDate(file.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (file.description.isNotEmpty)
              Text(
                file.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.download_rounded),
              onPressed: () => _downloadFile(file),
              tooltip: 'İndir',
            ),
            IconButton(
              icon: const Icon(Icons.delete_rounded, color: Colors.red),
              onPressed: () => _deleteFile(file),
              tooltip: 'Sil',
            ),
          ],
        ),
        onTap: () => _downloadFile(file),
      ),
    );
  }

  IconData _getFileIcon(String iconType) {
    switch (iconType) {
      case 'image':
        return Icons.image_rounded;
      case 'video':
        return Icons.video_file_rounded;
      case 'audio':
        return Icons.audio_file_rounded;
      case 'picture_as_pdf':
        return Icons.picture_as_pdf_rounded;
      case 'description':
        return Icons.description_rounded;
      case 'text_snippet':
        return Icons.text_snippet_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} gün önce';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat önce';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} dakika önce';
    } else {
      return 'Az önce';
    }
  }
}