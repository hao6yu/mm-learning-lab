import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../providers/profile_provider.dart';

typedef MathQuizHistoryLoader = Future<List<Map<String, dynamic>>> Function(
  int profileId,
);

class MathQuizHistoryScreen extends StatefulWidget {
  const MathQuizHistoryScreen({
    super.key,
    this.loadHistory,
  });

  final MathQuizHistoryLoader? loadHistory;

  @override
  State<MathQuizHistoryScreen> createState() => _MathQuizHistoryScreenState();
}

class _MathQuizHistoryScreenState extends State<MathQuizHistoryScreen> {
  late Future<List<Map<String, dynamic>>> _historyFuture;
  int? _resolvedProfileId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final selectedProfileId = context.read<ProfileProvider>().selectedProfileId;

    if (selectedProfileId == _resolvedProfileId) {
      return;
    }
    _resolvedProfileId = selectedProfileId;

    if (selectedProfileId == null) {
      _historyFuture = Future.value([]);
      return;
    }

    final loader = widget.loadHistory ??
        (int profileId) =>
            DatabaseService().getMathQuizAttempts(profileId: profileId);
    _historyFuture = loader(selectedProfileId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              Align(
                alignment: Alignment.topLeft,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF8E6CFF),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x338E6CFF),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(top: 8, left: 0),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Center(
                child: Text(
                  'Quiz History',
                  style: TextStyle(
                    fontFamily: 'Baloo2',
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF8E6CFF),
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _historyFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text(
                          'No quiz attempts yet!\nPlay a quiz to see your results here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontFamily: 'Baloo2',
                            color: Colors.grey,
                          ),
                        ),
                      );
                    }
                    final history = snapshot.data!;
                    return ListView.separated(
                      itemCount: history.length,
                      separatorBuilder: (context, i) =>
                          const SizedBox(height: 18),
                      itemBuilder: (context, i) {
                        final attempt = history[i];
                        final date =
                            DateTime.tryParse(attempt['datetime'] ?? '') ??
                                DateTime.now();
                        final ops = attempt['operations'] ?? '';
                        final grade = attempt['grade'] ?? '';
                        final numQuestions = attempt['num_questions'] ?? 0;
                        final numCorrect = attempt['num_correct'] ?? 0;
                        final timeUsed = attempt['time_used'] ?? 0;
                        final timeLimit = attempt['time_limit'] ?? 0;
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8E6CFF)
                                    .withValues(alpha: 0.10),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(
                              color: const Color(0xFF8E6CFF),
                              width: 2,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 18),
                          child: Row(
                            children: [
                              const Icon(Icons.emoji_events_rounded,
                                  color: Color(0xFF8E6CFF), size: 38),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${date.month}/${date.day}/${date.year}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                                      style: const TextStyle(
                                        fontFamily: 'Baloo2',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Color(0xFF8E6CFF),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Grade: $grade   Ops: $ops',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF24924B),
                                        fontFamily: 'Baloo2',
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Score: $numCorrect/$numQuestions   Time: $timeUsed s / $timeLimit min',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFFFF9F43),
                                        fontFamily: 'Baloo2',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
