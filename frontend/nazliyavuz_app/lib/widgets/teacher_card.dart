import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_widgets.dart';
import '../models/teacher.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/reservations/create_reservation_screen.dart';

class TeacherCard extends StatelessWidget {
  final Teacher teacher;
  final VoidCallback? onTap;
  final bool showFavoriteButton;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  const TeacherCard({
    super.key,
    required this.teacher,
    this.onTap,
    this.showFavoriteButton = true,
    this.isFavorite = false,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimationConfiguration.staggeredList(
      position: 0,
      duration: const Duration(milliseconds: 600),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: CustomWidgets.customCard(
            onTap: onTap,
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with image and favorite button
                _buildHeader(context),
                
                const SizedBox(height: 16),
                
                // Teacher info
                _buildTeacherInfo(context),
                
                const SizedBox(height: 12),
                
                // Categories
                _buildCategories(context),
                
                const SizedBox(height: 16),
                
                // Rating and price
                _buildRatingAndPrice(context),
                
                const SizedBox(height: 16),
                
                // Action buttons
                _buildActionButtons(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Stack(
      children: [
        // Teacher image
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryBlue.withOpacity(0.1),
                AppTheme.accentPurple.withOpacity(0.1),
              ],
            ),
          ),
          child: teacher.user?.profilePhotoUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: teacher.user!.profilePhotoUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppTheme.grey100,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppTheme.grey100,
                      child: Icon(
                        Icons.person_rounded,
                        size: 60,
                        color: AppTheme.grey400,
                      ),
                    ),
                  ),
                )
              : Icon(
                  Icons.person_rounded,
                  size: 60,
                  color: AppTheme.grey400,
                ),
        ),
        
        // Favorite button
        if (showFavoriteButton)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isFavorite ? AppTheme.accentRed : AppTheme.grey500,
                  size: 20,
                ),
                onPressed: onFavoriteToggle,
              ),
            ),
          ),
        
        // Online indicator
        if (teacher.onlineAvailable)
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.accentGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Online',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTeacherInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          teacher.user?.name ?? 'Bilinmeyen Öğretmen',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppTheme.grey900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          (teacher.bio?.isNotEmpty ?? false) ? teacher.bio! : 'Deneyimli öğretmen',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.grey600,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildCategories(BuildContext context) {
    if (!(teacher.categories?.isNotEmpty ?? false)) return const SizedBox.shrink();
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: teacher.categories!.take(3).map((category) {
        return CustomWidgets.customChip(
          label: category.name,
          backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
          textColor: AppTheme.primaryBlue,
        );
      }).toList(),
    );
  }

  Widget _buildRatingAndPrice(BuildContext context) {
    return Row(
      children: [
        // Rating
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.accentOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.star_rounded,
                color: AppTheme.accentOrange,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                teacher.ratingAvg.toStringAsFixed(1),
                style: TextStyle(
                  color: AppTheme.accentOrange,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '(${teacher.ratingCount})',
                style: TextStyle(
                  color: AppTheme.grey600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        
        const Spacer(),
        
        // Price
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryBlue,
                AppTheme.primaryBlueDark,
              ],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '₺${(teacher.priceHour ?? 0).toStringAsFixed(0)}/saat',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              if (teacher.user != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      otherUser: teacher.user!,
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.message_rounded, size: 18),
            label: const Text('Mesaj'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppTheme.grey300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        
        const SizedBox(width: 12),
        
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: () {
              if (onTap != null) {
                onTap!();
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateReservationScreen(
                      teacher: teacher,
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.calendar_today_rounded, size: 18),
            label: const Text('Rezerve Et'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}

class TeacherGridCard extends StatelessWidget {
  final Teacher teacher;
  final VoidCallback? onTap;
  final bool showFavoriteButton;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  const TeacherGridCard({
    super.key,
    required this.teacher,
    this.onTap,
    this.showFavoriteButton = true,
    this.isFavorite = false,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimationConfiguration.staggeredGrid(
      position: 0,
      duration: const Duration(milliseconds: 600),
      columnCount: 2,
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: CustomWidgets.customCard(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Teacher image
                Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryBlue.withOpacity(0.1),
                        AppTheme.accentPurple.withOpacity(0.1),
                      ],
                    ),
                  ),
                  child: teacher.user?.profilePhotoUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: teacher.user!.profilePhotoUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: AppTheme.grey100,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Icon(
                              Icons.person_rounded,
                              size: 40,
                              color: AppTheme.grey400,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.person_rounded,
                          size: 40,
                          color: AppTheme.grey400,
                        ),
                ),
                
                const SizedBox(height: 12),
                
                // Teacher name
                Text(
                  teacher.user?.name ?? 'Bilinmeyen Öğretmen',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.grey900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 4),
                
                // Rating
                Row(
                  children: [
                    Icon(
                      Icons.star_rounded,
                      color: AppTheme.accentOrange,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      teacher.ratingAvg.toStringAsFixed(1),
                      style: TextStyle(
                        color: AppTheme.grey700,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(${teacher.ratingCount})',
                      style: TextStyle(
                        color: AppTheme.grey500,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Price
                Text(
                  '₺${(teacher.priceHour ?? 0).toStringAsFixed(0)}/saat',
                  style: TextStyle(
                    color: AppTheme.primaryBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
