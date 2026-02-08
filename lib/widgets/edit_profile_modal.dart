import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../models/profile.dart';
import 'avatar_selector.dart';

class EditProfileModal extends StatefulWidget {
  final Profile profile;

  const EditProfileModal({super.key, required this.profile});

  @override
  State<EditProfileModal> createState() => _EditProfileModalState();
}

class _EditProfileModalState extends State<EditProfileModal> {
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  late String _selectedAvatar;
  late String _selectedAvatarType;

  // Validation state
  bool _nameError = false;
  bool _ageError = false;
  String _nameErrorMessage = '';
  String _ageErrorMessage = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _ageController = TextEditingController(text: widget.profile.age.toString());
    _selectedAvatar = widget.profile.avatar;
    _selectedAvatarType = widget.profile.avatarType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _validateAndSave() {
    final name = _nameController.text.trim();
    final ageText = _ageController.text.trim();
    final age = int.tryParse(ageText);

    setState(() {
      // Reset errors
      _nameError = false;
      _ageError = false;
      _nameErrorMessage = '';
      _ageErrorMessage = '';

      // Validate name
      if (name.isEmpty) {
        _nameError = true;
        _nameErrorMessage = 'Please enter a name';
      } else if (name.length < 2) {
        _nameError = true;
        _nameErrorMessage = 'Name must be at least 2 characters';
      }

      // Validate age
      if (ageText.isEmpty) {
        _ageError = true;
        _ageErrorMessage = 'Please enter an age';
      } else if (age == null) {
        _ageError = true;
        _ageErrorMessage = 'Please enter a valid number';
      } else if (age < 1 || age > 99) {
        _ageError = true;
        _ageErrorMessage = 'Age must be between 1 and 99';
      }
    });

    // If no errors, save the profile
    if (!_nameError && !_ageError) {
      final updatedProfile = Profile(
        id: widget.profile.id,
        name: name,
        age: age!,
        avatar: _selectedAvatar,
        avatarType: _selectedAvatarType,
        createdAt: widget.profile.createdAt,
      );
      context.read<ProfileProvider>().updateProfile(updatedProfile);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;

    // Responsive sizing
    final horizontalMargin = isTablet ? 48.0 : 24.0;
    final borderRadius = isTablet ? 24.0 : 20.0;
    final padding = isTablet ? 24.0 : 20.0;
    final titleFontSize = isTablet ? 20.0 : 18.0;
    final buttonFontSize = isTablet ? 18.0 : 16.0;

    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
          constraints: BoxConstraints(
            maxHeight: screenHeight * 0.85, // Use percentage of screen height
            maxWidth: isTablet ? 500.0 : double.infinity,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: padding, vertical: padding * 0.75),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    border: const Border(
                      bottom: BorderSide(color: Color(0xFFE9ECEF), width: 1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Cancel button
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: buttonFontSize,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      // Title
                      Text(
                        'Update Your Profile',
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2E7D5B),
                        ),
                      ),
                      // Save button
                      GestureDetector(
                        onTap: _validateAndSave,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4CAF50)
                                    .withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            'Save',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: buttonFontSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Scrollable content
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(padding),
                    child: Column(
                      children: [
                        // Avatar Selection Section
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F8F0),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE8F5E8)),
                          ),
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

                        SizedBox(height: padding),

                        // Name and Age Section
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF9E6),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFFE082)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Section title
                              Row(
                                children: [
                                  const Icon(
                                    Icons.edit,
                                    color: Color(0xFFFF9800),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Update your info!',
                                    style: TextStyle(
                                      fontSize: isTablet ? 16.0 : 14.0,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFFF9800),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Name Field
                              _buildKidFriendlyField(
                                label: 'What\'s your name?',
                                controller: _nameController,
                                placeholder: 'Type your name here...',
                                icon: Icons.face,
                                hasError: _nameError,
                                errorMessage: _nameErrorMessage,
                                maxLength: 12,
                                isTablet: isTablet,
                              ),

                              const SizedBox(height: 16),

                              // Age Field
                              _buildKidFriendlyField(
                                label: 'How old are you?',
                                controller: _ageController,
                                placeholder: 'Your age',
                                icon: Icons.cake,
                                hasError: _ageError,
                                errorMessage: _ageErrorMessage,
                                maxLength: 2,
                                keyboardType: TextInputType.number,
                                width: 100,
                                isTablet: isTablet,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKidFriendlyField({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    required IconData icon,
    required bool hasError,
    required String errorMessage,
    required int maxLength,
    required bool isTablet,
    TextInputType? keyboardType,
    double? width,
  }) {
    final fieldFontSize = isTablet ? 16.0 : 14.0;
    final labelFontSize = isTablet ? 14.0 : 12.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with icon
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: const Color(0xFF666666),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: labelFontSize,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF666666),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Input field
        SizedBox(
          width: width,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLength: maxLength,
            style: TextStyle(
              fontSize: fieldFontSize,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: fieldFontSize,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: hasError ? const Color(0xFFFF6B6B) : Colors.grey[300]!,
                  width: hasError ? 2.0 : 1.0,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: hasError ? const Color(0xFFFF6B6B) : Colors.grey[300]!,
                  width: hasError ? 2.0 : 1.0,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: hasError
                      ? const Color(0xFFFF6B6B)
                      : const Color(0xFF4CAF50),
                  width: 2.0,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFFF6B6B),
                  width: 2.0,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFFF6B6B),
                  width: 2.0,
                ),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              counterText: '', // Hide character counter
              suffixIcon: hasError
                  ? const Icon(
                      Icons.error_outline,
                      color: Color(0xFFFF6B6B),
                      size: 20,
                    )
                  : null,
            ),
            onChanged: (value) {
              // Clear errors when user starts typing
              if (hasError) {
                setState(() {
                  if (controller == _nameController) {
                    _nameError = false;
                    _nameErrorMessage = '';
                  } else {
                    _ageError = false;
                    _ageErrorMessage = '';
                  }
                });
              }
            },
          ),
        ),

        // Error message (compact)
        if (hasError) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: Color(0xFFFF6B6B),
                size: 12,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  errorMessage,
                  style: TextStyle(
                    color: const Color(0xFFFF6B6B),
                    fontSize: labelFontSize - 1,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
