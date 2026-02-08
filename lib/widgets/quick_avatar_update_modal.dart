import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../models/profile.dart';
import 'avatar_selector.dart';

class QuickAvatarUpdateModal extends StatefulWidget {
  final Profile profile;

  const QuickAvatarUpdateModal({super.key, required this.profile});

  @override
  State<QuickAvatarUpdateModal> createState() => _QuickAvatarUpdateModalState();
}

class _QuickAvatarUpdateModalState extends State<QuickAvatarUpdateModal> {
  late String _selectedAvatar;
  late String _selectedAvatarType;

  @override
  void initState() {
    super.initState();
    _selectedAvatar = widget.profile.avatar;
    _selectedAvatarType = widget.profile.avatarType;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    // Responsive sizing
    final horizontalMargin = isTablet ? 48.0 : 32.0;
    final maxHeight = isTablet ? 600.0 : 500.0;
    final borderRadius = isTablet ? 24.0 : 20.0;
    final padding = isTablet ? 20.0 : 16.0;
    final fontSize = isTablet ? 19.0 : 17.0;

    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
          constraints: BoxConstraints(
            maxHeight: maxHeight,
            maxWidth: isTablet ? 500.0 : double.infinity,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(padding),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Color(0xFFE5E5EA),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Semantics(
                      label: 'Cancel avatar update',
                      button: true,
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: const Color(0xFF007AFF),
                            fontSize: fontSize,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      'Update Avatar',
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF000000),
                      ),
                    ),
                    Semantics(
                      label: 'Save avatar changes',
                      button: true,
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          final updatedProfile = Profile(
                            id: widget.profile.id,
                            name: widget.profile.name,
                            age: widget.profile.age,
                            avatar: _selectedAvatar,
                            avatarType: _selectedAvatarType,
                            createdAt: widget.profile.createdAt,
                          );
                          context
                              .read<ProfileProvider>()
                              .updateProfile(updatedProfile);
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Save',
                          style: TextStyle(
                            color: const Color(0xFF007AFF),
                            fontSize: fontSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Avatar Selection Section
              Flexible(
                child: Padding(
                  padding: EdgeInsets.all(padding),
                  child: AvatarSelector(
                    currentAvatar: _selectedAvatar,
                    currentAvatarType: _selectedAvatarType,
                    onAvatarSelected: (avatar, avatarType) {
                      setState(() {
                        _selectedAvatar = avatar;
                        _selectedAvatarType = avatarType;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
