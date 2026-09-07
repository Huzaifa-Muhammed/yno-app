import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/feedback_repository.dart';
import '../services/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import '../widgets/header.dart';
import '../widgets/motion.dart';
import '../widgets/yno_scaffold.dart';

/// Report a Bug / Send a Suggestion — one screen, two modes.
///
/// The two drawer rows are genuinely the same form with different copy, so they
/// share a screen rather than duplicating a text box, a validator and a submit
/// path. [type] comes from the route ([Routes.reportBug] / [Routes.suggestion]),
/// which is why there are two routes rather than one taking an argument: the
/// drawer's `_item` helper navigates by name with no arguments, and giving it a
/// special case for these two would be worse than a second route constant.
///
/// Nothing is asked beyond the message. Who sent it, on what build and
/// platform, is captured by [FeedbackRepository.submit] — a bug report that
/// does not say which version it came from is usually unactionable, and nobody
/// types their own app version correctly.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key, required this.type});

  final FeedbackType type;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _message = TextEditingController();
  bool _busy = false;
  bool _sent = false;

  bool get _isBug => widget.type == FeedbackType.bug;

  @override
  void initState() {
    super.initState();
    _message.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  int get _length => _message.text.trim().length;
  bool get _canSend =>
      !_busy && _length > 0 && _length <= FeedbackRepository.maxMessageLength;

  Future<void> _send() async {
    if (!_canSend) return;
    setState(() => _busy = true);
    try {
      await FeedbackRepository.instance
          .submit(type: widget.type, message: _message.text);
      if (!mounted) return;
      // A thank-you panel rather than a toast-and-pop: this is a one-way
      // message with no reply, so the user needs to see plainly that it left.
      setState(() {
        _sent = true;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      showYnoToast(context, tr('feedback.sendFailed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return YnoScaffold(
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 26),
          children: [
            ScreenHeader(
              title: _isBug ? tr('drawer.reportBug') : tr('drawer.suggestion'),
              onBack: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(height: 14),
            if (_sent) _thanks() else ..._form(),
          ],
        ),
      ),
    );
  }

  List<Widget> _form() => [
        FadeSlideIn(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Text(_isBug ? '🐞' : '💡',
                    style: const TextStyle(fontSize: 52)),
              ),
              const SizedBox(height: 12),
              Text(_isBug ? tr('feedback.bugBlurb') : tr('feedback.ideaBlurb'),
                  textAlign: TextAlign.center,
                  style: AppText.barlow(
                      size: 14, color: AppColors.dim, height: 1.5)),
              const SizedBox(height: 22),
              SectionLabel(_isBug
                  ? tr('feedback.whatHappened')
                  : tr('feedback.yourIdea')),
              const SizedBox(height: 10),
              _messageBox(),
              const SizedBox(height: 8),
              _counter(),
              const SizedBox(height: 20),
              PrimaryButton(
                label: _busy ? tr('feedback.sending') : tr('feedback.send'),
                height: 54,
                fontSize: 18,
                onTap: _canSend ? _send : null,
              ),
              const SizedBox(height: 14),
              // Says out loud what is attached, because it is collected without
              // being asked for. Cheaper than a privacy complaint, and it tells
              // a reporter they do not need to type any of it.
              Text(tr('feedback.attachedNote'),
                  textAlign: TextAlign.center,
                  style: AppText.barlow(
                      size: 11.5, color: AppColors.dim2, height: 1.45)),
            ],
          ),
        ),
      ];

  /// Multi-line input.
  ///
  /// Hand-rolled rather than [YnoTextField], which is a fixed-height
  /// single-line box — a bug report needs room to breathe. The decoration
  /// deliberately mirrors it so the two do not look like different apps.
  Widget _messageBox() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: TextField(
        controller: _message,
        maxLines: 8,
        minLines: 6,
        // No `maxLength`: it draws Material's own counter under the field, in
        // the wrong font. The counter below is ours.
        textCapitalization: TextCapitalization.sentences,
        keyboardType: TextInputType.multiline,
        style: AppText.barlow(size: 15, height: 1.45),
        cursorColor: AppColors.primary,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText:
              _isBug ? tr('feedback.bugHint') : tr('feedback.ideaHint'),
          hintStyle: AppText.barlow(
              size: 15, color: AppColors.dim2, height: 1.45),
        ),
      ),
    );
  }

  Widget _counter() {
    final over = _length > FeedbackRepository.maxMessageLength;
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Text('$_length / ${FeedbackRepository.maxMessageLength}',
          style: AppText.barlow(
              size: 12,
              weight: over ? FontWeight.w800 : FontWeight.w600,
              // Only turns red once it actually blocks sending — a counter that
              // looks alarmed at 300 characters trains people to ignore it.
              color: over ? AppColors.loss : AppColors.dim2)),
    );
  }

  Widget _thanks() {
    return FadeSlideIn(
      child: Column(
        children: [
          const SizedBox(height: 30),
          const Text('✅', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 16),
          Text(tr('feedback.thanksTitle'),
              textAlign: TextAlign.center,
              style: AppText.condensed(size: 28, weight: FontWeight.w800)),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
                _isBug
                    ? tr('feedback.thanksBug')
                    : tr('feedback.thanksIdea'),
                textAlign: TextAlign.center,
                style: AppText.barlow(
                    size: 14, color: AppColors.dim, height: 1.5)),
          ),
          const SizedBox(height: 30),
          PrimaryButton(
            label: tr('common.done'),
            height: 52,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(height: 10),
          // Lets someone file a second report without walking back out to the
          // drawer — the most likely next action after a bug report is another
          // bug report.
          GhostButton(
            label: _isBug
                ? tr('feedback.reportAnother')
                : tr('feedback.suggestAnother'),
            onTap: () => setState(() {
              _message.clear();
              _sent = false;
            }),
          ),
        ],
      ),
    );
  }
}
