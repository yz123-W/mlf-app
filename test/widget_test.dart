import 'package:flutter_test/flutter_test.dart';
import 'package:mlf_app/app/theme/app_colors.dart';
import 'package:mlf_app/features/interview/data/interview_models.dart';

void main() {
  test('设计系统色板与原型一致', () {
    expect(AppColors.blue.toARGB32(), 0xFF002B99);
    expect(AppColors.wine.toARGB32(), 0xFF6B001B);
    expect(AppColors.cream.toARGB32(), 0xFFFFFFFF);
  });

  test('场次模型解析后端字段', () {
    final session = InterviewSessionM.fromJson(const {
      'id': 12,
      'sessionNo': 'S20261014120000001',
      'jobProfileId': 3,
      'industry': '1',
      'jobName': 'Java 后端',
      'difficulty': '2',
      'questionType': '1,2',
      'totalCount': 5,
      'answeredCount': 2,
      'status': '1',
      'score': 78.5,
      'startTime': '2026-10-14 12:00:00',
      'duration': 0,
      'reportId': null,
    });

    expect(session.id, 12);
    expect(session.ongoing, isTrue);
    expect(session.finished, isFalse);
    expect(session.totalCount, 5);
    expect(session.answeredCount, 2);
    expect(session.score, 78.5);
    expect(session.reportId, isNull);
    expect(session.questionTypeLabels, ['行为面', '技术面']);
  });
}

