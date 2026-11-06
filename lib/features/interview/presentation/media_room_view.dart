import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/env.dart';
import '../../../shared/utils/toast.dart';
import '../../../shared/widgets/mlf_widgets.dart';
import '../data/interview_models.dart';
import '../data/interview_providers.dart';

/// 对话式面试作答视图（对齐学生端 Web `answer.vue`）。
///
/// 文字：输入框作答 → chat 取下一题。
/// 语音：麦克风录音 → 上传后端 ASR 转文字 → 确认文本 → chat 取下一题 → TTS 朗读。
/// 视频：相机预览 + 录像（视频轨道），同时单独录 WAV 走 ASR；视频上传后随作答一起提交。
class MediaRoomView extends ConsumerStatefulWidget {
  const MediaRoomView({super.key, required this.session});

  final InterviewSessionM session;

  @override
  ConsumerState<MediaRoomView> createState() => _MediaRoomViewState();
}

enum _MicState { idle, recording, recognizing, confirm, sending }

class _MediaRoomViewState extends ConsumerState<MediaRoomView>
    with WidgetsBindingObserver {
  static const int _maxSeconds = 60;
  static const int _voiceFemale = 101001;
  static const int _voiceMale = 101004;

  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  final _transcript = TextEditingController();
  final _textAnswer = TextEditingController();
  final _scroll = ScrollController();

  _MicState _state = _MicState.idle;
  int _voice = _voiceFemale;
  int _seconds = 0;
  Timer? _timer;

  String _questionText = '';
  String _questionNoText = '面试官提问';
  int _answered = 0;
  int _total = 0;
  String? _questionAudioUrl;

  String _audioUrl = '';
  String _videoUrl = '';
  String _audioPath = '';
  bool _finished = false;
  bool _loadingGreeting = true;

  CameraController? _camera;
  Future<void>? _cameraInit;
  bool _cameraReady = false;
  bool _mirrorPreview = false;
  String? _cameraError;

  bool get _isVideo => widget.session.isVideo;
  bool get _isText => !widget.session.isMedia;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _total = widget.session.totalCount;
    _answered = widget.session.answeredCount.clamp(0, _total);
    _questionText = _isVideo
        ? '欢迎进入视频面试。请先点击下方麦克风做一个简单的自我介绍，我会根据你的介绍开始提问。'
        : _isText
        ? '欢迎参加模拟面试。请先在下方输入你的自我介绍，我会根据你的回答开始提问。'
        : '欢迎进入语音面试。请先点击下方麦克风做一个简单的自我介绍，我会根据你的介绍开始提问。';
    _finished = widget.session.finished;
    if (_isVideo) _cameraInit = _initCamera();
    _loadGreeting();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _recorder.dispose();
    _player.dispose();
    _camera?.dispose();
    _transcript.dispose();
    _textAnswer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// 视频面试：切后台释放相机，回前台重建预览，避免黑屏与资源被系统回收。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isVideo) return;
    if (state == AppLifecycleState.paused) {
      if (_camera?.value.isRecordingVideo ?? false) {
        // 录像中切后台先落盘，避免相机被回收后无法停止录像。
        _stopRecording();
        return;
      }
      _releaseCamera();
    } else if (state == AppLifecycleState.resumed && !_cameraReady) {
      _cameraInit = _initCamera();
    }
  }

  Future<void> _releaseCamera() async {
    final controller = _camera;
    _camera = null;
    _cameraReady = false;
    if (mounted) setState(() {});
    try {
      await controller?.dispose();
    } catch (_) {}
  }

  // ------------------------------------------------------------------ 初始化

  /// 进入页面时取开场白（含 TTS 音频）并自动朗读，对齐 Web 端行为。
  Future<void> _loadGreeting() async {
    try {
      final list = await ref
          .read(interviewRepositoryProvider)
          .qaList(widget.session.id);
      final greet = list
          .where((q) => q.questionContent.contains('自我介绍'))
          .toList();
      if (!mounted) return;
      if (greet.isNotEmpty) {
        final last = greet.last;
        setState(() {
          _questionText = last.questionContent;
          _questionAudioUrl = last.audioUrl;
          _answered = list
              .where((q) => q.answerContent.trim().isNotEmpty)
              .length;
        });
        if (!_isText) _playTts(last.audioUrl);
      }
    } catch (_) {
      // 开场白拉取失败时保留本地欢迎语，不阻断作答。
    } finally {
      if (mounted) setState(() => _loadingGreeting = false);
    }
  }

  Future<void> _initCamera() async {
    try {
      final previous = _camera;
      _camera = null;
      _cameraReady = false;
      if (previous != null) {
        try {
          await previous.dispose();
        } catch (_) {}
      }
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _cameraError = '未找到可用摄像头');
        return;
      }
      // 优先使用前置摄像头：视频面试需要看到自己的表情与状态。
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.low,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _cameraReady = true;
        _mirrorPreview = camera.lensDirection == CameraLensDirection.front;
      });
    } catch (e) {
      if (mounted) setState(() => _cameraError = '摄像头不可用：$e');
    }
  }

  // ------------------------------------------------------------------ 音频

  String _fullUrl(String url) =>
      url.startsWith('http') ? url : '${Env.apiBaseUrl}$url';

  Future<void> _playTts(String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      await _player.stop();
      await _player.play(UrlSource(_fullUrl(url)));
    } catch (_) {
      // TTS 播放失败静默降级，不影响作答。
    }
  }

  Future<void> _previewRecord() async {
    if (_audioPath.isEmpty) {
      showToast(context, '暂无可试听的录音');
      return;
    }
    try {
      await _player.stop();
      await _player.play(DeviceFileSource(_audioPath));
    } catch (e) {
      if (mounted) showToast(context, '试听失败：$e');
    }
  }

  // ------------------------------------------------------------------ 录音

  Future<void> _onMicTap() async {
    if (_state == _MicState.recording) {
      await _stopRecording();
    } else if (_state == _MicState.idle) {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    if (_finished) {
      showToast(context, '本场面试已结束');
      return;
    }
    if (!await _recorder.hasPermission()) {
      if (mounted) showToast(context, '无法访问麦克风，请检查系统权限');
      return;
    }
    // 视频模式：等相机初始化完成再开录，避免录像分支被跳过。
    if (_isVideo && !_cameraReady) {
      await _cameraInit;
      if (!mounted) return;
      if (!_cameraReady) showToast(context, '摄像头未就绪，本次仅录制语音');
    }
    try {
      await _player.stop();
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      _audioPath = '${dir.path}/answer_$stamp.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          bitRate: 64000,
          numChannels: 1,
        ),
        path: _audioPath,
      );
      if (_isVideo && _cameraReady) {
        try {
          await _camera!.startVideoRecording();
          debugPrint('video recording started');
        } catch (e) {
          debugPrint('video recording start failed: $e');
          _cameraError = '录像启动失败：$e';
        }
      }
      setState(() {
        _state = _MicState.recording;
        _seconds = 0;
        _audioUrl = '';
        _videoUrl = '';
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() => _seconds++);
        if (_seconds >= _maxSeconds) {
          timer.cancel();
          _stopRecording();
        }
      });
    } catch (e) {
      if (mounted) showToast(context, '录音启动失败：$e');
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    String? path;
    XFile? video;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    if (_isVideo && _cameraReady) {
      try {
        if (_camera!.value.isRecordingVideo) {
          video = await _camera!.stopVideoRecording();
          debugPrint('video recording stopped: ${video.path}');
        } else {
          debugPrint('camera is not recording at stop time');
        }
      } catch (e) {
        debugPrint('video recording stop failed: $e');
        _cameraError = '录像保存失败：$e';
      }
    }
    if (path == null || path.isEmpty) {
      if (!mounted) return;
      setState(() => _state = _MicState.idle);
      showToast(context, '录音失败，请重录一次');
      return;
    }
    setState(() => _state = _MicState.recognizing);
    try {
      final repo = ref.read(interviewRepositoryProvider);
      final audio = await repo.uploadAudio(
        widget.session.id,
        filePath: path,
        filename: 'answer.m4a',
      );
      var videoUrl = '';
      if (video != null && await File(video.path).length() > 0) {
        try {
          debugPrint('video upload start: ${video.path}');
          videoUrl = await repo.uploadVideo(
            widget.session.id,
            filePath: video.path,
            filename: 'answer.mp4',
          );
          debugPrint('video upload done: $videoUrl');
        } catch (e) {
          debugPrint('video upload failed: $e');
          if (mounted) showToast(context, '视频上传失败，已保留语音作答');
        }
      } else if (video != null) {
        // 部分设备（如模拟器）编码器不可用，会产出 0 字节文件。
        debugPrint('video file is empty, skip upload');
        if (mounted) showToast(context, '当前设备无法生成录像，已保留语音作答');
      }
      if (!mounted) return;
      setState(() {
        _audioUrl = audio.audioUrl;
        _videoUrl = videoUrl;
        _transcript.text = audio.text;
        _state = _MicState.confirm;
      });
      if (audio.text.isEmpty) {
        showToast(context, '未能识别出内容，可手动修改后发送，或重录一次');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = _MicState.idle);
      showToast(context, '识别失败，请重试：$e');
    }
  }

  Future<void> _retry() async {
    await _player.stop();
    _transcript.clear();
    setState(() {
      _audioUrl = '';
      _videoUrl = '';
      _audioPath = '';
      _seconds = 0;
      _state = _MicState.idle;
    });
  }

  // ------------------------------------------------------------------ 提交

  /// 语音/视频：确认转写文本后提交。
  Future<void> _send() async {
    final text = _transcript.text.trim();
    if (text.isEmpty) {
      showToast(context, '请输入或识别作答内容');
      return;
    }
    await _submit(
      text,
      answerType: '2',
      audioUrl: _audioUrl,
      videoUrl: _videoUrl,
    );
  }

  /// 文字面试：输入框提交。
  Future<void> _sendText() async {
    final text = _textAnswer.text.trim();
    if (text.isEmpty) {
      showToast(context, '请输入你的作答');
      return;
    }
    await _submit(text, answerType: '1');
  }

  Future<void> _submit(
    String text, {
    required String answerType,
    String audioUrl = '',
    String videoUrl = '',
  }) async {
    setState(() => _state = _MicState.sending);
    try {
      final reply = await ref
          .read(interviewRepositoryProvider)
          .chat(
            widget.session.id,
            answer: text,
            answerType: answerType,
            audioUrl: audioUrl,
            videoUrl: videoUrl,
            voice: _isText ? null : _voice,
          );
      if (!mounted) return;
      _transcript.clear();
      _textAnswer.clear();
      setState(() {
        _answered = reply.mainQuestionCount > 0
            ? reply.mainQuestionCount
            : _answered + 1;
        _total = reply.totalCount > 0 ? reply.totalCount : _total;
        _questionText = reply.aiMessage;
        _questionAudioUrl = reply.questionAudioUrl;
        _questionNoText = reply.followUpNo > 0
            ? '第 ${reply.questionNo} 题 · 追问 ${reply.followUpNo}'
            : (reply.questionNo > 0 ? '第 ${reply.questionNo} 题' : '面试官');
        _finished = reply.finished;
        _audioUrl = '';
        _videoUrl = '';
        _audioPath = '';
        _state = _MicState.idle;
      });
      if (!_isText &&
          reply.questionAudioUrl != null &&
          reply.questionAudioUrl!.isNotEmpty) {
        _playTts(reply.questionAudioUrl);
      }
      if (reply.finished) {
        ref.invalidate(sessionHistoryProvider);
        ref.invalidate(sessionDetailProvider(widget.session.id));
        showToast(context, '本场已完成，复盘报告已生成');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = _MicState.idle);
      showToast(context, '$e');
    }
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _topBar(),
        Expanded(child: _stage()),
        _inputPanel(),
      ],
    );
  }

  Widget _topBar() {
    final progress = _total == 0 ? 0.0 : (_answered / _total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '进度 $_answered/$_total',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (!_isText) _voiceSwitch(),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0x1A002B99),
              valueColor: const AlwaysStoppedAnimation(AppColors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _voiceSwitch() {
    Widget item(int value, String label) {
      final active = _voice == value;
      return GestureDetector(
        onTap: () => setState(() => _voice = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active ? AppColors.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: active ? Colors.white : AppColors.muted,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [item(_voiceMale, '男声'), item(_voiceFemale, '女声')],
      ),
    );
  }

  Widget _stage() {
    return Stack(
      children: [
        // 视频模式：相机预览（右上角小窗）
        if (_isVideo) Positioned(right: 18, top: 8, child: _cameraPreview()),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
          child: ListView(
            controller: _scroll,
            children: [
              if (_isVideo) const SizedBox(height: 150),
              Text(
                _questionNoText,
                style: const TextStyle(
                  fontSize: 8.5,
                  letterSpacing: 1.2,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 10),
              MlfCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 3,
                      decoration: BoxDecoration(
                        color: AppColors.wine,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _loadingGreeting && _questionText.isEmpty
                          ? '正在准备面试官的开场白…'
                          : _questionText,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        height: 1.58,
                        color: AppColors.ink,
                      ),
                    ),
                    if (!_isText &&
                        _questionAudioUrl != null &&
                        _questionAudioUrl!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _playTts(_questionAudioUrl),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.volume_up_outlined,
                              size: 15,
                              color: AppColors.blue,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '重听本题',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_finished) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.mint.withValues(alpha: .45),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    '本场面试已完成，复盘报告正在生成，可在「面试记录」中查看。',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.7,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _cameraPreview() {
    if (_cameraError != null) {
      return Container(
        width: 110,
        height: 140,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Text(
          _cameraError!,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.muted,
            height: 1.5,
          ),
        ),
      );
    }
    if (!_cameraReady || _camera == null) {
      return Container(
        width: 110,
        height: 140,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF0A1120),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white54,
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Transform.flip(
        flipX: _mirrorPreview,
        child: SizedBox(
          width: 110,
          height: 140,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: 110,
              height:
                  110 /
                  (_camera!.value.aspectRatio == 0
                      ? 1
                      : _camera!.value.aspectRatio),
              child: CameraPreview(_camera!),
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: _isText
          ? _textComposer()
          : (_state == _MicState.confirm ? _confirmArea() : _micArea()),
    );
  }

  Widget _textComposer() {
    final busy = _state == _MicState.sending;
    final disabled = busy || _finished;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (busy) ...[
          const Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.blue,
                ),
              ),
              SizedBox(width: 8),
              Text(
                '面试官正在准备下一题…',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: TextField(
            controller: _textAnswer,
            enabled: !disabled,
            maxLines: 5,
            minLines: 3,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.6,
              color: AppColors.ink,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: '在此输入你的作答…',
              hintStyle: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 46,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: disabled ? AppColors.muted : AppColors.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: disabled ? null : _sendText,
                child: Center(
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _finished ? '本场面试已结束' : '发送回答',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _micArea() {
    final recording = _state == _MicState.recording;
    final busy = _state == _MicState.recognizing || _state == _MicState.sending;
    final String tip;
    final String sub;
    switch (_state) {
      case _MicState.recording:
        tip = '正在录音 ${_fmt(_seconds)}';
        sub = '再次点击停止并识别（最长 60 秒）';
        break;
      case _MicState.recognizing:
        tip = '正在识别你的回答…';
        sub = '腾讯云 ASR 语音转文字中';
        break;
      case _MicState.sending:
        tip = '面试官正在准备下一题…';
        sub = '';
        break;
      default:
        tip = _finished ? '本场面试已结束' : '点击麦克风，开始回答本题';
        sub = _finished ? '' : '说完后再次点击停止，自动识别为文字';
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (recording) ...[
          const _StaticWave(),
          const SizedBox(height: 10),
        ],
        GestureDetector(
          onTap: busy || _finished ? null : _onMicTap,
          child: SizedBox(
            width: 84,
            height: 84,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: recording
                          ? const Color(0x336B001B)
                          : const Color(0x1F002B99),
                    ),
                  ),
                ),
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: recording ? AppColors.wine : AppColors.blue,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: recording
                            ? const Color(0x336B001B)
                            : const Color(0x33002B99),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    recording ? Icons.stop_rounded : Icons.mic_none,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (recording) ...[
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              tip,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
        if (sub.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            sub,
            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
        ],
      ],
    );
  }

  Widget _confirmArea() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '转写结果',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _fmt(_seconds),
              style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _previewRecord,
              child: const Row(
                children: [
                  Icon(
                    Icons.play_circle_outline,
                    size: 16,
                    color: AppColors.blue,
                  ),
                  SizedBox(width: 3),
                  Text(
                    '试听',
                    style: TextStyle(fontSize: 11.5, color: AppColors.blue),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: TextField(
            controller: _transcript,
            maxLines: 5,
            minLines: 3,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.6,
              color: AppColors.ink,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: '识别内容可在此修改',
              hintStyle: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: _retry,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.line),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '重录',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 44,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _send,
                      child: const Center(
                        child: Text(
                          '确认发送',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _fmt(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// 录音波形装饰：静态柱状图，只表达“正在录音”，不随音量跳动。
class _StaticWave extends StatelessWidget {
  const _StaticWave();

  static const List<double> _heights = [8, 14, 20, 11, 23, 16, 9, 19, 13, 7];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final height in _heights)
            Container(
              width: 3,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}
