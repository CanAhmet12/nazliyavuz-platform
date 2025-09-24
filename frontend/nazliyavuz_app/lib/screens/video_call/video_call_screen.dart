import 'package:flutter/material.dart';
import '../../models/user.dart';

class VideoCallScreen extends StatefulWidget {
  final User otherUser;
  final String callType; // 'video' or 'audio'

  const VideoCallScreen({
    super.key,
    required this.otherUser,
    required this.callType,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isVideoEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  Column(
                    children: [
                      Text(
                        widget.otherUser.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _isConnected ? 'Bağlandı' : 'Bağlanıyor...',
                        style: TextStyle(
                          color: _isConnected ? Colors.green : Colors.orange,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 48), // Balance the back button
                ],
              ),
            ),
            
            // Video area
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.callType == 'video' ? Icons.videocam : Icons.mic,
                        size: 80,
                        color: Colors.white54,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Video Call Özelliği',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Geçici olarak devre dışı',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (widget.otherUser.profilePhotoUrl != null)
                        CircleAvatar(
                          radius: 60,
                          backgroundImage: NetworkImage(widget.otherUser.profilePhotoUrl!),
                        )
                      else
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey[600],
                          child: Text(
                            widget.otherUser.name.isNotEmpty 
                                ? widget.otherUser.name[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        widget.otherUser.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Bottom controls
            Container(
              padding: const EdgeInsets.all(32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute button
                  _buildControlButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    color: _isMuted ? Colors.red : Colors.white,
                    onPressed: () {
                      setState(() {
                        _isMuted = !_isMuted;
                      });
                    },
                  ),
                  
                  // End call button
                  _buildControlButton(
                    icon: Icons.call_end,
                    color: Colors.red,
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  
                  // Video toggle button
                  _buildControlButton(
                    icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                    color: _isVideoEnabled ? Colors.white : Colors.red,
                    onPressed: () {
                      setState(() {
                        _isVideoEnabled = !_isVideoEnabled;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: color, size: 28),
        iconSize: 28,
      ),
    );
  }
}