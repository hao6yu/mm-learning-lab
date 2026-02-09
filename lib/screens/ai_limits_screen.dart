import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/profile.dart';
import '../providers/profile_provider.dart';
import '../services/ai_parental_control_service.dart';
import '../services/ai_usage_limit_service.dart';
import '../services/database_service.dart';
import '../services/subscription_service.dart';

class AiLimitsScreenData {
  final String? profileName;
  final AiQuotaCheckResult chatQuota;
  final AiQuotaCheckResult storyQuota;
  final AiCallAllowance callAllowance;
  final AiParentalControls controls;

  const AiLimitsScreenData({
    required this.profileName,
    required this.chatQuota,
    required this.storyQuota,
    required this.callAllowance,
    required this.controls,
  });
}

typedef AiLimitsDataLoader = Future<AiLimitsScreenData> Function(
  int profileId,
  bool isPremium,
);
typedef AiLimitsControlSaver = Future<void> Function(
  int profileId,
  AiParentalControls controls,
);

class AiLimitsScreen extends StatefulWidget {
  const AiLimitsScreen({
    super.key,
    this.loadData,
    this.saveControls,
  });

  final AiLimitsDataLoader? loadData;
  final AiLimitsControlSaver? saveControls;

  @override
  State<AiLimitsScreen> createState() => _AiLimitsScreenState();
}

class _AiLimitsScreenState extends State<AiLimitsScreen> {
  final AIUsageLimitService _usageService = AIUsageLimitService();
  final AiParentalControlService _parentalControlService =
      AiParentalControlService();
  final DatabaseService _databaseService = DatabaseService();

  int? _profileId;
  String? _profileName;
  bool _isPremium = false;
  bool _isLoading = false;
  bool _isSavingControls = false;

  AiQuotaCheckResult? _chatQuota;
  AiQuotaCheckResult? _storyQuota;
  AiCallAllowance? _callAllowance;
  AiParentalControls _controls = const AiParentalControls.defaults();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextProfileId = context.read<ProfileProvider>().selectedProfileId;
    final nextPremium = context.read<SubscriptionService>().isSubscribed;
    if (_profileId == nextProfileId && _isPremium == nextPremium) {
      return;
    }

