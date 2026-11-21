import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/feature_models.dart';
import '../../services/app_state_controller.dart';
import '../../utils/formatters.dart';
import '../../widgets/common_widgets.dart';

enum PlanHorizon { all, daily, weekly, monthly, completed }

class TasksScreen extends StatefulWidget {
  final AppStateController controller;

  const TasksScreen({super.key, required this.controller});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  PlanHorizon _horizon = PlanHorizon.all;
  String? _selectedProjectId;

  List<TaskModel> _filteredTasks() {
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final weekEnd = todayEnd.add(const Duration(days: 7));
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    return widget.controller.tasks.where((t) {
      if (_selectedProjectId != null && t.projectId != _selectedProjectId) {
        return false;
      }
      switch (_horizon) {
        case PlanHorizon.completed:
          return t.isCompleted;
        case PlanHorizon.daily:
          return !t.isCompleted &&
              t.dueDate != null &&
              !t.dueDate!.isAfter(todayEnd);
        case PlanHorizon.weekly:
          return !t.isCompleted &&
              t.dueDate != null &&
              !t.dueDate!.isAfter(weekEnd);
        case PlanHorizon.monthly:
          return !t.isCompleted &&
              t.dueDate != null &&
              !t.dueDate!.isAfter(monthEnd);
        case PlanHorizon.all:
          return !t.isCompleted;
      }
    }).toList();
  }

