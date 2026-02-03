import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../models/profile.dart';
import '../providers/profile_provider.dart';
import 'edit_profile_modal.dart';

class ProfileCard extends StatelessWidget {
  final Profile profile;
  final bool isSelected;
  final VoidCallback onTap;

  const ProfileCard({
    super.key,
    required this.profile,
    required this.isSelected,
    required this.onTap,
  });

  void _showActionSheet(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text(
          '${profile.name}\'s Profile',
          style: TextStyle(fontSize: isTablet ? 18.0 : 16.0, fontWeight: FontWeight.w500),
        ),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              showCupertinoModalPopup(
                context: context,
                builder: (context) => EditProfileModal(profile: profile),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.pencil, color: Color(0xFF007AFF)),
                SizedBox(width: isTablet ? 10.0 : 8.0),
                Text('Edit Profile', style: TextStyle(fontSize: isTablet ? 18.0 : 16.0)),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _showDeleteConfirmation(context);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.delete, color: CupertinoColors.destructiveRed),
                SizedBox(width: isTablet ? 10.0 : 8.0),
                Text('Delete Profile', style: TextStyle(fontSize: isTablet ? 18.0 : 16.0)),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text('Cancel', style: TextStyle(fontSize: isTablet ? 18.0 : 16.0)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    showCupertinoDialog<void>(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text('Delete Profile', style: TextStyle(fontSize: isTablet ? 19.0 : 17.0)),
        content: Text(
          'Are you sure you want to delete ${profile.name}\'s profile? This action cannot be undone.',
          style: TextStyle(fontSize: isTablet ? 15.0 : 13.0),
        ),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: Text('Cancel', style: TextStyle(fontSize: isTablet ? 18.0 : 16.0)),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              context.read<ProfileProvider>().deleteProfile(profile.id!);
            },
            child: Text('Delete', style: TextStyle(fontSize: isTablet ? 18.0 : 16.0)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    // Responsive sizing
    final cardHeight = isTablet ? 210.0 : 190.0; // Reduced height to prevent overflow
    final padding = isTablet ? 14.0 : 12.0; // Reduced padding
    final borderRadius = isTablet ? 24.0 : 20.0;

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showActionSheet(context),
      child: Container(
        height: cardHeight,
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBE6),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF9F43) : Colors.transparent,
            width: isTablet ? 4.0 : 3.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: isTablet ? 16.0 : 12.0,
              offset: Offset(0, isTablet ? 6.0 : 4.0),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header row with ellipsis button
            SizedBox(
              height: isTablet ? 32.0 : 28.0, // Increased height for better alignment
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => _showActionSheet(context),
                    child: Container(
                      padding: EdgeInsets.all(isTablet ? 8.0 : 6.0), // Increased padding
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.10),
                            blurRadius: 4.0,
                            offset: const Offset(0, 1.5),
                          ),
                        ],
                      ),
                      child: Icon(
                        CupertinoIcons.ellipsis,
                        size: isTablet ? 26.0 : 22.0, // Increased icon size
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main content - centered in remaining space
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: isTablet ? 90.0 : 80.0,
                    height: isTablet ? 90.0 : 80.0,
                    decoration: BoxDecoration(
                      color: profile.avatarType == 'photo' ? Colors.transparent : _getAvatarColor(profile.avatar),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: isTablet ? 10.0 : 8.0,
                          offset: const Offset(0, 2.0),
                        ),
                      ],
                    ),
                    child: _buildAvatarContent(isTablet),
                  ),
                  SizedBox(height: isTablet ? 8.0 : 6.0), // Reduced spacing
                  Flexible(
                    child: Text(
                      profile.name,
                      style: TextStyle(
                        fontSize: isTablet ? 18.0 : 16.0, // Slightly smaller font
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFFF6B6B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: isTablet ? 2.0 : 1.0), // Reduced spacing
                  Flexible(
                    child: Text(
                      'Age ${profile.age}',
                      style: TextStyle(
                        fontSize: isTablet ? 14.0 : 12.0, // Slightly smaller font
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF43C465),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarContent(bool isTablet) {
    final avatarSize = isTablet ? 90.0 : 80.0;
    final iconSize = isTablet ? 45.0 : 40.0;
    final emojiSize = isTablet ? 45.0 : 40.0;

    if (profile.avatarType == 'photo') {
      return Container(
        width: avatarSize,
        height: avatarSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: isTablet ? 4.0 : 3.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: isTablet ? 10.0 : 8.0,
              offset: const Offset(0, 2.0),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.file(
            File(profile.avatar),
            width: avatarSize,
            height: avatarSize,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // Fallback to emoji if photo fails to load
              return Container(
                width: avatarSize,
                height: avatarSize,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFD3B6),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    CupertinoIcons.person,
                    size: iconSize,
                    color: Colors.black54,
                  ),
                ),
              );
            },
          ),
        ),
      );
    } else {
      // Emoji avatar
      return Container(
        width: avatarSize,
        height: avatarSize,
        decoration: BoxDecoration(
          color: _getAvatarColor(profile.avatar),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          profile.avatar,
          style: TextStyle(
            fontSize: emojiSize,
            height: 1.0,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
  }

  Color _getAvatarColor(String avatar) {
    switch (avatar) {
      case '👧':
        return const Color(0xFFFFE066); // Yellow for Madeline
      case '👦':
        return const Color(0xFFB3E0FF); // Blue for Matthew
      default:
        return const Color(0xFFFFD3B6); // Default peachy color
    }
  }
}

class AddProfileCard extends StatelessWidget {
  final VoidCallback onTap;

  const AddProfileCard({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    // Responsive sizing to match ProfileCard
    final cardHeight = isTablet ? 210.0 : 190.0; // Match ProfileCard height
    final borderRadius = isTablet ? 24.0 : 20.0;
    final iconSize = isTablet ? 52.0 : 44.0; // Slightly smaller icon
    final fontSize = isTablet ? 16.0 : 14.0; // Slightly smaller font

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: cardHeight,
        decoration: BoxDecoration(
          color: const Color(0xFFEAF6FF),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: const Color(0xFF8FD6FF),
            width: isTablet ? 3.0 : 2.0,
            style: BorderStyle.solid,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: isTablet ? 16.0 : 12.0,
              offset: Offset(0, isTablet ? 6.0 : 4.0),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.add_circled,
              size: iconSize,
              color: const Color(0xFF8FD6FF),
            ),
            SizedBox(height: isTablet ? 12.0 : 8.0),
            Text(
              'Add Profile',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF8FD6FF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
