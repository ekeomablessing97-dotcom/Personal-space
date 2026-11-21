import 'package:flutter/material.dart';
import '../../services/app_state_controller.dart';
import '../../utils/formatters.dart';
import '../../widgets/common_widgets.dart';
import '../notes/note_editor_screen.dart';

class PrivateSpaceScreen extends StatefulWidget {
  final AppStateController controller;

  const PrivateSpaceScreen({super.key, required this.controller});

  @override
  State<PrivateSpaceScreen> createState() => _PrivateSpaceScreenState();
}

class _PrivateSpaceScreenState extends State<PrivateSpaceScreen> {
  final TextEditingController _pinCtrl = TextEditingController();
  final TextEditingController _confirmPinCtrl = TextEditingController();
  String? _errorText;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final available = await widget.controller.authService.canUseBiometrics();
    if (mounted) setState(() => _biometricAvailable = available);
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  Future<void> _setupPin() async {
    final pin = _pinCtrl.text.trim();
    final confirm = _confirmPinCtrl.text.trim();
    if (pin.length < 4) {
      setState(() => _errorText = 'Use at least 4 digits for your PIN.');
      return;
    }
    if (pin != confirm) {
      setState(() => _errorText = 'PINs do not match.');
      return;
    }
    await widget.controller.authService.setPin(pin);
    _pinCtrl.clear();
    _confirmPinCtrl.clear();
    setState(() => _errorText = null);
  }

  Future<void> _unlockWithPin() async {
    final ok = await widget.controller.authService.verifyPin(_pinCtrl.text.trim());
    _pinCtrl.clear();
    if (!ok) {
      setState(() => _errorText = 'Incorrect PIN. Please try again.');
    } else {
      setState(() => _errorText = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.controller.authService;
    final ctrl = widget.controller;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Private Space'),
        actions: [
          if (auth.isUnlocked)
            IconButton(
              tooltip: 'Lock Now',
              icon: const Icon(Icons.lock),
              onPressed: auth.lock,
            ),
        ],
      ),
      body: ListenableBuilder(
        listenable: auth,
        builder: (context, _) {
          if (!auth.hasPin) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Icon(Icons.shield_outlined, size: 44),
                const SizedBox(height: 12),
                Text(
                  'Create a Private Space PIN',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Protect private notes and journal entries locally. PINs are salted and hashed with SHA-256 inside encrypted storage.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _pinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'New PIN (4+ digits)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Confirm PIN',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(_errorText!,
                      style: const TextStyle(color: Colors.redAccent)),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _setupPin,
                  child: const Text('Enable Private Space'),
                ),
              ],
            );
          }

          if (!auth.isUnlocked) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SizedBox(height: 20),
                const Icon(Icons.lock_outline, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Private Space is Locked',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Previews are hidden while locked.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _pinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Enter PIN',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _unlockWithPin(),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(_errorText!,
                      style: const TextStyle(color: Colors.redAccent)),
                ],
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _unlockWithPin,
                  child: const Text('Unlock with PIN'),
                ),
                if (_biometricAvailable && ctrl.settings.biometricsEnabled) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: auth.authenticateWithBiometrics,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Unlock with Biometrics / Device Lock'),
                  ),
                ],
              ],
            );
          }

          final privNotes = ctrl.privateNotes;
          final privJournals = ctrl.privateJournalEntries;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NoteEditorScreen(
                            controller: ctrl,
                            forcePrivate: true,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('New Private Note'),
                    ),
                  ),
                ],
              ),
              const SectionHeader(title: 'Private Notes'),
              if (privNotes.isEmpty)
                const EmptyStateCard(
                  icon: Icons.lock_open_outlined,
                  title: 'No private notes',
                  subtitle:
                      'Toggle "Private" in any note editor or create one directly here.',
                )
              else
                ...privNotes.map((n) => Card(
                      child: ListTile(
                        title: Text(
                            n.title.isEmpty ? 'Untitled Private Note' : n.title),
                        subtitle: Text(
                          n.plainText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NoteEditorScreen(
                              controller: ctrl,
                              existingNote: n,
                            ),
                          ),
                        ),
                      ),
                    )),
              const SectionHeader(title: 'Private Journal Entries'),
              if (privJournals.isEmpty)
                const EmptyStateCard(
                  icon: Icons.book_outlined,
                  title: 'No private journal entries',
                  subtitle:
                      'Journal entries marked private appear here when unlocked.',
                )
              else
                ...privJournals.map((j) => Card(
                      child: ListTile(
                        title: Text(j.title.isEmpty
                            ? AppFormatters.fullDate(j.entryDate)
                            : j.title),
                        subtitle: Text(
                          j.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )),
            ],
          );
        },
      ),
    );
  }
}
