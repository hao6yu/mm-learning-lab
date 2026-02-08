import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../models/story.dart';
import '../services/openai_service.dart';
import '../providers/profile_provider.dart';

class CreateStoryScreen extends StatefulWidget {
  final Story? storyToEdit; // If provided, we're editing an existing story

  const CreateStoryScreen({super.key, this.storyToEdit});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _promptController = TextEditingController();

  // Current step in the wizard (0-4)
  int _currentStep = 0;

  String _selectedEmoji = '📝';
  String _selectedCategory = 'Adventure';
  String _selectedDifficulty = 'Easy';
  String _selectedAgeGroup = 'middle';
  bool _isSaving = false;
  bool _isGenerating = false;
  String? _generationError;
  final OpenAIService _openAIService = OpenAIService();

  // Animation controllers for smooth transitions
  late AnimationController _stepAnimationController;
  late Animation<double> _stepAnimation;

  // Simplified emoji options with categories
  final Map<String, List<String>> _emojiCategories = {
    'Animals': ['🐱', '🐶', '🦁', '🐢', '🐘', '🦄', '🐉', '🦊'],
    'Adventure': ['🚀', '🏰', '⛵', '🗺️', '🎈', '🚂', '🏔️', '🏝️'],
    'Magic': ['⭐', '🌟', '🌙', '✨', '🔮', '🧚', '🧙‍♀️', '👑'],
    'Nature': ['🌈', '🌸', '🌺', '🌲', '🌵', '☀️', '🌤️', '❄️'],
  };

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Adventure', 'icon': '🗺️', 'color': Color(0xFFFF6B6B)},
    {'name': 'Animals', 'icon': '🐾', 'color': Color(0xFF4ECDC4)},
    {'name': 'Space', 'icon': '🚀', 'color': Color(0xFF45B7D1)},
    {'name': 'Fantasy', 'icon': '🦄', 'color': Color(0xFF96CEB4)},
    {'name': 'Nature', 'icon': '🌳', 'color': Color(0xFFFECEA8)},
  ];

  final List<Map<String, dynamic>> _difficulties = [
    {
      'name': 'Easy',
      'icon': '😊',
      'description': 'Simple and fun!',
      'color': Color(0xFF4ECDC4)
    },
    {
      'name': 'Medium',
      'icon': '🤔',
      'description': 'A little challenge',
      'color': Color(0xFFFFD93D)
    },
    {
      'name': 'Hard',
      'icon': '🧠',
      'description': 'For smart cookies!',
      'color': Color(0xFFFF6B6B)
    },
  ];

  final Map<String, Map<String, dynamic>> _ageGroups = {
    'young': {
      'label': '3-6 years',
      'icon': '👶',
      'description': 'Little readers'
    },
    'middle': {
      'label': '7-9 years',
      'icon': '🧒',
      'description': 'Growing readers'
    },
    'older': {
      'label': '10-12 years',
      'icon': '👦👧',
      'description': 'Big readers'
    },
  };

  @override
  void initState() {
    super.initState();
    OpenAIService.initialize();

    _stepAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _stepAnimation = CurvedAnimation(
      parent: _stepAnimationController,
      curve: Curves.easeInOut,
    );

    // If editing an existing story, skip to the final step
    if (widget.storyToEdit != null) {
      _currentStep = 4; // Go directly to the writing step
      _titleController.text = widget.storyToEdit!.title;
      _contentController.text = widget.storyToEdit!.content;
      _selectedEmoji = widget.storyToEdit!.emoji;
      _selectedCategory = widget.storyToEdit!.category;
      _selectedDifficulty = widget.storyToEdit!.difficulty;
    }

    _stepAnimationController.forward();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _promptController.dispose();
    _stepAnimationController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 4) {
      setState(() {
        _currentStep++;
      });
      _stepAnimationController.reset();
      _stepAnimationController.forward();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _stepAnimationController.reset();
      _stepAnimationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;
    final isLandscape = screenWidth > screenHeight;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF8FD6FF), Color(0xFFEAF6FF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar with Progress
              _buildAppBar(isTablet, isLandscape),

              // Main Content
              Expanded(
                child: AnimatedBuilder(
                  animation: _stepAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, 20 * (1 - _stepAnimation.value)),
                      child: Opacity(
                        opacity: _stepAnimation.value,
                        child: _buildCurrentStep(isTablet, isLandscape),
                      ),
                    );
                  },
                ),
              ),

              // Navigation Buttons
              _buildNavigationButtons(isTablet, isLandscape),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isTablet, bool isLandscape) {
    final steps = ['Who?', 'What?', 'How?', 'Style', 'Write!'];

    return Container(
      padding: EdgeInsets.all(
          isLandscape ? (isTablet ? 12.0 : 6.0) : (isTablet ? 20.0 : 16.0)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(isTablet ? 24.0 : 20.0),
          bottomRight: Radius.circular(isTablet ? 24.0 : 20.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8.0,
            offset: const Offset(0, 4.0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Row
          Row(
            children: [
              // Back button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF8E6CFF),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x338E6CFF),
                        blurRadius: 8.0,
                        offset: const Offset(0, 4.0),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.all(isTablet ? 12.0 : 10.0),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: isTablet ? 24.0 : 20.0,
                  ),
                ),
              ),

              Expanded(
                child: Center(
                  child: Text(
                    widget.storyToEdit == null
                        ? '✨ Create Your Story'
                        : '✏️ Edit Story',
                    style: TextStyle(
                      fontSize: isLandscape
                          ? (isTablet ? 20.0 : 16.0)
                          : (isTablet ? 24.0 : 20.0),
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF8E6CFF),
                    ),
                  ),
                ),
              ),

              // Save button (only show on final step)
              if (_currentStep == 4)
                _isSaving
                    ? Container(
                        padding: EdgeInsets.all(isTablet ? 12.0 : 10.0),
                        child: SizedBox(
                          width: isTablet ? 24.0 : 20.0,
                          height: isTablet ? 24.0 : 20.0,
                          child: const CircularProgressIndicator(
                            color: Color(0xFF8E6CFF),
                            strokeWidth: 2.0,
                          ),
                        ),
                      )
                    : GestureDetector(
                        onTap: _saveStory,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8E6CFF), Color(0xFF7C4DFF)],
                            ),
                            borderRadius:
                                BorderRadius.circular(isTablet ? 12.0 : 10.0),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8E6CFF)
                                    .withValues(alpha: 0.3),
                                blurRadius: 4.0,
                                offset: const Offset(0, 2.0),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 16.0 : 12.0,
                            vertical: isTablet ? 10.0 : 8.0,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.save_rounded,
                                color: Colors.white,
                                size: isTablet ? 18.0 : 16.0,
                              ),
                              SizedBox(width: isTablet ? 6.0 : 4.0),
                              Text(
                                'Save',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isTablet ? 14.0 : 12.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
              else
                SizedBox(
                    width: isTablet ? 80.0 : 60.0), // Placeholder for alignment
            ],
          ),

          SizedBox(
              height: isLandscape
                  ? (isTablet ? 6.0 : 2.0)
                  : (isTablet ? 16.0 : 12.0)),

          // Progress Indicator
          if (widget.storyToEdit == null) // Only show for new stories
            Row(
              children: List.generate(steps.length, (index) {
                final isActive = index == _currentStep;
                final isCompleted = index < _currentStep;

                return Expanded(
                  child: Container(
                    margin:
                        EdgeInsets.symmetric(horizontal: isTablet ? 4.0 : 2.0),
                    child: Column(
                      children: [
                        Container(
                          height: isTablet ? 8.0 : 6.0,
                          decoration: BoxDecoration(
                            color: isCompleted || isActive
                                ? const Color(0xFF8E6CFF)
                                : Colors.grey.shade300,
                            borderRadius:
                                BorderRadius.circular(isTablet ? 4.0 : 3.0),
                          ),
                        ),
                        SizedBox(height: isTablet ? 8.0 : 6.0),
                        Text(
                          steps[index],
                          style: TextStyle(
                            fontSize: isLandscape
                                ? (isTablet ? 10.0 : 8.0)
                                : (isTablet ? 12.0 : 10.0),
                            fontWeight:
                                isActive ? FontWeight.bold : FontWeight.normal,
                            color: isActive
                                ? const Color(0xFF8E6CFF)
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep(bool isTablet, bool isLandscape) {
    switch (_currentStep) {
      case 0:
        return _buildAgeGroupStep(isTablet, isLandscape);
      case 1:
        return _buildCategoryStep(isTablet, isLandscape);
      case 2:
        return _buildDifficultyStep(isTablet, isLandscape);
      case 3:
        return _buildEmojiStep(isTablet, isLandscape);
      case 4:
        return _buildWritingStep(isTablet, isLandscape);
      default:
        return _buildAgeGroupStep(isTablet, isLandscape);
    }
  }

  Widget _buildAgeGroupStep(bool isTablet, bool isLandscape) {
    return Padding(
      padding: EdgeInsets.all(
          isLandscape ? (isTablet ? 16.0 : 8.0) : (isTablet ? 24.0 : 16.0)),
      child: Column(
        children: [
          SizedBox(
              height: isLandscape
                  ? (isTablet ? 10.0 : 5.0)
                  : (isTablet ? 40.0 : 20.0)),
          Text(
            '👋 Who will read this story?',
            style: TextStyle(
              fontSize: isLandscape
                  ? (isTablet ? 24.0 : 20.0)
                  : (isTablet ? 28.0 : 24.0),
              fontWeight: FontWeight.bold,
              color: const Color(0xFF26324A),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(
              height: isLandscape
                  ? (isTablet ? 8.0 : 4.0)
                  : (isTablet ? 16.0 : 12.0)),
          Text(
            'Choose the age group so we can make it just right!',
            style: TextStyle(
              fontSize: isLandscape
                  ? (isTablet ? 14.0 : 12.0)
                  : (isTablet ? 18.0 : 16.0),
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isTablet ? 40.0 : 30.0),
          Expanded(
            child: ListView(
              children: _ageGroups.entries.map((entry) {
                final isSelected = _selectedAgeGroup == entry.key;
                final ageData = entry.value;

                return Container(
                  margin: EdgeInsets.only(
                      bottom: isLandscape
                          ? (isTablet ? 8.0 : 6.0)
                          : (isTablet ? 16.0 : 12.0)),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedAgeGroup = entry.key;
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.all(isLandscape
                          ? (isTablet ? 16.0 : 12.0)
                          : (isTablet ? 24.0 : 20.0)),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF8E6CFF).withValues(alpha: 0.1)
                            : Colors.white,
                        borderRadius:
                            BorderRadius.circular(isTablet ? 20.0 : 16.0),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF8E6CFF)
                              : Colors.grey.shade300,
                          width: isSelected ? 3.0 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8.0,
                            offset: const Offset(0, 4.0),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Text(
                            ageData['icon'],
                            style: TextStyle(
                                fontSize: isLandscape
                                    ? (isTablet ? 36.0 : 30.0)
                                    : (isTablet ? 48.0 : 40.0)),
                          ),
                          SizedBox(
                              width: isLandscape
                                  ? (isTablet ? 12.0 : 8.0)
                                  : (isTablet ? 20.0 : 16.0)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ageData['label'],
                                  style: TextStyle(
                                    fontSize: isLandscape
                                        ? (isTablet ? 18.0 : 14.0)
                                        : (isTablet ? 22.0 : 18.0),
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF26324A),
                                  ),
                                ),
                                SizedBox(
                                    height: isLandscape
                                        ? (isTablet ? 2.0 : 1.0)
                                        : (isTablet ? 4.0 : 2.0)),
                                Text(
                                  ageData['description'],
                                  style: TextStyle(
                                    fontSize: isLandscape
                                        ? (isTablet ? 12.0 : 10.0)
                                        : (isTablet ? 16.0 : 14.0),
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: const Color(0xFF8E6CFF),
                              size: isTablet ? 32.0 : 28.0,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryStep(bool isTablet, bool isLandscape) {
    return Padding(
      padding: EdgeInsets.all(
          isLandscape ? (isTablet ? 16.0 : 8.0) : (isTablet ? 24.0 : 16.0)),
      child: Column(
        children: [
          SizedBox(
              height: isLandscape
                  ? (isTablet ? 10.0 : 5.0)
                  : (isTablet ? 40.0 : 20.0)),
          Text(
            '🎭 What kind of story?',
            style: TextStyle(
              fontSize: isLandscape
                  ? (isTablet ? 24.0 : 20.0)
                  : (isTablet ? 28.0 : 24.0),
              fontWeight: FontWeight.bold,
              color: const Color(0xFF26324A),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(
              height: isLandscape
                  ? (isTablet ? 8.0 : 4.0)
                  : (isTablet ? 16.0 : 12.0)),
          Text(
            'Pick your favorite type of adventure!',
            style: TextStyle(
              fontSize: isLandscape
                  ? (isTablet ? 14.0 : 12.0)
                  : (isTablet ? 18.0 : 16.0),
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(
              height: isLandscape
                  ? (isTablet ? 15.0 : 8.0)
                  : (isTablet ? 40.0 : 30.0)),
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isTablet ? 3 : 2,
                crossAxisSpacing: isTablet ? 16.0 : 12.0,
                mainAxisSpacing: isTablet ? 16.0 : 12.0,
                childAspectRatio: isTablet ? 1.2 : 1.1,
              ),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category['name'];

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = category['name'];
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? category['color'].withValues(alpha: 0.2)
                          : Colors.white,
                      borderRadius:
                          BorderRadius.circular(isTablet ? 20.0 : 16.0),
                      border: Border.all(
                        color: isSelected
                            ? category['color']
                            : Colors.grey.shade300,
                        width: isSelected ? 3.0 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8.0,
                          offset: const Offset(0, 4.0),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          category['icon'],
                          style: TextStyle(fontSize: isTablet ? 48.0 : 40.0),
                        ),
                        SizedBox(height: isTablet ? 12.0 : 8.0),
                        Text(
                          category['name'],
                          style: TextStyle(
                            fontSize: isTablet ? 18.0 : 16.0,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF26324A),
                          ),
                        ),
                        if (isSelected)
                          Padding(
                            padding: EdgeInsets.only(top: isTablet ? 8.0 : 4.0),
                            child: Icon(
                              Icons.check_circle,
                              color: category['color'],
                              size: isTablet ? 24.0 : 20.0,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyStep(bool isTablet, bool isLandscape) {
    return Padding(
      padding: EdgeInsets.all(
          isLandscape ? (isTablet ? 16.0 : 8.0) : (isTablet ? 24.0 : 16.0)),
      child: Column(
        children: [
          SizedBox(
              height: isLandscape
                  ? (isTablet ? 10.0 : 5.0)
                  : (isTablet ? 40.0 : 20.0)),
          Text(
            '🎯 How challenging?',
            style: TextStyle(
              fontSize: isLandscape
                  ? (isTablet ? 24.0 : 20.0)
                  : (isTablet ? 28.0 : 24.0),
              fontWeight: FontWeight.bold,
              color: const Color(0xFF26324A),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(
              height: isLandscape
                  ? (isTablet ? 8.0 : 4.0)
                  : (isTablet ? 16.0 : 12.0)),
          Text(
            'Choose how tricky you want your story to be!',
            style: TextStyle(
              fontSize: isLandscape
                  ? (isTablet ? 14.0 : 12.0)
                  : (isTablet ? 18.0 : 16.0),
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isTablet ? 40.0 : 30.0),
          Expanded(
            child: ListView(
              children: _difficulties.map((difficulty) {
                final isSelected = _selectedDifficulty == difficulty['name'];

                return Container(
                  margin: EdgeInsets.only(bottom: isTablet ? 16.0 : 12.0),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDifficulty = difficulty['name'];
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.all(isTablet ? 24.0 : 20.0),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? difficulty['color'].withValues(alpha: 0.1)
                            : Colors.white,
                        borderRadius:
                            BorderRadius.circular(isTablet ? 20.0 : 16.0),
                        border: Border.all(
                          color: isSelected
                              ? difficulty['color']
                              : Colors.grey.shade300,
                          width: isSelected ? 3.0 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8.0,
                            offset: const Offset(0, 4.0),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Text(
                            difficulty['icon'],
                            style: TextStyle(fontSize: isTablet ? 48.0 : 40.0),
                          ),
                          SizedBox(width: isTablet ? 20.0 : 16.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  difficulty['name'],
                                  style: TextStyle(
                                    fontSize: isTablet ? 22.0 : 18.0,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF26324A),
                                  ),
                                ),
                                SizedBox(height: isTablet ? 4.0 : 2.0),
                                Text(
                                  difficulty['description'],
                                  style: TextStyle(
                                    fontSize: isTablet ? 16.0 : 14.0,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: difficulty['color'],
                              size: isTablet ? 32.0 : 28.0,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiStep(bool isTablet, bool isLandscape) {
    return Padding(
      padding: EdgeInsets.all(
          isLandscape ? (isTablet ? 16.0 : 8.0) : (isTablet ? 24.0 : 16.0)),
      child: Column(
        children: [
          SizedBox(
              height: isLandscape
                  ? (isTablet ? 10.0 : 5.0)
                  : (isTablet ? 40.0 : 20.0)),
          Text(
            '😊 Pick your story emoji!',
            style: TextStyle(
              fontSize: isLandscape
                  ? (isTablet ? 24.0 : 20.0)
                  : (isTablet ? 28.0 : 24.0),
              fontWeight: FontWeight.bold,
              color: const Color(0xFF26324A),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(
              height: isLandscape
                  ? (isTablet ? 8.0 : 4.0)
                  : (isTablet ? 16.0 : 12.0)),
          Text(
            'This will be your story\'s special symbol!',
            style: TextStyle(
              fontSize: isLandscape
                  ? (isTablet ? 14.0 : 12.0)
                  : (isTablet ? 18.0 : 16.0),
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(
              height: isLandscape
                  ? (isTablet ? 15.0 : 8.0)
                  : (isTablet ? 40.0 : 30.0)),
          Expanded(
            child: ListView(
              children: _emojiCategories.entries.map((entry) {
                return Container(
                  margin: EdgeInsets.only(bottom: isTablet ? 20.0 : 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 8.0 : 4.0),
                        child: Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: isTablet ? 20.0 : 18.0,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF26324A),
                          ),
                        ),
                      ),
                      SizedBox(height: isTablet ? 12.0 : 8.0),
                      SizedBox(
                        height: isTablet ? 80.0 : 70.0,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: entry.value.length,
                          itemBuilder: (context, index) {
                            final emoji = entry.value[index];
                            final isSelected = emoji == _selectedEmoji;

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedEmoji = emoji;
                                });
                              },
                              child: Container(
                                width: isTablet ? 70.0 : 60.0,
                                margin: EdgeInsets.only(
                                    right: isTablet ? 8.0 : 6.0),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF8E6CFF)
                                          .withValues(alpha: 0.2)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(
                                      isTablet ? 16.0 : 12.0),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF8E6CFF)
                                        : Colors.grey.shade300,
                                    width: isSelected ? 3.0 : 1.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 4.0,
                                      offset: const Offset(0, 2.0),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    emoji,
                                    style: TextStyle(
                                        fontSize: isTablet ? 36.0 : 30.0),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWritingStep(bool isTablet, bool isLandscape) {
    return Form(
        key: _formKey,
        child: Padding(
          padding: EdgeInsets.all(
              isLandscape ? (isTablet ? 16.0 : 8.0) : (isTablet ? 24.0 : 16.0)),
          child: SingleChildScrollView(
            child: Column(
              children: [
                // AI Helper Section
                if (widget.storyToEdit == null)
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.only(
                        bottom: isLandscape
                            ? (isTablet ? 8.0 : 6.0)
                            : (isTablet ? 20.0 : 16.0)),
                    padding: EdgeInsets.all(isLandscape
                        ? (isTablet ? 8.0 : 6.0)
                        : (isTablet ? 20.0 : 16.0)),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF8E6CFF).withValues(alpha: 0.1),
                          const Color(0xFF3ED6C1).withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius:
                          BorderRadius.circular(isTablet ? 20.0 : 16.0),
                      border: Border.all(
                          color:
                              const Color(0xFF8E6CFF).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              '🤖',
                              style: TextStyle(
                                  fontSize: isLandscape
                                      ? (isTablet ? 24.0 : 20.0)
                                      : (isTablet ? 32.0 : 28.0)),
                            ),
                            SizedBox(
                                width: isLandscape
                                    ? (isTablet ? 8.0 : 6.0)
                                    : (isTablet ? 12.0 : 8.0)),
                            Expanded(
                              child: Text(
                                'AI Story Helper',
                                style: TextStyle(
                                  fontSize: isLandscape
                                      ? (isTablet ? 16.0 : 14.0)
                                      : (isTablet ? 20.0 : 18.0),
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF8E6CFF),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                            height: isLandscape
                                ? (isTablet ? 8.0 : 6.0)
                                : (isTablet ? 16.0 : 12.0)),
                        TextFormField(
                          controller: _promptController,
                          decoration: InputDecoration(
                            hintText:
                                'Tell me your story idea! (like "a cat who loves pizza")',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(isTablet ? 12.0 : 10.0),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding:
                                EdgeInsets.all(isTablet ? 16.0 : 12.0),
                          ),
                          style: TextStyle(fontSize: isTablet ? 16.0 : 14.0),
                        ),
                        SizedBox(
                            height: isLandscape
                                ? (isTablet ? 8.0 : 6.0)
                                : (isTablet ? 16.0 : 12.0)),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                _isGenerating ? null : _generateFullStory,
                            icon: Icon(Icons.auto_awesome,
                                size: isTablet ? 24.0 : 20.0),
                            label: Text(
                              '✨ Create My Story!',
                              style: TextStyle(
                                fontSize: isTablet ? 18.0 : 16.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8E6CFF),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                vertical: isLandscape
                                    ? (isTablet ? 10.0 : 8.0)
                                    : (isTablet ? 16.0 : 14.0),
                                horizontal: isLandscape
                                    ? (isTablet ? 16.0 : 12.0)
                                    : (isTablet ? 24.0 : 20.0),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    isTablet ? 16.0 : 12.0),
                              ),
                              elevation: 4.0,
                            ),
                          ),
                        ),
                        if (_isGenerating)
                          Padding(
                            padding:
                                EdgeInsets.only(top: isTablet ? 16.0 : 12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: isTablet ? 20.0 : 16.0,
                                  height: isTablet ? 20.0 : 16.0,
                                  child: const CircularProgressIndicator(
                                      strokeWidth: 2.0),
                                ),
                                SizedBox(width: isTablet ? 12.0 : 8.0),
                                Text(
                                  'Creating magic...',
                                  style: TextStyle(
                                    fontSize: isTablet ? 14.0 : 12.0,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_generationError != null)
                          Padding(
                            padding:
                                EdgeInsets.only(top: isTablet ? 12.0 : 8.0),
                            child: Container(
                              padding: EdgeInsets.all(isTablet ? 12.0 : 8.0),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius:
                                    BorderRadius.circular(isTablet ? 8.0 : 6.0),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Text(
                                _generationError!,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: isTablet ? 14.0 : 12.0,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                // Title Field
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: '📖 Story Title',
                    hintText: 'What\'s your story called?',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(isTablet ? 12.0 : 10.0),
                    ),
                    contentPadding: EdgeInsets.all(isTablet ? 16.0 : 14.0),
                  ),
                  style: TextStyle(fontSize: isTablet ? 18.0 : 16.0),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Your story needs a title!';
                    }
                    return null;
                  },
                ),

                SizedBox(height: isTablet ? 16.0 : 12.0),

                // Content Field
                SizedBox(
                  height: isLandscape ? 120.0 : 200.0,
                  child: TextFormField(
                    controller: _contentController,
                    decoration: InputDecoration(
                      labelText: '✍️ Write Your Story',
                      hintText: 'Once upon a time...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(isTablet ? 12.0 : 10.0),
                      ),
                      contentPadding: EdgeInsets.all(isTablet ? 16.0 : 14.0),
                      alignLabelWithHint: true,
                    ),
                    style: TextStyle(fontSize: isTablet ? 16.0 : 14.0),
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Don\'t forget to write your story!';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ),
        ));
  }

  Widget _buildNavigationButtons(bool isTablet, bool isLandscape) {
    return Container(
      padding: EdgeInsets.all(
          isLandscape ? (isTablet ? 12.0 : 8.0) : (isTablet ? 24.0 : 16.0)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isTablet ? 24.0 : 20.0),
          topRight: Radius.circular(isTablet ? 24.0 : 20.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8.0,
            offset: const Offset(0, -4.0),
          ),
        ],
      ),
      child: Row(
        children: [
          // Previous button
          if (_currentStep > 0 && widget.storyToEdit == null)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _previousStep,
                icon: Icon(Icons.arrow_back,
                    size: isLandscape
                        ? (isTablet ? 16.0 : 14.0)
                        : (isTablet ? 20.0 : 18.0)),
                label: Text(
                  'Back',
                  style: TextStyle(
                      fontSize: isLandscape
                          ? (isTablet ? 12.0 : 10.0)
                          : (isTablet ? 16.0 : 14.0)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade300,
                  foregroundColor: Colors.grey.shade700,
                  padding: EdgeInsets.symmetric(
                      vertical: isLandscape
                          ? (isTablet ? 10.0 : 8.0)
                          : (isTablet ? 16.0 : 14.0)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(isTablet ? 12.0 : 10.0),
                  ),
                ),
              ),
            ),

          if (_currentStep > 0 &&
              widget.storyToEdit == null &&
              _currentStep < 4)
            SizedBox(width: isTablet ? 16.0 : 12.0),

          // Next button
          if (_currentStep < 4 && widget.storyToEdit == null)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _nextStep,
                icon: Icon(Icons.arrow_forward,
                    size: isLandscape
                        ? (isTablet ? 16.0 : 14.0)
                        : (isTablet ? 20.0 : 18.0)),
                label: Text(
                  'Next',
                  style: TextStyle(
                      fontSize: isLandscape
                          ? (isTablet ? 12.0 : 10.0)
                          : (isTablet ? 16.0 : 14.0)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8E6CFF),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                      vertical: isLandscape
                          ? (isTablet ? 10.0 : 8.0)
                          : (isTablet ? 16.0 : 14.0)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(isTablet ? 12.0 : 10.0),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Generate a complete story with title and content using AI
  Future<void> _generateFullStory() async {
    setState(() {
      _isGenerating = true;
      _generationError = null;
    });

    try {
      // Build a comprehensive prompt based on all selections
      String prompt = 'Create a complete children\'s story';

      if (_promptController.text.isNotEmpty) {
        prompt += ' about ${_promptController.text}';
      }

      // Add category context
      prompt += ' in the $_selectedCategory category';

      // Add difficulty context
      prompt += ' with ${_selectedDifficulty.toLowerCase()} difficulty level';

      // Add age group context
      final ageData = _ageGroups[_selectedAgeGroup];
      if (ageData != null) {
        prompt +=
            ' suitable for ${ageData['label']} (${ageData['description']})';
      }

      final storyData = await _openAIService.generateStory(
        ageGroup: _selectedAgeGroup,
        prompt: prompt,
      );

      if (!mounted) return;
      if (storyData != null &&
          storyData['title'] != null &&
          storyData['content'] != null) {
        setState(() {
          // Always update both title and content
          _titleController.text = storyData['title'];
          _contentController.text = storyData['content'];

          // Update emoji if provided and it's in our available options
          if (storyData['emoji'] != null) {
            final emoji = storyData['emoji'].toString();
            final allEmojis =
                _emojiCategories.values.expand((list) => list).toList();
            if (allEmojis.contains(emoji)) {
              _selectedEmoji = emoji;
            }
          }
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Text('🎉'),
                SizedBox(width: 8),
                Text('Your story is ready! You can edit it if you want.'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() {
          _generationError =
              'Couldn\'t create a complete story right now. Try writing your own or check your internet connection!';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generationError =
            'Oops! Something went wrong. Please check your internet connection and try again!';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _saveStory() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      try {
        final databaseService = DatabaseService();
        final selectedProfileId =
            context.read<ProfileProvider>().selectedProfileId;
        if (selectedProfileId == null) {
          throw Exception('No profile selected.');
        }

        if (widget.storyToEdit == null) {
          // Creating a new story
          final story = Story(
            title: _titleController.text,
            content: _contentController.text,
            emoji: _selectedEmoji,
            category: _selectedCategory,
            difficulty: _selectedDifficulty,
            wordOfDay: null,
            isUserCreated: true,
            profileId: selectedProfileId,
          );

          await databaseService.insertStory(story);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Text('🎉'),
                  SizedBox(width: 8),
                  Text('Your story is saved!'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // Updating an existing story
          final updatedStory = Story(
            id: widget.storyToEdit!.id,
            title: _titleController.text,
            content: _contentController.text,
            emoji: _selectedEmoji,
            category: _selectedCategory,
            difficulty: _selectedDifficulty,
            wordOfDay: widget.storyToEdit!.wordOfDay,
            isUserCreated: true,
            audioPath: widget.storyToEdit!.audioPath,
            profileId: selectedProfileId,
          );

          await databaseService.updateStory(
            updatedStory,
            profileId: selectedProfileId,
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Text('✅'),
                  SizedBox(width: 8),
                  Text('Story updated!'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        }

        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Text('😞'),
                SizedBox(width: 8),
                Text('Oops! Couldn\'t save. Try again!'),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    }
  }
}
