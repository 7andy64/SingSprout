import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/voice_card.dart';
import '../../shared/providers/app_state.dart';

/// 家庭音乐账本 — 声音明信片发件箱
class LedgerPage extends StatelessWidget {
  const LedgerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('家庭音乐账本'),
        centerTitle: true,
      ),
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          final cards = appState.cards;

          if (cards.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('✉️', style: TextStyle(fontSize: 56)),
                  SizedBox(height: 14),
                  Text(
                    '还没有发出明信片',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '完成一首作品后可以分享给家人',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: cards.length,
            itemBuilder: (_, i) => _CardItem(card: cards[i]),
          );
        },
      ),
    );
  }
}

class _CardItem extends StatelessWidget {
  final VoiceCard card;

  const _CardItem({required this.card});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.send,
                size: 22,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.textContent ?? '(无内容)',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (card.audioPath != null) ...[
                        const Icon(Icons.mic, size: 13,
                            color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        const Text('含语音',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary)),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        _formatDate(card.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
