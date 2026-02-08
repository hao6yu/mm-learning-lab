import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';

class AvatarSelector extends StatefulWidget {
  final String currentAvatar;
  final String currentAvatarType;
  final Function(String avatar, String avatarType) onAvatarSelected;

  const AvatarSelector({
    super.key,
    required this.currentAvatar,
    required this.currentAvatarType,
    required this.onAvatarSelected,
  });

  @override
  State<AvatarSelector> createState() => _AvatarSelectorState();
}

class _AvatarSelectorState extends State<AvatarSelector> {
  late String _selectedAvatar;
  late String _selectedAvatarType;
  final ImagePicker _picker = ImagePicker();

  // All available avatars organized for horizontal scrolling
  final List<String> _allAvatars = [
    '👦',
    '👧',
    '🧒',
    '👶',
    '🐶',
    '🐱',
    '🐰',
    '🦁',
    '🐸',
    '🐧',
    '🦄',
    '🌟',
    '🎈',
    '🚀',
    '⚽',
    '🎨',
    '🐻',
    '🐨',
    '🐯',
    '🦊',
    '🐼',
    '🐵',
    '🦝',
    '🐹',
    '🌈',
    '⭐',
    '🎯',
    '🎪',
    '🎭',
    '📚',
    '🎮',
    '🚗'
  ];

  // Organize avatars into columns for horizontal scrolling (3 rows per column)
  List<List<String>> get _avatarColumns {
    List<List<String>> columns = [];
    for (int i = 0; i < _allAvatars.length; i += 3) {
      columns.add(_allAvatars.skip(i).take(3).toList());
    }
    return columns;
  }

  @override
  void initState() {
    super.initState();
    _selectedAvatar = widget.currentAvatar;
    _selectedAvatarType = widget.currentAvatarType;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 400,
        maxHeight: 400,
      );