  Future<void> _toggleInlineChecklistItem(TaskModel task, String itemId) async {
    final previousTask = task;
    final updatedChecklist = task.checklist.map((item) {
      if (item.id == itemId) {
        return item.copyWith(isChecked: !item.isChecked);
      }
      return item;
    }).toList();

    final allChecked = updatedChecklist.isNotEmpty &&
        updatedChecklist.every((item) => item.isChecked);
    final now = DateTime.now();

    final bool nextCompleted =
        allChecked ? true : (task.isCompleted ? false : false);
    final didAutoComplete = !task.isCompleted && nextCompleted;

    await widget.controller.saveTask(
      task.copyWith(
        checklist: updatedChecklist,
        isCompleted: nextCompleted,
        completedAt: nextCompleted ? now : null,
        clearCompletedAt: !nextCompleted,
        updatedAt: now,
      ),
    );

    if (didAutoComplete && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text('Completed "${task.title}"'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              widget.controller.saveTask(previousTask);
            },
          ),
        ),
      );
    }
  }

  void _openTaskEditor({TaskModel? existing}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final checklistCtrl = TextEditingController();
    TaskPriority priority = existing?.priority ?? TaskPriority.medium;
    String? projectId = existing?.projectId ?? _selectedProjectId;
    DateTime? dueDate = existing?.dueDate;
    DateTime? reminderAt = existing?.reminderAt;
    final checklist =
        List<ChecklistItemModel>.from(existing?.checklist ?? const []);
    final taskId = existing?.id ?? const Uuid().v4();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      existing == null ? 'New Task' : 'Edit Task',
                      style: Theme.of(ctx)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Task title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<TaskPriority>(
                            initialValue: priority,
                            decoration: const InputDecoration(
                              labelText: 'Priority',
                              border: OutlineInputBorder(),
                            ),
                            items: TaskPriority.values
                                .map((p) => DropdownMenuItem(
                                      value: p,
                                      child: Text(p.label),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setSheetState(() => priority = v);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            initialValue: projectId,
                            decoration: const InputDecoration(
                              labelText: 'Project',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('None'),
                              ),
                              ...widget.controller.projects
                                  .map((pr) => DropdownMenuItem<String?>(
                                        value: pr.id,
                                        child: Text(pr.name),
                                      )),
                            ],
                            onChanged: (v) =>
                                setSheetState(() => projectId = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: dueDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (d != null) {
                              setSheetState(() => dueDate = d);
                            }
                          },
                          icon: const Icon(Icons.event, size: 16),
                          label: Text(dueDate == null
                              ? 'Set Due Date'
                              : 'Due: ${AppFormatters.shortDate(dueDate!)}'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: reminderAt ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2100),
                            );
                            if (d == null || !ctx.mounted) return;
                            final t = await showTimePicker(
                              context: ctx,
                              initialTime: TimeOfDay.now(),
                            );
                            if (t != null) {
                              setSheetState(() => reminderAt = DateTime(
                                    d.year,
                                    d.month,
                                    d.day,
                                    t.hour,
                                    t.minute,
                                  ));
                            }
                          },
                          icon: const Icon(Icons.notifications_active_outlined,
                              size: 16),
                          label: Text(reminderAt == null
                              ? 'Reminder'
                              : AppFormatters.dateTime(reminderAt!)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: checklistCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Add checklist sub-item...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: () {
                            final txt = checklistCtrl.text.trim();
                            if (txt.isEmpty) return;
                            setSheetState(() {
                              checklist.add(ChecklistItemModel(
                                id: const Uuid().v4(),
                                taskId: taskId,
                                label: txt,
                                sortOrder: checklist.length,
                              ));
                              checklistCtrl.clear();
                            });
                          },
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    ...checklist.map((item) => CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: item.isChecked,
                          title: Text(item.label),
                          onChanged: (v) {
                            setSheetState(() {
                              final idx =
                                  checklist.indexWhere((c) => c.id == item.id);
                              if (idx != -1) {
                                checklist[idx] =
                                    item.copyWith(isChecked: v ?? false);
                              }
                            });
                          },
                        )),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          final title = titleCtrl.text.trim();
                          if (title.isEmpty) return;
                          final now = DateTime.now();
                          final allChecked = checklist.isNotEmpty &&
                              checklist.every((c) => c.isChecked);
                          final completedFlag =
                              allChecked ? true : (existing?.isCompleted ?? false);
                          final task = TaskModel(
                            id: taskId,
                            projectId: projectId,
                            title: title,
                            notes: notesCtrl.text.trim(),
                            priority: priority,
                            dueDate: dueDate,
                            reminderAt: reminderAt,
                            isCompleted: completedFlag,
                            completedAt: completedFlag
                                ? (existing?.completedAt ?? now)
                                : null,
                            clearCompletedAt: !completedFlag,
                            checklist: checklist,
                            createdAt: existing?.createdAt ?? now,
                            updatedAt: now,
                          );
                          await widget.controller.saveTask(task);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('Save Task'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showNewProjectDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Project'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Project name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              await widget.controller.createProject(ctrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _filteredTasks();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Manager'),
        actions: [
          IconButton(
            tooltip: 'New Project',
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: _showNewProjectDialog,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTaskEditor(),
        icon: const Icon(Icons.add_task),
        label: const Text('New Task'),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Upcoming'),
                  selected: _horizon == PlanHorizon.all,
                  onSelected: (_) => setState(() => _horizon = PlanHorizon.all),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Daily'),
                  selected: _horizon == PlanHorizon.daily,
                  onSelected: (_) =>
                      setState(() => _horizon = PlanHorizon.daily),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Weekly'),
                  selected: _horizon == PlanHorizon.weekly,
                  onSelected: (_) =>
                      setState(() => _horizon = PlanHorizon.weekly),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Monthly'),
                  selected: _horizon == PlanHorizon.monthly,
                  onSelected: (_) =>
                      setState(() => _horizon = PlanHorizon.monthly),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Completed'),
                  selected: _horizon == PlanHorizon.completed,
                  onSelected: (_) =>
                      setState(() => _horizon = PlanHorizon.completed),
                ),
              ],
            ),
          ),
          if (widget.controller.projects.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('All Projects'),
                    selected: _selectedProjectId == null,
                    onSelected: (_) =>
                        setState(() => _selectedProjectId = null),
                  ),
                  const SizedBox(width: 6),
                  ...widget.controller.projects.map((pr) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(pr.name),
                          selected: _selectedProjectId == pr.id,
                          onSelected: (sel) => setState(
                              () => _selectedProjectId = sel ? pr.id : null),
                        ),
                      )),
                ],
              ),
            ),
          Expanded(
            child: tasks.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: EmptyStateCard(
                      icon: Icons.task_alt,
                      title: 'No tasks in this view',
                      subtitle:
                          'Add tasks with checklists, deadlines, priorities, and local reminders.',
                      buttonLabel: 'Add Task',
                      onPressed: () => _openTaskEditor(),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    itemCount: tasks.length,
                    itemBuilder: (_, idx) {
                      final task = tasks[idx];
                      final doneCount =
                          task.checklist.where((c) => c.isChecked).length;
                      final progressValue = task.checklist.isEmpty
                          ? 0.0
                          : doneCount / task.checklist.length;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                onTap: () => _openTaskEditor(existing: task),
                                leading: Checkbox(
                                  value: task.isCompleted,
                                  onChanged: (_) =>
                                      widget.controller.toggleTaskComplete(task),
                                ),
                                title: Text(
                                  task.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    decoration: task.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (task.notes.isNotEmpty) Text(task.notes),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 10,
                                      children: [
                                        Text(
                                          task.priority.label,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                  fontWeight: FontWeight.w700),
                                        ),
                                        if (task.dueDate != null)
                                          Text(
                                            'Due ${AppFormatters.shortDate(task.dueDate!)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall,
                                          ),
                                        if (task.checklist.isNotEmpty)
                                          Text(
                                            'Checklist: $doneCount/${task.checklist.length}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () =>
                                      widget.controller.deleteTask(task.id),
                                ),
                              ),
                              if (task.checklist.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 28, right: 16, top: 2),
                                  child: Column(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: LinearProgressIndicator(
                                          value: progressValue,
                                          minHeight: 5,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      ...task.checklist.map(
                                        (item) => InkWell(
                                          onTap: () =>
                                              _toggleInlineChecklistItem(
                                                  task, item.id),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 4),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  item.isChecked
                                                      ? Icons.check_box
                                                      : Icons
                                                          .check_box_outline_blank,
                                                  size: 18,
                                                  color: item.isChecked
                                                      ? Theme.of(context)
                                                          .colorScheme
                                                          .primary
                                                      : Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    item.label,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      decoration: item.isChecked
                                                          ? TextDecoration
                                                              .lineThrough
                                                          : null,
                                                      color: item.isChecked
                                                          ? Theme.of(context)
                                                              .colorScheme
                                                              .onSurfaceVariant
                                                          : null,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
