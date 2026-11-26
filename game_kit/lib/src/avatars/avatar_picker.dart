import 'package:flutter/material.dart';

import '../buttons.dart';
import '../night_background.dart';
import '../theme.dart';
import 'avatar_store.dart';
import 'catalog.dart';
import 'profile.dart';

/// What the picker returns.
class AvatarPick {
  const AvatarPick(this.name, this.choice);
  final String name;
  final AvatarChoice choice;
}

/// Category chips, a grid of avatars, a live preview, an optional name field
/// and "Use my photo". Pops with an [AvatarPick] when saved.
class AvatarPickerScreen extends StatefulWidget {
  const AvatarPickerScreen({
    super.key,
    required this.initial,
    this.name = '',
    this.title = 'Your avatar',
    this.importer = const PhotoImporter(),
  });

  final AvatarChoice initial;
  final String name;
  final String title;
  final PhotoImporter importer;

  @override
  State<AvatarPickerScreen> createState() => _AvatarPickerScreenState();
}

class _AvatarPickerScreenState extends State<AvatarPickerScreen> {
  late AvatarChoice _choice = widget.initial;
  late AvatarCategory _category = widget.initial.avatar.category;
  late final TextEditingController _name = TextEditingController(text: widget.name);
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _usePhoto() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final path = await widget.importer.import();
      if (path != null && mounted) _choice = AvatarChoice(_choice.avatarId, photoPath: path);
    } catch (_) {
      _message = 'Couldn\'t open that photo. Your avatar is still selected.';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final items = avatarsIn(_category);
    return Scaffold(
      body: NightBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded, color: KitColors.ink),
                    ),
                    Text(widget.title, style: KitTheme.heading(size: 24)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Container(
                      key: const ValueKey('avatar-preview'),
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: KitColors.gold, shape: BoxShape.circle),
                      child: AvatarView(choice: _choice, size: 84),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _name,
                            maxLength: 12,
                            style: KitTheme.body(size: 18, weight: FontWeight.w800),
                            decoration: const InputDecoration(isDense: true, counterText: '', hintText: 'Your name'),
                          ),
                          Text(
                            _choice.isPhoto ? 'My photo' : _choice.avatar.name,
                            style: KitTheme.body(size: 13, color: KitColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: SoftButton(
                        label: _busy ? 'Opening…' : 'Use my photo',
                        icon: Icons.photo_library_rounded,
                        onPressed: _busy ? null : _usePhoto,
                      ),
                    ),
                    if (_choice.isPhoto) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: SoftButton(
                          label: 'Remove photo',
                          icon: Icons.delete_outline_rounded,
                          onPressed: () => setState(() => _choice = AvatarChoice(_choice.avatarId)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Text(_message!, style: KitTheme.body(size: 13, color: KitColors.gold)),
                ),
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      for (final c in AvatarCategory.values)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(c.label),
                            selected: c == _category,
                            showCheckmark: false,
                            selectedColor: KitColors.gold,
                            backgroundColor: KitColors.panel,
                            labelStyle: KitTheme.body(
                              size: 13,
                              weight: FontWeight.w800,
                              color: c == _category ? KitColors.goldInk : KitColors.ink,
                            ),
                            onSelected: (_) => setState(() => _category = c),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 92,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final avatar = items[i];
                    final selected = !_choice.isPhoto && _choice.avatarId == avatar.id;
                    return Semantics(
                      button: true,
                      selected: selected,
                      label: avatar.name,
                      excludeSemantics: true,
                      child: GestureDetector(
                        key: ValueKey('avatar-${avatar.id}'),
                        onTap: () => setState(() => _choice = AvatarChoice(avatar.id)),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected ? KitColors.gold : Colors.white24,
                          ),
                          child: LayoutBuilder(
                            builder: (context, box) => AvatarView(choice: AvatarChoice(avatar.id), size: box.maxWidth),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: GoldButton(
                    label: 'Save',
                    onPressed: _busy ? null : () => Navigator.of(context).pop(AvatarPick(_name.text.trim(), _choice)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
