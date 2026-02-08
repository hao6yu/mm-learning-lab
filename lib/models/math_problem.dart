import 'dart:math';
import '../models/math_buddy.dart';

class MathProblem {
  final String question;
  final String displayQuestion;
  final int answer;
  final List<int> options;
  final String grade;
  final String operation;

  MathProblem({
    required this.question,
    required this.displayQuestion,
    required this.answer,
    required this.options,
    required this.grade,
    required this.operation,
  });

  static MathProblem generateProblemForGrade(String grade, String operation) {
    switch (operation) {
      case '+':
        return _generateAdditionProblem(grade);
      case '-':
        return _generateSubtractionProblem(grade);
      case '×':
        return _generateMultiplicationProblem(grade);
      case '÷':
        return _generateDivisionProblem(grade);
      default:
        return _generateAdditionProblem(grade);
    }
  }

  static MathProblem _generateAdditionProblem(String grade) {
    final random = Random();
    final range = MathBuddy.gradeDifficultyRanges[grade]!;
    final minValue = range['min']!;
    final maxValue = range['max']!;

    int num1 = minValue + random.nextInt(maxValue - minValue + 1);
    int num2 = minValue + random.nextInt(maxValue - minValue + 1);

    final answer = num1 + num2;
    final question = "$num1 + $num2 = ?";
    final displayQuestion = "$num1 + $num2";

    // Generate options, including the correct answer
    List<int> options = [answer];

    // Add incorrect options
    while (options.length < 4) {
      int incorrectOption;
      // Generate plausible wrong answers
      if (random.nextBool()) {
        // Off by a small amount
        int offset = random.nextInt(3) + 1;
        incorrectOption = answer + (random.nextBool() ? offset : -offset);
      } else {
        // Random number in range but not the answer
        incorrectOption = minValue + random.nextInt(maxValue * 2 - minValue);
      }

      if (!options.contains(incorrectOption) && incorrectOption >= 0) {
        options.add(incorrectOption);
      }
    }

    // Shuffle options
    options.shuffle();

    return MathProblem(
      question: question,
      displayQuestion: displayQuestion,
      answer: answer,
      options: options,
      grade: grade,
      operation: '+',
    );
  }

  static MathProblem _generateSubtractionProblem(String grade) {
    final random = Random();
    final range = MathBuddy.gradeDifficultyRanges[grade]!;
    final minValue = range['min']!;
    final maxValue = range['max']!;

    // First number should be larger to avoid negative results
    int num1 = minValue + random.nextInt(maxValue - minValue + 1);
    int num2 = minValue + random.nextInt(num1 - minValue + 1);

    final answer = num1 - num2;
    final question = "$num1 - $num2 = ?";
    final displayQuestion = "$num1 - $num2";

    // Generate options, including the correct answer
    List<int> options = [answer];

    // Add incorrect options
    while (options.length < 4) {
      int incorrectOption;
      // Generate plausible wrong answers
      if (random.nextBool()) {
        // Off by a small amount
        int offset = random.nextInt(3) + 1;
        incorrectOption = answer + (random.nextBool() ? offset : -offset);
      } else if (random.nextBool()) {
        // Common error: reversed subtraction
        incorrectOption = num2 - num1;
      } else {
        // Random number in range but not the answer
        incorrectOption = random.nextInt(maxValue + 1);
      }

      if (!options.contains(incorrectOption) && incorrectOption >= 0) {
        options.add(incorrectOption);
      }
    }

    // Shuffle options
    options.shuffle();

    return MathProblem(
      question: question,
      displayQuestion: displayQuestion,
      answer: answer,
      options: options,
      grade: grade,
      operation: '-',
    );
  }

  static MathProblem _generateMultiplicationProblem(String grade) {
    final random = Random();
    int num1, num2;

    // Adjust multiplication difficulty based on grade
    switch (grade) {
      case '3rd':
        num1 = random.nextInt(10) + 1;
        num2 = random.nextInt(10) + 1;
        break;
      case '4th':
        num1 = random.nextInt(12) + 1;
        num2 = random.nextInt(12) + 1;
        break;
      default:
        num1 = random.nextInt(5) + 1;
        num2 = random.nextInt(5) + 1;
    }

    final answer = num1 * num2;
    final question = "$num1 × $num2 = ?";
    final displayQuestion = "$num1 × $num2";

    // Generate options, including the correct answer
    List<int> options = [answer];

    // Add incorrect options
    while (options.length < 4) {
      int incorrectOption;

      // Generate plausible wrong answers
      if (random.nextBool()) {
        // Off by a small amount
        int offset = random.nextInt(3) + 1;
        incorrectOption = answer + (random.nextBool() ? offset : -offset);
      } else {
        // Common multiplication error
        int wrongNum1 = num1 + (random.nextBool() ? 1 : -1);
        int wrongNum2 = num2 + (random.nextBool() ? 1 : -1);
        incorrectOption = wrongNum1 * wrongNum2;
      }

      if (!options.contains(incorrectOption) && incorrectOption > 0) {
        options.add(incorrectOption);
      }
    }

    // Shuffle options
    options.shuffle();

    return MathProblem(
      question: question,
      displayQuestion: displayQuestion,
      answer: answer,
      options: options,
      grade: grade,
      operation: '×',
    );
  }

  static MathProblem _generateDivisionProblem(String grade) {
    final random = Random();
    int num1, num2;

    // Only 4th grade gets division
    if (grade == '4th') {
      // Create a division problem with a clean answer (no remainders for simplicity)
      num2 = random.nextInt(10) + 2; // Divisor between 2 and 11
      int result = random.nextInt(10) + 1; // Result between 1 and 10
      num1 = num2 *
          result; // Dividend is divisor * result to ensure clean division
    } else {
      // Fallback for lower grades (this shouldn't happen but just in case)
      num2 = random.nextInt(5) + 2;
      int result = random.nextInt(5) + 1;
      num1 = num2 * result;
    }

    final answer = num1 ~/ num2;
    final question = "$num1 ÷ $num2 = ?";
    final displayQuestion = "$num1 ÷ $num2";

    // Generate options, including the correct answer
    List<int> options = [answer];

    // Add incorrect options
    while (options.length < 4) {
      int incorrectOption;

      // Generate plausible wrong answers
      if (random.nextBool()) {
        // Off by a small amount
        int offset = random.nextInt(2) + 1;
        incorrectOption = answer + (random.nextBool() ? offset : -offset);
      } else if (random.nextBool()) {
        // Common division error: divide divisor by dividend instead
        incorrectOption = num2 > 0 && num1 > 0 ? num2 ~/ num1 : 1;
      } else {
        // Random number in a reasonable range
        incorrectOption = random.nextInt(20) + 1;
      }

      if (!options.contains(incorrectOption) && incorrectOption > 0) {
        options.add(incorrectOption);
      }
    }

    // Shuffle options
    options.shuffle();

    return MathProblem(
      question: question,
      displayQuestion: displayQuestion,
      answer: answer,
      options: options,
      grade: grade,
      operation: '÷',
    );
  }

  static MathProblem generateRandomProblemForGrade(String grade) {
    final random = Random();
    final allowedOperations = MathBuddy.gradeOperations[grade]!.toList();

    // Select a random operation from the allowed operations for this grade
    final operation =
        allowedOperations[random.nextInt(allowedOperations.length)];

    return generateProblemForGrade(grade, operation);
  }
}
