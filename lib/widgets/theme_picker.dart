import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../services/theme_service.dart';

/// A simple theme picker widget showing available themes as cards
class ThemePicker extends StatelessWidget {
  final bool isTablet;
  
  const ThemePicker({
    super.key,
    this.isTablet = false,
  });

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final currentTheme = themeService.currentTheme;
    final themes = themeService.availableThemes;
    
    final cardSize = isTablet ? 100.0 : 90.0;
    final fontSize = isTablet ? 12.0 : 10.0;
    final emojiSize = isTablet ? 28.0 : 24.0;
    final spacing = isTablet ? 16.0 : 12.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: spacing),
          child: Row(
            children: [
              Icon(
                Icons.palette_outlined,
                size: isTablet ? 24.0 : 20.0,
                color: themeService.config.headingColor,
              ),
              SizedBox(width: 8),
              Text(
                'App Theme',
                style: TextStyle(
                  fontSize: isTablet ? 18.0 : 16.0,
                  fontWeight: FontWeight.bold,
                  color: themeService.config.headingColor,
                ),
              ),
            ],
          ),
        ),
        
        Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: themes.map((theme) {
            final isSelected = getThemeConfig(currentTheme) == theme;
            final themeType = theme == valentineTheme 
                ? AppThemeType.valentine 
                : AppThemeType.standard;
            
            return GestureDetector(
              onTap: () => themeService.setTheme(themeType),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: cardSize,
                height: cardSize,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: theme.screenGradient,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected 
                        ? theme.primaryColor 
                        : Colors.white.withValues(alpha: 0.5),
                    width: isSelected ? 3.0 : 1.5,
                  ),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: theme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ] : null,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          theme.emoji,
                          style: TextStyle(fontSize: emojiSize),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          theme.name,
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.w600,
                            color: theme.headingColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (isSelected) ...[
                          const SizedBox(height: 2),
                          Icon(
                            Icons.check_circle,
                            size: isTablet ? 14.0 : 12.0,
                            color: theme.primaryColor,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        
        // Auto-seasonal toggle
        Padding(
          padding: EdgeInsets.only(top: spacing),
          child: Row(
            children: [
              Switch.adaptive(
                value: themeService.autoSeasonal,
                onChanged: (value) => themeService.setAutoSeasonal(value),
                activeTrackColor: themeService.config.primaryColor.withValues(alpha: 0.5),
                activeThumbColor: themeService.config.primaryColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Auto-switch for holidays',
                  style: TextStyle(
                    fontSize: fontSize,
                    color: themeService.config.subtitleColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Compact theme button for header/toolbar
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    
    return IconButton(
      onPressed: () => _showThemePicker(context),
      icon: Text(
        themeService.config.emoji,
        style: const TextStyle(fontSize: 24),
      ),
      tooltip: 'Change theme',
    );
  }
  
  void _showThemePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24 + MediaQuery.of(context).viewPadding.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const ThemePicker(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
