/// One-shot happenings (hops, captures, reactions) on the wire.
library;

import 'package:flutter/material.dart';
import 'package:game_kit/game_kit.dart';

import '../game/board.dart';
import '../game/models.dart';
import '../ui/controller.dart';
import 'protocol.dart';

List<double> _point(BoardPoint p) => [p.row, p.col];

BoardPoint _readPoint(Object? o) {
  final list = o! as List;
  return BoardPoint((list[0] as num).toDouble(), (list[1] as num).toDouble());
}

NetMessage encodeEvent(LudoEvent e) => switch (e) {
      StepEvent(:final seat, :final from, :final to, :final number, :final last) => NetMessage.event(
          'step',
          {'seat': seat, 'from': _point(from), 'to': _point(to), 'n': number, 'last': last},
        ),
      CaptureEvent(:final at, :final victims, :final bySeat) => NetMessage.event('capture', {
          'at': _point(at),
          'by': bySeat,
          'victims': [
            for (final v in victims) [v.seat, v.token],
          ],
        }),
      SafeEvent(:final at) => NetMessage.event('safe', {'at': _point(at)}),
      HomeEvent(:final seat) => NetMessage.event('home', {'seat': seat}),
      BannerEvent(:final text, :final color) => NetMessage.event('banner', {'text': text, 'color': color.toARGB32()}),
      ReactionEvent(:final seat, :final emoji) => NetMessage.event('reaction', {'seat': seat, 'emoji': emoji}),
    };

/// Null for an unknown or malformed event, which is simply not shown.
LudoEvent? decodeEvent(NetMessage m, int seats) {
  try {
    final d = m.data;
    bool seatOk(Object? s) => s is int && s >= 0 && s < seats;
    switch (d['kind']) {
      case 'step':
        if (!seatOk(d['seat'])) return null;
        return StepEvent(
          seat: d['seat']! as int,
          from: _readPoint(d['from']),
          to: _readPoint(d['to']),
          number: d['n']! as int,
          last: d['last']! as bool,
        );
      case 'capture':
        if (!seatOk(d['by'])) return null;
        return CaptureEvent(
          _readPoint(d['at']),
          [for (final v in d['victims']! as List) TokenRef((v as List)[0] as int, v[1] as int)],
          d['by']! as int,
        );
      case 'safe':
        return SafeEvent(_readPoint(d['at']));
      case 'home':
        return seatOk(d['seat']) ? HomeEvent(d['seat']! as int) : null;
      case 'banner':
        return BannerEvent(cleanBanner(d['text']! as String), Color(d['color']! as int));
      case 'reaction':
        final emoji = d['emoji'];
        if (!seatOk(d['seat']) || !kReactionEmoji.contains(emoji)) return null;
        return ReactionEvent(d['seat']! as int, emoji! as String);
    }
  } on TypeError {
    return null;
  } on RangeError {
    return null;
  }
  return null;
}

String cleanBanner(String text) => text.length > 40 ? text.substring(0, 40) : text;
