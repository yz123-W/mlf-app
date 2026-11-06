import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/providers.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/mlf_widgets.dart';
import '../data/interview_models.dart';
import '../data/interview_providers.dart';

/// 复盘报告：总分 / 五维 / 雷达 / AI 评语 / 薄弱点 / 改进建议 / 逐题明细 + 一键生成 + 导出 PDF。
class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({super.key, required this.reportId});

  final int reportId;

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  bool _generating = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    ref.read(analyticsProvider).track('report_view', {
      'reportId': widget.reportId,
    });
  }

  String _gradeText(double total) {
    if (total >= 85) return '表现优秀';
    if (total >= 70) return '表现良好';
    if (total >= 60) return '基本合格';
    return '仍需提升';
  }

  Future<void> _generate() async {
    final report = ref
        .read(reportDetailProvider(widget.reportId))
        .asData
        ?.value;
    if (report == null) {
      showToast(context, '暂无报告数据');
      return;
    }
    setState(() => _generating = true);
    try {
      await ref
          .read(interviewRepositoryProvider)
          .generateReport(report.sessionId);
      ref.invalidate(reportDetailProvider(widget.reportId));
      ref.invalidate(reportQuestionsProvider(widget.reportId));
      ref.read(analyticsProvider).track('interview_finish', {
        'reportId': widget.reportId,
        'sessionId': report.sessionId,
      });
      if (mounted) showToast(context, '报告已生成');
    } catch (e) {
      if (mounted) showToast(context, '$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      final report = ref
          .read(reportDetailProvider(widget.reportId))
          .asData
          ?.value;
      final bytes = await ref
          .read(interviewRepositoryProvider)
          .downloadReportPdf(widget.reportId);
      final dir = await getApplicationDocumentsDirectory();
      final name = (report?.reportNo.isNotEmpty ?? false)
          ? report!.reportNo
          : 'report-${widget.reportId}';
      final file = File('${dir.path}/$name.pdf');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      // 降级（spec R5）：open_filex 与工程 AGP 9 / Gradle 9 不兼容，已移除；
      // 本期仅落盘并提示保存路径，交由用户在文件管理器中打开。
      showToast(context, '报告已保存至：${file.path}');
    } catch (e) {
      if (mounted) showToast(context, '导出失败：$e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(reportDetailProvider(widget.reportId));
    final questionsAsync = ref.watch(reportQuestionsProvider(widget.reportId));

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text(
          '面试复盘报告',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      body: reportAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.blue),
        ),
        error: (error, _) => _errorView('$error'),
        data: (report) {
          if (report == null) {
            return _errorView('报告数据不存在或已被删除');
          }
          return _content(report, questionsAsync.asData?.value ?? const []);
        },
      ),
    );
  }

  Widget _content(
    InterviewReportM report,
    List<ReportQuestionDetailM> details,
  ) {
    final total = report.totalScore ?? 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
      children: [
        _scoreHeader(report, total),
        const SizedBox(height: 18),
        _radarCard(report),
        const SizedBox(height: 18),
        _dimensionCard(report),
        if (report.summary.trim().isNotEmpty) ...[
          const SizedBox(height: 18),
          _textCard(
            'AI 评语',
            report.summary,
            Icons.smart_toy_outlined,
            AppColors.blue,
          ),
        ],
        if (report.weakPoints.isNotEmpty) ...[
          const SizedBox(height: 18),
          _weakPointsCard(report.weakPoints),
        ],
        if (report.suggest.trim().isNotEmpty) ...[
          const SizedBox(height: 18),
          _textCard(
            '改进建议',
            report.suggest,
            Icons.tips_and_updates_outlined,
            AppColors.wine,
          ),
        ],
        const SizedBox(height: 22),
        _actions(report),
        const SizedBox(height: 26),
        Row(
          children: [
            const Text(
              '逐题明细',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            Text(
              '共 ${details.length} 题',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 11),
        if (details.isEmpty)
          const MlfCard(
            padding: EdgeInsets.all(18),
            child: Text(
              '暂无逐题明细',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          )
        else
          for (final detail in details) ...[
            _detailCard(detail),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _scoreHeader(InterviewReportM report, double total) {
    final time = report.startTime;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                total.toStringAsFixed(1),
                style: const TextStyle(
                  fontFamily: 'serif',
                  color: AppColors.blue,
                  fontSize: 46,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8, left: 4),
                child: Text(
                  '分',
                  style: TextStyle(color: AppColors.muted, fontSize: 15),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.wineSoft,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFFEAD3DA)),
                ),
                child: Text(
                  _gradeText(total),
                  style: const TextStyle(
                    color: AppColors.wine,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            report.jobName.isEmpty ? '模拟面试' : report.jobName,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            time == null ? '时间未知' : DateFormat('yyyy-MM-dd HH:mm').format(time),
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _radarCard(InterviewReportM report) {
    return MlfCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '能力雷达',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 230,
            child: CustomPaint(
              painter: _RadarPainter(
                values: report.fiveDimensions,
                labels: InterviewReportM.dimensionLabels,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dimensionCard(InterviewReportM report) {
    final values = report.fiveDimensions;
    return MlfCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '五维得分',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < InterviewReportM.dimensionLabels.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text(
                    InterviewReportM.dimensionLabels[i],
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (values[i].clamp(0, 100)) / 100.0,
                      minHeight: 8,
                      backgroundColor: const Color(0x1A002B99),
                      valueColor: AlwaysStoppedAnimation(
                        i == 4 ? AppColors.wine : AppColors.blue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 42,
                  child: Text(
                    values[i].toStringAsFixed(0),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _textCard(String title, String body, IconData icon, Color color) {
    return MlfCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              height: 1.8,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _weakPointsCard(List<String> weakPoints) {
    return MlfCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: AppColors.orange,
              ),
              SizedBox(width: 6),
              Text(
                '薄弱点',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: weakPoints
                .map(
                  (e) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE4D8),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      e,
                      style: const TextStyle(
                        color: AppColors.wine,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _actions(InterviewReportM report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!report.generated)
          MlfPrimaryButton(
            label: '一键生成报告',
            loading: _generating,
            onPressed: _generate,
          ),
        if (!report.generated) const SizedBox(height: 12),
        OutlinedButton(
          onPressed: report.generated && !_exporting ? _exportPdf : null,
          style: OutlinedButton.styleFrom(
            backgroundColor: const Color(0xFFE7EDFF),
            side: BorderSide.none,
            minimumSize: const Size.fromHeight(51),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: _exporting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.blue,
                  ),
                )
              : Text(
                  report.generated ? '导出 PDF' : '报告生成后可导出 PDF',
                  style: TextStyle(
                    color: report.generated ? AppColors.blue : AppColors.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _detailCard(ReportQuestionDetailM detail) {
    return MlfCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7EDFF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '第 ${detail.questionNo} 题',
                  style: const TextStyle(
                    color: AppColors.blue,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                InterviewDict.questionType(detail.questionType),
                style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
              ),
              const Spacer(),
              if (detail.score != null)
                Text(
                  '${detail.score!.toStringAsFixed(0)} 分',
                  style: const TextStyle(
                    color: AppColors.wine,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            detail.questionContent,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          _section(
            '我的作答',
            detail.myAnswer?.trim().isNotEmpty == true
                ? detail.myAnswer!
                : '（未作答）',
            detail.myAnswer?.trim().isNotEmpty == true
                ? AppColors.ink
                : AppColors.muted,
          ),
          const SizedBox(height: 10),
          _section(
            '参考答案',
            detail.referenceAnswer.trim().isEmpty
                ? '（暂无参考答案）'
                : detail.referenceAnswer,
            AppColors.ink,
          ),
          if (detail.comment.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _section('点评', detail.comment, AppColors.ink),
          ],
          if (detail.keyPoints.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: detail.keyPoints.map(_keyPointChip).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _section(String label, String body, Color bodyColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.blue,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          body,
          style: TextStyle(fontSize: 13.5, height: 1.7, color: bodyColor),
        ),
      ],
    );
  }

  Widget _keyPointChip(KeyPointM point) {
    final fg = point.hit ? AppColors.success : AppColors.wine;
    final bg = point.hit ? const Color(0xFFDCF5E6) : const Color(0xFFFFE4D8);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            point.hit ? Icons.check : Icons.priority_high,
            size: 13,
            color: fg,
          ),
          const SizedBox(width: 4),
          Text(
            point.text,
            style: TextStyle(
              color: fg,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: AppColors.muted,
              size: 34,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 42,
              child: FilledButton(
                onPressed: () {
                  ref.invalidate(reportDetailProvider(widget.reportId));
                  ref.invalidate(reportQuestionsProvider(widget.reportId));
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '重新加载',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 五维雷达图（0–100）。
class _RadarPainter extends CustomPainter {
  const _RadarPainter({required this.values, required this.labels});

  final List<double> values;
  final List<String> labels;

  @override
  void paint(Canvas canvas, Size size) {
    final count = values.length;
    if (count < 3) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 30;
    final step = 2 * math.pi / count;

    Offset pointAt(int i, double r) =>
        center +
        Offset(
          math.cos(-math.pi / 2 + step * i) * r,
          math.sin(-math.pi / 2 + step * i) * r,
        );

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = AppColors.line
      ..strokeWidth = 1;

    for (var ring = 1; ring <= 4; ring++) {
      final r = radius * ring / 4;
      final path = Path();
      for (var i = 0; i < count; i++) {
        final p = pointAt(i, r);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }
    for (var i = 0; i < count; i++) {
      canvas.drawLine(center, pointAt(i, radius), gridPaint);
    }

    final valuePath = Path();
    for (var i = 0; i < count; i++) {
      final ratio = (values[i].clamp(0, 100)) / 100.0;
      final p = pointAt(i, radius * ratio);
      if (i == 0) {
        valuePath.moveTo(p.dx, p.dy);
      } else {
        valuePath.lineTo(p.dx, p.dy);
      }
    }
    valuePath.close();
    canvas.drawPath(
      valuePath,
      Paint()
        ..style = PaintingStyle.fill
        ..color = AppColors.blue.withValues(alpha: 0.22),
    );
    canvas.drawPath(
      valuePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = AppColors.blue
        ..strokeWidth = 2,
    );

    for (var i = 0; i < count; i++) {
      final p = pointAt(i, radius + 18);
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(color: AppColors.muted, fontSize: 10.5),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.labels != labels;
}
