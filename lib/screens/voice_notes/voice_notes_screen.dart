import 'package:flutter/material.dart';
import '../../models/app_models.dart';
import '../../models/feature_models.dart';
import '../../services/app_state_controller.dart';
import '../../utils/formatters.dart';
import '../../widgets/common_widgets.dart';

class VoiceNotesScreen extends StatefulWidget {
  final AppStateController controller;

  const VoiceNotesScreen({super.key, required this.controller});

  @override
  State<VoiceNotesScreen> createState() => _VoiceNotesScreenState();
}

class _VoiceNotesScreenState extends State<VoiceNotesScreen> {
  Future<void> _onStartOrStop() async {
    final voice = widget.controller.voiceService;
    if (!voice.isRecording) {
      final started = await voice.startRecording();
      if (!started && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Microphone permission is required to record voice notes.',
            ),
          ),
        );
      }
      return;
    }

    final titleCtrl = TextEditingController();
    String? selectedNoteId;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Save Voice Recording'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Recording title',
                  hintText: 'Optional title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: selectedNoteId,
                decoration: const InputDecoration(
                  labelText: 'Attach to a note (optional)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('None'),
                  ),
                  ...widget.controller.publicActiveNotes.map(
                    (NoteModel n) => DropdownMenuItem<String?>(
                      value: n.id,
                      child: Text(
                        n.title.isEmpty ? 'Untitled Note' : n.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (val) =>
                    setDlgState(() => selectedNoteId = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Discard'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final saved = await voice.stopAndSaveRecording(
        customTitle: titleCtrl.text,
        attachedNoteId: selectedNoteId,
      );
      if (saved != null) {
        await widget.controller.saveVoiceRecording(saved);
      }
    } else {
      await voice.cancelRecording();
    }
  }

  Future<void> _renameRecording(VoiceRecordingModel rec) async {
    final ctrl = TextEditingController(text: rec.title);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Recording'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (ctrl.text.trim().isNotEmpty) {
                await widget.controller.saveVoiceRecording(
                  rec.copyWith(title: ctrl.text.trim()),
                );
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final voice = widget.controller.voiceService;
    final recordings = widget.controller.voiceRecordings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Notes'),
      ),
      body: ListenableBuilder(
        listenable: voice,
        builder: (context, _) {
          return Column(
            children: [
              // Recorder control deck
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.45),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          voice.isRecording
                              ? (voice.isPaused
                                  ? Icons.pause_circle_filled
                                  : Icons.fiber_manual_record)
                              : Icons.mic,
                          color: voice.isRecording && !voice.isPaused
                              ? Colors.redAccent
                              : Theme.of(context).colorScheme.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          voice.isRecording
                              ? (voice.isPaused
                                  ? 'Paused • ${AppFormatters.durationFromMs(voice.elapsedMs)}'
                                  : 'Recording • ${AppFormatters.durationFromMs(voice.elapsedMs)}')
                              : 'Ready to record locally',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: _onStartOrStop,
                          icon: Icon(voice.isRecording
                              ? Icons.stop
                              : Icons.fiber_manual_record),
                          label: Text(
                              voice.isRecording ? 'Stop & Save' : 'Start Recording'),
                        ),
                        if (voice.isRecording) ...[
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: voice.isPaused
                                ? voice.resumeRecording
                                : voice.pauseRecording,
                            icon: Icon(
                                voice.isPaused ? Icons.play_arrow : Icons.pause),
                            label: Text(voice.isPaused ? 'Resume' : 'Pause'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: recordings.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: EmptyStateCard(
                          icon: Icons.mic_none,
                          title: 'No voice recordings yet',
                          subtitle:
                              'Record spoken thoughts, meeting briefs, or quick memos stored locally on your device.',
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: recordings.length,
                        itemBuilder: (_, idx) {
                          final rec = recordings[idx];
                          final isCurrentPlaying =
                              voice.playingRecordingId == rec.id &&
                                  voice.isPlaying;
                          final attachedNote = rec.attachedNoteId == null
                              ? null
                              : widget.controller.allNotes
                                  .where((n) => n.id == rec.attachedNoteId)
                                  .firstOrNull;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: IconButton.filledTonal(
                                icon: Icon(isCurrentPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow),
                                onPressed: () => voice.togglePlayback(rec),
                              ),
                              title: Text(
                                rec.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Duration: ${AppFormatters.durationFromMs(rec.durationMs)} • ${AppFormatters.dateTime(rec.createdAt)}',
                                    style:
                                        Theme.of(context).textTheme.labelSmall,
                                  ),
                                  if (attachedNote != null)
                                    Text(
                                      'Attached to: ${attachedNote.title.isEmpty ? 'Untitled Note' : attachedNote.title}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary),
                                    ),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (action) async {
                                  if (action == 'rename') {
                                    await _renameRecording(rec);
                                  } else if (action == 'delete') {
                                    if (voice.playingRecordingId == rec.id) {
                                      await voice.stopPlayback();
                                    }
                                    await widget.controller
                                        .deleteVoiceRecording(rec.id);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: 'rename', child: Text('Rename')),
                                  PopupMenuItem(
                                      value: 'delete', child: Text('Delete')),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