    _profileId = nextProfileId;
    _isPremium = nextPremium;
    _reload();
  }

  Future<void> _reload() async {
    final profileId = _profileId;
    if (profileId == null) {
      setState(() {
        _isLoading = false;
        _profileName = null;
        _chatQuota = null;
        _storyQuota = null;
        _callAllowance = null;
        _controls = const AiParentalControls.defaults();
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final data = widget.loadData != null
          ? await widget.loadData!(profileId, _isPremium)
          : await _loadDataFromServices(
              profileId: profileId,
              isPremium: _isPremium,
            );

      if (!mounted) return;
      setState(() {
        _profileName = data.profileName;
        _chatQuota = data.chatQuota;
        _storyQuota = data.storyQuota;
        _callAllowance = data.callAllowance;
        _controls = data.controls;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load AI limits. $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<AiLimitsScreenData> _loadDataFromServices({
    required int profileId,
    required bool isPremium,
  }) async {
    final results = await Future.wait<dynamic>([
      _databaseService.getProfile(profileId),
      _usageService.getCountQuotaStatus(
        profileId: profileId,
        isPremium: isPremium,
        feature: AiCountFeature.chatMessage,
      ),
      _usageService.getCountQuotaStatus(
        profileId: profileId,
        isPremium: isPremium,
        feature: AiCountFeature.storyGeneration,
      ),
      _usageService.getVoiceCallAllowance(
        profileId: profileId,
        isPremium: isPremium,
      ),
      _parentalControlService.getControls(profileId),
    ]);

    final profile = results[0] as Profile?;
    return AiLimitsScreenData(
      profileName: profile?.name,
      chatQuota: results[1] as AiQuotaCheckResult,
      storyQuota: results[2] as AiQuotaCheckResult,
      callAllowance: results[3] as AiCallAllowance,
      controls: results[4] as AiParentalControls,
    );
  }

  Future<void> _saveControls(AiParentalControls next) async {
    final profileId = _profileId;
    if (profileId == null || _isSavingControls) return;
    final previous = _controls;
    setState(() {
      _controls = next;
      _isSavingControls = true;
    });
    try {
      if (widget.saveControls != null) {
        await widget.saveControls!(profileId, next);
      } else {
        await _parentalControlService.saveControls(profileId, next);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _controls = previous;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save AI limits. $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingControls = false;
        });
      }
    }
  }

  String _hourLabel(int hour) {
    final normalized = hour % 12 == 0 ? 12 : hour % 12;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    return '$normalized $suffix';
  }

  Widget _buildQuotaRow({
    required String label,
    required int used,
    required int limit,
    required Color color,
  }) {
    final safeLimit = limit <= 0 ? 1 : limit;
    final ratio = (used / safeLimit).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF355C7D),
                ),
              ),
            ),
            Text(
              '$used / $limit',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF355C7D),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildUsageCard() {
    final chat = _chatQuota;
    final story = _storyQuota;
    final call = _callAllowance;
    if (chat == null || story == null || call == null) {
      return const SizedBox.shrink();
    }

    final parentOverrideSeconds = _controls.maxCallMinutesOverride == null
        ? null
        : _controls.maxCallMinutesOverride! * 60;
    final perSessionCap = parentOverrideSeconds == null
        ? call.perCallLimitSeconds
        : math.min(call.perCallLimitSeconds, parentOverrideSeconds);
    final nextCallCap =
        math.min(call.remainingForThisCallSeconds, perSessionCap);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI Usage',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF355C7D),
            ),
          ),
          const SizedBox(height: 10),
          _buildQuotaRow(
            label: 'Chat Today',
            used: chat.usedToday,
            limit: chat.dailyLimit,
            color: const Color(0xFF4ECDC4),
          ),
          const SizedBox(height: 10),
          _buildQuotaRow(
            label: 'Chat This Week',
            used: chat.usedThisWeek,
            limit: chat.weeklyLimit,
            color: const Color(0xFF45B7D1),
          ),
          const SizedBox(height: 14),
          _buildQuotaRow(
            label: 'Stories Today',
            used: story.usedToday,
            limit: story.dailyLimit,
            color: const Color(0xFFFF9F43),
          ),
          const SizedBox(height: 10),
          _buildQuotaRow(
            label: 'Stories This Week',
            used: story.usedThisWeek,
            limit: story.weeklyLimit,
            color: const Color(0xFFFF6B6B),
          ),
          const SizedBox(height: 14),
          _buildQuotaRow(
            label: 'Call Minutes Today',
            used: call.usedTodaySeconds ~/ 60,
            limit: (call.usedTodaySeconds + call.remainingTodaySeconds) ~/ 60,
            color: const Color(0xFF8E6CFF),
          ),
          const SizedBox(height: 10),
          _buildQuotaRow(
            label: 'Call Minutes This Week',
            used: call.usedThisWeekSeconds ~/ 60,
            limit: (call.usedThisWeekSeconds + call.remainingThisWeekSeconds) ~/
                60,
            color: const Color(0xFF5AA9FF),
          ),
          const SizedBox(height: 12),
          Text(
            'Next call max: ${_usageService.formatDurationShort(nextCallCap)}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF355C7D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsCard() {
    final controls = _controls;
    final hasOverride = controls.maxCallMinutesOverride != null;
    final sliderValue = (controls.maxCallMinutesOverride ?? 8).toDouble();
    final hours = List<int>.generate(24, (index) => index);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Parent Controls',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF355C7D),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: controls.callEnabled,
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              'Allow AI calls',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('Turn off to fully block voice calls'),
            onChanged: (value) {
              _saveControls(controls.copyWith(callEnabled: value));
            },
          ),
          SwitchListTile(
            value: hasOverride,
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              'Custom max call length',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              hasOverride
                  ? '${controls.maxCallMinutesOverride} min per call'
                  : 'Use default plan limits',
            ),
            onChanged: (enabled) {
              if (!enabled) {
                _saveControls(
                  controls.copyWith(clearMaxCallMinutesOverride: true),
                );
                return;
              }
              _saveControls(controls.copyWith(maxCallMinutesOverride: 8));
            },
          ),
          if (hasOverride)
            Slider(
              min: 2,
              max: 20,
              divisions: 18,
              label: '${sliderValue.round()} min',
              value: sliderValue,
              onChanged: (value) {
                setState(() {
                  _controls = controls.copyWith(
                    maxCallMinutesOverride: value.round(),
                  );
                });
              },
              onChangeEnd: (value) {
                _saveControls(
                  _controls.copyWith(maxCallMinutesOverride: value.round()),
                );
              },
            ),
          SwitchListTile(
            value: controls.bedtimeLockEnabled,
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              'Bedtime lock',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              controls.bedtimeLockEnabled
                  ? 'Blocked during ${controls.bedtimeRangeLabel()}'
                  : 'No bedtime lock',
            ),
            onChanged: (value) {
              _saveControls(controls.copyWith(bedtimeLockEnabled: value));
            },
          ),
          if (controls.bedtimeLockEnabled)
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<int>(
                    initialValue: controls.bedtimeStartHour,
                    decoration: const InputDecoration(
                      labelText: 'Start',
                      isDense: true,
                    ),
                    items: hours
                        .map(
                          (hour) => DropdownMenuItem<int>(
                            value: hour,
                            child: Text(_hourLabel(hour)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      _saveControls(controls.copyWith(bedtimeStartHour: value));
                    },
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<int>(
                    initialValue: controls.bedtimeEndHour,
                    decoration: const InputDecoration(
                      labelText: 'End',
                      isDense: true,
                    ),
                    items: hours
                        .map(
                          (hour) => DropdownMenuItem<int>(
                            value: hour,
                            child: Text(_hourLabel(hour)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      _saveControls(controls.copyWith(bedtimeEndHour: value));
                    },
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Limits & Controls'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _profileId == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Select a child profile first to view AI limits.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF6FF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Child: ${_profileName ?? 'Profile #$_profileId'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF355C7D),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isPremium ? 'Plan: Premium' : 'Plan: Free',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF355C7D),
                          ),
                        ),
                        if (!_isPremium) ...[
                          const SizedBox(height: 10),
                          FilledButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/subscription'),
                            child: const Text('Upgrade plan'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    _buildUsageCard(),
                    const SizedBox(height: 12),
                    _buildControlsCard(),
                  ],
                ],
              ),
            ),
    );
  }
}
