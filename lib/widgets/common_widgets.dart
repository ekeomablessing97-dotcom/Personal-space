import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/feature_models.dart';
import '../services/app_state_controller.dart';
import '../utils/formatters.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.buttonLabel,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (buttonLabel != null && onPressed != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.add, size: 18),
              label: Text(buttonLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class StatPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const StatPill({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class WeeklyActivityChart extends StatelessWidget {
  final Map<String, int> dailyCounts;

  const WeeklyActivityChart({super.key, required this.dailyCounts});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = dailyCounts.entries.toList();
    final maxVal = entries.fold<int>(
      1,
      (prev, e) => e.value > prev ? e.value : prev,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '7-Day Creative & Writing Activity',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: entries.map((e) {
                final parsed = DateTime.tryParse(e.key) ?? DateTime.now();
                final dayLabel = DateFormat('E').format(parsed).substring(0, 2);
                final ratio = e.value / maxVal;
                final barHeight = (ratio * 68).clamp(6.0, 68.0);

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${e.value}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 22,
                      height: e.value == 0 ? 6 : barHeight,
                      decoration: BoxDecoration(
                        color: e.value == 0
                            ? theme.colorScheme.outlineVariant.withValues(alpha: 0.45)
                            : theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dayLabel,
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class ConnectionSheet extends StatefulWidget {
  final AppStateController controller;
  final String sourceType;
  final String sourceId;

  const ConnectionSheet({
    super.key,
    required this.controller,
    required this.sourceType,
    required this.sourceId,
  });

  @override
  State<ConnectionSheet> createState() => _ConnectionSheetState();
}

class _ConnectionSheetState extends State<ConnectionSheet> {
  String _selectedType = 'note';
  String? _selectedTargetId;
  final TextEditingController _labelCtrl =
      TextEditingController(text: 'Connected to');

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  List<({String id, String title, String subtitle})> _candidates() {
    switch (_selectedType) {
      case 'idea':
        return widget.controller.ideas
            .map((i) => (
                  id: i.id,
                  title: i.title,
                  subtitle: '${i.category.label} • ${i.stage.label}',
                ))
            .toList();
      case 'task':
        return widget.controller.tasks
            .map((t) => (
                  id: t.id,
                  title: t.title,
                  subtitle: t.isCompleted ? 'Completed' : t.priority.label,
                ))
            .toList();
      case 'journal':
        return widget.controller.journalEntries
            .where((j) => !j.isPrivate || widget.controller.authService.isUnlocked)
            .map((j) => (
                  id: j.id,
                  title: j.title.isEmpty ? 'Journal Entry' : j.title,
                  subtitle: AppFormatters.shortDate(j.entryDate),
                ))
            .toList();
      case 'note':
      default:
        return widget.controller.publicActiveNotes
            .where((n) => !(widget.sourceType == 'note' && n.id == widget.sourceId))
            .map((n) => (
                  id: n.id,
                  title: n.title.isEmpty ? 'Untitled Note' : n.title,
                  subtitle: AppFormatters.shortDate(n.updatedAt),
                ))
            .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing =
        widget.controller.connectionsFor(widget.sourceType, widget.sourceId);
    final items = _candidates();

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Linked Records',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (existing.isNotEmpty) ...[
              ...existing.map((c) {
                final isSource =
                    c.sourceType == widget.sourceType && c.sourceId == widget.sourceId;
                final otherType = isSource ? c.targetType : c.sourceType;
                final otherId = isSource ? c.targetId : c.sourceId;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.link),
                  title: Text('${otherType.toUpperCase()}: $otherId'),
                  subtitle: Text(c.label),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await widget.controller.removeConnection(c.id);
                      if (mounted) setState(() {});
                    },
                  ),
                );
              }),
              const Divider(),
            ],
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'note', label: Text('Notes')),
                ButtonSegment(value: 'idea', label: Text('Ideas')),
                ButtonSegment(value: 'task', label: Text('Tasks')),
                ButtonSegment(value: 'journal', label: Text('Journal')),
              ],
              selected: {_selectedType},
              onSelectionChanged: (s) {
                setState(() {
                  _selectedType = s.first;
                  _selectedTargetId = null;
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedTargetId,
              decoration: const InputDecoration(
                labelText: 'Select item to link',
                border: OutlineInputBorder(),
              ),
              items: items
                  .map((it) => DropdownMenuItem(
                        value: it.id,
                        child: Text(
                          '${it.title} (${it.subtitle})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (val) => setState(() => _selectedTargetId = val),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _labelCtrl,
              decoration: const InputDecoration(
                labelText: 'Relationship label',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _selectedTargetId == null
                    ? null
                    : () async {
                        await widget.controller.addConnection(
                          sourceType: widget.sourceType,
                          sourceId: widget.sourceId,
                          targetType: _selectedType,
                          targetId: _selectedTargetId!,
                          label: _labelCtrl.text.trim().isEmpty
                              ? 'Related to'
                              : _labelCtrl.text.trim(),
                        );
                        if (mounted) setState(() => _selectedTargetId = null);
                      },
                icon: const Icon(Icons.add_link),
                label: const Text('Create Link'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
