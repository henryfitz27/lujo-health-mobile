import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../api/models/post.dart';

/// Señales de confianza visibles (v2 §22.1): naturaleza, afirmación, revisión y correcciones.
class TrustBadges extends StatelessWidget {
  const TrustBadges({super.key, required this.post, this.light = false});

  final Post post;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, Color?)>[
      if (post.authorVerified)
        (Icons.verified, 'Profesional verificado', Colors.lightBlueAccent),
      if (post.contentNature != 'experience')
        (Icons.info_outline, post.natureLabel, null),
      if (post.claimLabel.isNotEmpty)
        (Icons.science_outlined, post.claimLabel, null),
      if (post.trustLabel.isNotEmpty)
        (
          post.reviewStatus == 'approved'
              ? Icons.fact_check_outlined
              : Icons.hourglass_top,
          post.trustLabel,
          post.reviewStatus == 'approved'
              ? Colors.greenAccent
              : Colors.amberAccent,
        ),
      if (post.correctionsCount > 0)
        (Icons.published_with_changes, 'Corregido', Colors.amberAccent),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    final base = light
        ? Colors.white
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final (icon, label, color) in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: light
                  ? Colors.white24
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 12,
                  color: light
                      ? (color ?? base)
                      : (color == null
                            ? base
                            : Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 3),
                Text(label, style: TextStyle(fontSize: 11, color: base)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Aviso de corrección sobre el contenido (v2 §22.1).
class CorrectionNotice extends StatelessWidget {
  const CorrectionNotice({super.key, required this.post, this.light = false});

  final Post post;
  final bool light;

  @override
  Widget build(BuildContext context) {
    if (post.correctionNote.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: light
            ? Colors.black45
            : Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Corrección: ${post.correctionNote}',
        style: TextStyle(
          fontSize: 12,
          color: light
              ? Colors.white
              : Theme.of(context).colorScheme.onTertiaryContainer,
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Encuesta con voto (v2 §8.1). Muestra resultados cuando se votó o cerró.
class PollView extends ConsumerStatefulWidget {
  const PollView({
    super.key,
    required this.post,
    required this.onChanged,
    this.light = false,
  });

  final Post post;
  final void Function(Post) onChanged;
  final bool light;

  @override
  ConsumerState<PollView> createState() => _PollViewState();
}

class _PollViewState extends ConsumerState<PollView> {
  final _selected = <String>{};
  bool _busy = false;

  Future<void> _vote(List<String> ids) async {
    setState(() => _busy = true);
    try {
      final updated = await ref
          .read(apiClientProvider)
          .vote(widget.post.id, ids);
      widget.onChanged(updated);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final poll = widget.post.poll;
    if (poll == null) return const SizedBox.shrink();
    final color = widget.light
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    final showResults = poll.voted || poll.closed;
    final total = poll.votesCount == 0 ? 1 : poll.votesCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final o in poll.options)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: showResults
                ? _ResultBar(
                    label: o.text,
                    fraction: o.votesCount / total,
                    mine: poll.viewerOptionIds.contains(o.id),
                    color: color,
                    light: widget.light,
                  )
                : poll.multiple
                ? CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(o.text, style: TextStyle(color: color)),
                    value: _selected.contains(o.id),
                    onChanged: _busy
                        ? null
                        : (v) => setState(
                            () => v == true
                                ? _selected.add(o.id)
                                : _selected.remove(o.id),
                          ),
                  )
                : OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: color,
                      side: BorderSide(color: color.withValues(alpha: 0.6)),
                      alignment: Alignment.centerLeft,
                    ),
                    onPressed: _busy ? null : () => _vote([o.id]),
                    child: Text(o.text),
                  ),
          ),
        Row(
          children: [
            Text(
              [
                '${poll.votesCount} voto${poll.votesCount == 1 ? '' : 's'}',
                if (poll.closed) 'cerrada',
                if (!poll.closed && poll.closesAt != null)
                  'cierra ${_fmt(poll.closesAt!)}',
                if (poll.multiple) 'varias opciones',
              ].join(' · '),
              style: TextStyle(
                fontSize: 12,
                color: color.withValues(alpha: 0.8),
              ),
            ),
            const Spacer(),
            if (!showResults && poll.multiple)
              FilledButton.tonal(
                onPressed: _busy || _selected.isEmpty
                    ? null
                    : () => _vote(_selected.toList()),
                child: const Text('Votar'),
              ),
          ],
        ),
      ],
    );
  }

  String _fmt(DateTime d) {
    final l = d.toLocal();
    return '${l.day}/${l.month} ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}

class _ResultBar extends StatelessWidget {
  const _ResultBar({
    required this.label,
    required this.fraction,
    required this.mine,
    required this.color,
    required this.light,
  });

  final String label;
  final double fraction;
  final bool mine;
  final Color color;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        FractionallySizedBox(
          widthFactor: fraction.clamp(0.02, 1),
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color:
                  (light ? Colors.white : Theme.of(context).colorScheme.primary)
                      .withValues(alpha: mine ? 0.55 : 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        SizedBox(
          height: 36,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                if (mine) Icon(Icons.check, size: 16, color: color),
                if (mine) const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(color: color),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${(fraction * 100).round()} %',
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
