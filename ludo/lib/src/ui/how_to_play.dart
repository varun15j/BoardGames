import 'package:flutter/material.dart';
import 'package:game_kit/game_kit.dart';

/// Rules in plain words.
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  static const _rules = <(String, String)>[
    ('Goal', 'Bring all your tokens round the board and into the centre. The match ends when all but one player have finished.'),
    ('Leaving base', 'You need a 6 to move a token out of its base onto your start square.'),
    ('Moving', 'Move any token by the number rolled. Tokens travel clockwise, then turn into your coloured home lane.'),
    ('Finishing', 'A token needs the exact roll to reach the centre. Too big a number and that token has to wait.'),
    ('Capturing', 'Land on a rival token to send it back to its base, unless it stands on a safe square.'),
    ('Safe squares', 'The four coloured start squares and the four stars are safe. Tokens there cannot be captured.'),
    ('Bonus rolls', 'Roll again after a 6, a capture, or bringing a token home. Three 6s in a row end your turn.'),
    ('Timer', 'You have 15 seconds a turn. When it runs out the game rolls and plays the best move for you.'),
    ('Shapes', 'Every colour has its own mark - circle, square, triangle or diamond - so tokens are easy to tell apart.'),
  ];

  @override
  Widget build(BuildContext context) {
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
                    Text('How to play', style: KitTheme.heading(size: 26)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    for (final (title, body) in _rules)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: KitColors.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: KitTheme.heading(size: 18, color: KitColors.gold)),
                            const SizedBox(height: 4),
                            Text(body, style: KitTheme.body(size: 14.5, weight: FontWeight.w600, color: KitColors.muted)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final s in kCornerStyles) ...[
                          TokenDisc(color: s.color, shape: s.shape, size: 30),
                          const SizedBox(width: 10),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
