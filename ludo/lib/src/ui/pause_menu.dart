import 'package:flutter/material.dart';
import 'package:game_kit/game_kit.dart';

import 'controller.dart';
import 'how_to_play.dart';

enum PauseChoice { resume, saveAndExit, leave }

/// Pause dialog: resume, sound and haptics, rules, save and exit, leave.
class PauseMenu extends StatefulWidget {
  const PauseMenu({
    super.key,
    required this.controller,
    required this.onSettingsChanged,
    required this.graphics,
    required this.view3d,
    required this.onViewChanged,
    this.networked = false,
  });

  /// A Wi-Fi match cannot be saved.
  final bool networked;
  final bool view3d;
  final ValueChanged<bool> onViewChanged;
  final LudoController controller;
  final GraphicsSettings graphics;
  final VoidCallback onSettingsChanged;

  @override
  State<PauseMenu> createState() => _PauseMenuState();
}

class _PauseMenuState extends State<PauseMenu> {
  late bool _view3d = widget.view3d;

  LudoController get c => widget.controller;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: KitColors.panel,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Paused', textAlign: TextAlign.center, style: KitTheme.heading(size: 28)),
            const SizedBox(height: 16),
            GoldButton(label: 'Resume', icon: Icons.play_arrow_rounded, onPressed: () => Navigator.pop(context, PauseChoice.resume)),
            const SizedBox(height: 14),
            _toggle('Sound', Icons.volume_up_rounded, c.soundOn, (v) => setState(() {
                  c.soundOn = v;
                  widget.onSettingsChanged();
                })),
            const SizedBox(height: 8),
            _toggle('Haptics', Icons.vibration_rounded, c.hapticsOn, (v) => setState(() {
                  c.hapticsOn = v;
                  widget.onSettingsChanged();
                })),
            const SizedBox(height: 12),
            Text('Board view', style: KitTheme.body(size: 13, weight: FontWeight.w800, color: KitColors.muted)),
            const SizedBox(height: 6),
            SegmentedPills<bool>(
              options: const [false, true],
              value: _view3d,
              labelOf: (v) => v ? '3D board' : '2D board',
              onChanged: (v) {
                setState(() => _view3d = v);
                widget.onViewChanged(v);
              },
            ),
            const SizedBox(height: 12),
            GraphicsSelector(settings: widget.graphics),
            const SizedBox(height: 12),
            SoftButton(
              label: 'How to play',
              icon: Icons.help_outline_rounded,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HowToPlayScreen())),
            ),
            if (!widget.networked) ...[
              const SizedBox(height: 10),
              SoftButton(
                label: 'Save & exit',
                icon: Icons.save_alt_rounded,
                onPressed: () => Navigator.pop(context, PauseChoice.saveAndExit),
              ),
            ],
            const SizedBox(height: 10),
            SoftButton(
              label: 'Leave match',
              icon: Icons.logout_rounded,
              danger: true,
              onPressed: () => _confirmLeave(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: KitColors.panel,
        title: Text('Leave this match?', style: KitTheme.heading(size: 22)),
        content: Text('Your progress will be lost.', style: KitTheme.body(color: KitColors.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep playing')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Leave')),
        ],
      ),
    );
    if (ok == true && context.mounted) Navigator.pop(context, PauseChoice.leave);
  }

  Widget _toggle(String label, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return Semantics(
      toggled: value,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Icon(icon, color: value ? KitColors.gold : KitColors.muted),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: KitTheme.body(size: 16, weight: FontWeight.w800))),
              Switch(value: value, onChanged: onChanged, activeThumbColor: KitColors.goldInk, activeTrackColor: KitColors.gold),
            ],
          ),
        ),
      ),
    );
  }
}
