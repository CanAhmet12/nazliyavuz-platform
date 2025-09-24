import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/user.dart';
import '../../models/message.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../video_call/video_call_screen.dart';
import '../files/file_sharing_screen.dart';
import '../assignments/assignment_screen.dart';

class ChatScreen extends StatefulWidget {
  final User otherUser;

  const ChatScreen({
    super.key,
    required this.otherUser,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _apiService = ApiService();
  
  List<Message> _messages = [];
  int? _chatId;
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChat() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final response = await _apiService.getOrCreateChat(widget.otherUser.id);
      final chatData = response['chat'];
      
      setState(() {
        _chatId = chatData['id'];
        _messages = (chatData['messages'] as List)
            .map((json) => Message.fromJson(json))
            .toList();
        _isLoading = false;
      });

      // Mark messages as read
      if (_chatId != null) {
        await _apiService.markMessagesAsRead(_chatId!);
      }

      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _chatId == null || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      final message = await _apiService.sendMessage(_chatId!, content);
      
      setState(() {
        _messages.add(message);
      });

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      _showErrorSnackBar('Mesaj gönderilirken hata oluştu: $e');
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // Profile Photo
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryBlue,
                    AppTheme.accentPurple,
                  ],
                ),
              ),
              child: widget.otherUser.profilePhotoUrl == null
                  ? Text(
                      widget.otherUser.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(
                        widget.otherUser.profilePhotoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Text(
                            widget.otherUser.name[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUser.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    widget.otherUser.role == 'teacher' ? 'Öğretmen' : 'Öğrenci',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoCallScreen(
                    otherUser: widget.otherUser,
                    callType: 'video',
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.attach_file, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FileSharingScreen(
                    otherUser: widget.otherUser,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              _showChatOptions();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildMessagesList(),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Chat yüklenirken hata oluştu',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadChat,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz mesaj yok',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'İlk mesajı siz gönderin!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message.senderId == _getCurrentUserId();
        final showDate = _shouldShowDate(index);
        
        return Column(
          children: [
            if (showDate) _buildDateSeparator(message.createdAt),
            _buildMessageBubble(message, isMe),
          ],
        );
      },
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        DateFormat('dd MMMM yyyy', 'tr').format(date),
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryBlue.withValues(alpha: 0.7),
                    AppTheme.accentPurple.withValues(alpha: 0.7),
                  ],
                ),
              ),
              child: widget.otherUser.profilePhotoUrl == null
                  ? Text(
                      widget.otherUser.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        widget.otherUser.profilePhotoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Text(
                            widget.otherUser.name[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.primaryBlue : Colors.grey[100],
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 16,
                      color: isMe ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('HH:mm').format(message.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: isMe 
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              ),
              child: const Icon(
                Icons.person,
                color: AppTheme.primaryBlue,
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Mesajınızı yazın...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                maxLines: null,
                textInputAction: TextInputAction.newline,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.add_rounded),
            onSelected: _handleMenuSelection,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'video_call',
                child: Row(
                  children: [
                    Icon(Icons.video_call_rounded),
                    SizedBox(width: 8),
                    Text('Video Görüşme'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'audio_call',
                child: Row(
                  children: [
                    Icon(Icons.call_rounded),
                    SizedBox(width: 8),
                    Text('Sesli Görüşme'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'file_sharing',
                child: Row(
                  children: [
                    Icon(Icons.folder_shared_rounded),
                    SizedBox(width: 8),
                    Text('Dosya Paylaşımı'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'assignments',
                child: Row(
                  children: [
                    Icon(Icons.assignment_rounded),
                    SizedBox(width: 8),
                    Text('Ödevler'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _isSending ? null : _sendMessage,
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowDate(int index) {
    if (index == 0) return true;
    
    final currentDate = _messages[index].createdAt;
    final previousDate = _messages[index - 1].createdAt;
    
    return !DateUtils.isSameDay(currentDate, previousDate);
  }

  int _getCurrentUserId() {
    // Bu bilgiyi AuthBloc'tan almalıyız, şimdilik mock olarak 1 döndürüyoruz
    // TODO: AuthBloc'tan gerçek user ID'yi al
    return 1;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showChatOptions() {
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
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                
                Text(
                  'Chat Seçenekleri',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[900],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Options Grid
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _buildChatOptionCard(
                      context,
                      icon: Icons.video_call_rounded,
                      title: 'Video Görüşme',
                      subtitle: 'Video görüşme başlat',
                      color: const Color(0xFF3B82F6),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VideoCallScreen(
                              otherUser: widget.otherUser,
                              callType: 'video',
                            ),
                          ),
                        );
                      },
                    ),
                    _buildChatOptionCard(
                      context,
                      icon: Icons.call_rounded,
                      title: 'Sesli Görüşme',
                      subtitle: 'Sesli görüşme başlat',
                      color: const Color(0xFF10B981),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VideoCallScreen(
                              otherUser: widget.otherUser,
                              callType: 'audio',
                            ),
                          ),
                        );
                      },
                    ),
                    _buildChatOptionCard(
                      context,
                      icon: Icons.folder_shared_rounded,
                      title: 'Dosya Paylaşımı',
                      subtitle: 'Dosya paylaş',
                      color: const Color(0xFFF59E0B),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FileSharingScreen(
                              otherUser: widget.otherUser,
                            ),
                          ),
                        );
                      },
                    ),
                    _buildChatOptionCard(
                      context,
                      icon: Icons.assignment_rounded,
                      title: 'Ödevler',
                      subtitle: 'Ödevleri görüntüle',
                      color: const Color(0xFF8B5CF6),
                      onTap: () {
                        Navigator.pop(context);
                        // TODO: Get actual user role from AuthBloc
                        final isTeacher = true; // This should come from actual user data
                        
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AssignmentScreen(
                              otherUser: widget.otherUser,
                              isTeacher: isTeacher,
                            ),
                          ),
                        );
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

  Widget _buildChatOptionCard(
    BuildContext context, {
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
              color: color.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
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
                color: Colors.grey[900],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'video_call':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoCallScreen(
              otherUser: widget.otherUser,
              callType: 'video',
            ),
          ),
        );
        break;
      case 'audio_call':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoCallScreen(
              otherUser: widget.otherUser,
              callType: 'audio',
            ),
          ),
        );
        break;
      case 'file_sharing':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FileSharingScreen(
              otherUser: widget.otherUser,
            ),
          ),
        );
        break;
      case 'assignments':
        // Check if user is teacher to determine if they can create assignments
        // For now, we'll assume the current user can determine their role
        // TODO: Get actual user role from AuthBloc
        final isTeacher = true; // This should come from actual user data
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AssignmentScreen(
              otherUser: widget.otherUser,
              isTeacher: isTeacher,
            ),
          ),
        );
        break;
    }
  }
}