      if (image != null) {
        final croppedFile = await _cropImage(image.path);
        if (croppedFile != null) {
          final savedPath = await _saveImageToAppDirectory(croppedFile.path);
          setState(() {
            _selectedAvatar = savedPath;
            _selectedAvatarType = 'photo';
          });
          widget.onAvatarSelected(_selectedAvatar, _selectedAvatarType);
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      // Show error to user
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: const Text('Failed to select image. Please try again.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<CroppedFile?> _cropImage(String imagePath) async {
    return await ImageCropper().cropImage(
      sourcePath: imagePath,
      uiSettings: [
        IOSUiSettings(
          title: 'Crop Profile Photo',
          doneButtonTitle: 'Done',
          cancelButtonTitle: 'Cancel',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
        ),
        AndroidUiSettings(
          toolbarTitle: 'Crop Profile Photo',
          toolbarColor: const Color(0xFF43C465),
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
          initAspectRatio: CropAspectRatioPreset.square,
          hideBottomControls: false,
        ),
      ],
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressQuality: 85,
      maxWidth: 200,
      maxHeight: 200,
    );
  }

  Future<String> _saveImageToAppDirectory(String imagePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final profileImagesDir = Directory('${appDir.path}/profile_images');

    if (!await profileImagesDir.exists()) {
      await profileImagesDir.create(recursive: true);
    }

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savedImage = File('${profileImagesDir.path}/$fileName');

    await File(imagePath).copy(savedImage.path);
    return savedImage.path;
  }

  void _showImageSourceDialog() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Choose Profile Photo'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.camera, size: isTablet ? 22.0 : 20.0),
                SizedBox(width: isTablet ? 10.0 : 8.0),
                const Text('Take Photo'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.photo, size: isTablet ? 22.0 : 20.0),
                SizedBox(width: isTablet ? 10.0 : 8.0),
                const Text('Choose from Gallery'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    // Responsive sizing - reduced to prevent overflow
    final titleFontSize = isTablet ? 18.0 : 16.0;
    final buttonFontSize = isTablet ? 16.0 : 14.0;
    final iconSize = isTablet ? 18.0 : 16.0;
    final photoPreviewSize = isTablet ? 70.0 : 60.0;
    final borderWidth = isTablet ? 4.0 : 3.0;
    final carouselHeight = isTablet ? 150.0 : 130.0; // Further reduced height
    final horizontalMargin = isTablet ? 24.0 : 20.0;
    final verticalPadding = isTablet ? 10.0 : 8.0;
    final horizontalPadding = isTablet ? 18.0 : 16.0;
    final borderRadius = isTablet ? 14.0 : 12.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Section Title
        Text(
          'Choose Avatar',
          style: TextStyle(
            fontSize: titleFontSize,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: isTablet ? 6.0 : 4.0), // Reduced spacing

        // Photo Option Button
        Container(
          width: double.infinity,
          margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
          child: Semantics(
            label: _selectedAvatarType == 'photo'
                ? 'Change profile photo'
                : 'Use your own photo as avatar',
            button: true,
            child: CupertinoButton(
              padding: EdgeInsets.symmetric(
                  vertical: verticalPadding, horizontal: horizontalPadding),
              color: _selectedAvatarType == 'photo'
                  ? const Color(0xFF43C465).withValues(alpha: 0.1)
                  : const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(borderRadius),
              onPressed: _showImageSourceDialog,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.camera_fill,
                    size: iconSize,
                    color: _selectedAvatarType == 'photo'
                        ? const Color(0xFF43C465)
                        : const Color(0xFF007AFF),
                    semanticLabel: 'Camera icon',
                  ),
                  SizedBox(width: isTablet ? 10.0 : 8.0),
                  Text(
                    _selectedAvatarType == 'photo'
                        ? 'Change Photo'
                        : 'Use Your Photo',
                    style: TextStyle(
                      fontSize: buttonFontSize,
                      color: _selectedAvatarType == 'photo'
                          ? const Color(0xFF43C465)
                          : const Color(0xFF007AFF),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        SizedBox(height: isTablet ? 8.0 : 6.0), // Reduced spacing

        // Current Selection Preview
        if (_selectedAvatarType == 'photo' && _selectedAvatar.isNotEmpty)
          Container(
            width: photoPreviewSize,
            height: photoPreviewSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF43C465),
                width: borderWidth,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF43C465).withValues(alpha: 0.3),
                  blurRadius: isTablet ? 10.0 : 8.0,
                  offset: Offset(0, isTablet ? 3.0 : 2.0),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.file(
                File(_selectedAvatar),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFFFFE066),
                    child: Icon(
                      CupertinoIcons.person,
                      size: isTablet ? 35.0 : 30.0,
                      color: Colors.black54,
                    ),
                  );
                },
              ),
            ),
          ),

        SizedBox(height: isTablet ? 6.0 : 4.0), // Reduced spacing

        // Divider with "OR" text
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey[300])),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isTablet ? 14.0 : 12.0),
              child: Text(
                'OR',
                style: TextStyle(
                  fontSize: isTablet ? 14.0 : 12.0,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey[300])),
          ],
        ),

        SizedBox(height: isTablet ? 6.0 : 4.0), // Reduced spacing

        // Emoji selection hint
        Semantics(
          label: 'Swipe horizontally to see more emoji options',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.left_chevron,
                size: isTablet ? 14.0 : 12.0,
                color: Colors.grey[400],
                semanticLabel: 'Swipe left',
              ),
              SizedBox(width: isTablet ? 6.0 : 4.0),
              Text(
                'Swipe to see more emojis',
                style: TextStyle(
                  fontSize: isTablet ? 14.0 : 12.0,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
              SizedBox(width: isTablet ? 6.0 : 4.0),
              Icon(
                CupertinoIcons.right_chevron,
                size: isTablet ? 14.0 : 12.0,
                color: Colors.grey[400],
                semanticLabel: 'Swipe right',
              ),
            ],
          ),
        ),

        SizedBox(height: isTablet ? 4.0 : 2.0), // Reduced spacing

        // Horizontal scrolling emoji carousel (3 rows)
        Semantics(
          label: 'Emoji avatar selection grid',
          child: SizedBox(
            height: carouselHeight,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _avatarColumns.map((column) {
                  return Padding(
                    padding: EdgeInsets.only(right: isTablet ? 12.0 : 10.0),
                    child: Column(
                      children: column.asMap().entries.map((entry) {
                        int index = entry.key;
                        String avatar = entry.value;
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index < column.length - 1
                                ? (isTablet ? 6.0 : 4.0)
                                : 0, // Further reduced spacing
                          ),
                          child: _AvatarChoice(
                            avatar: avatar,
                            isSelected: _selectedAvatarType == 'emoji' &&
                                _selectedAvatar == avatar,
                            onTap: () {
                              setState(() {
                                _selectedAvatar = avatar;
                                _selectedAvatarType = 'emoji';
                              });
                              widget.onAvatarSelected(
                                  _selectedAvatar, _selectedAvatarType);
                            },
                            isTablet: isTablet,
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AvatarChoice extends StatelessWidget {
  final String avatar;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isTablet;

  const _AvatarChoice({
    required this.avatar,
    required this.isSelected,
    required this.onTap,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    final size = isTablet ? 46.0 : 40.0; // Further reduced size
    final borderWidth = isTablet ? 4.0 : 3.0;
    final fontSize = isTablet ? 24.0 : 20.0; // Further reduced font size
    final blurRadius = isTablet ? 10.0 : 8.0;
    final offset = isTablet ? 3.0 : 2.0;

    return Semantics(
      label: 'Avatar option: $avatar${isSelected ? ', selected' : ''}',
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFFFFE066),
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? const Color(0xFF43C465) : Colors.transparent,
              width: borderWidth,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF43C465).withValues(alpha: 0.3),
                      blurRadius: blurRadius,
                      offset: Offset(0, offset),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              avatar,
              style: TextStyle(fontSize: fontSize),
              semanticsLabel: 'Emoji $avatar',
            ),
          ),
        ),
      ),
    );
  }
}
