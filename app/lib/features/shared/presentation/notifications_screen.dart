import 'package:flutter/material.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/services/social_service.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';

/// Sino com contador de não lidas (usado nas home de cliente e profissional).
class UnreadBell extends StatelessWidget {
  const UnreadBell({super.key, required this.onOpenJob});

  /// Chamado quando o usuário toca em uma notificação ligada a uma demanda.
  final void Function(BuildContext context, String jobId) onOpenJob;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppNotification>>(
      stream: SocialService().streamNotifications(),
      builder: (context, snap) {
        final unread = (snap.data ?? const []).where((n) => n.unread).length;
        return BellButton(
          count: unread,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => NotificationsScreen(onOpenJob: onOpenJob)),
          ),
        );
      },
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, required this.onOpenJob});

  final void Function(BuildContext context, String jobId) onOpenJob;

  IconData _icon(String kind) => switch (kind) {
    'new_quote' => Icons.request_quote_rounded,
    'quote_accepted' => Icons.handshake_rounded,
    'quote_rejected' => Icons.thumb_down_alt_rounded,
    'payment_escrow' => Icons.lock_rounded,
    'payment_released' => Icons.payments_rounded,
    'new_invite' => Icons.notifications_active_rounded,
    'emergency_accepted' => Icons.bolt_rounded,
    'emergency_refunded' => Icons.undo_rounded,
    'job_completed' || 'job_finished' => Icons.check_circle_rounded,
    'job_canceled' || 'invite_declined' => Icons.cancel_rounded,
    _ => Icons.notifications_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final service = SocialService();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          TextButton(onPressed: service.markAllRead, child: const Text('Marcar lidas')),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: service.streamNotifications(),
        builder: (context, snap) {
          if (snap.hasError) return const ErrorView(message: 'Não foi possível carregar as notificações.');
          if (!snap.hasData) return const LoadingView();
          final items = snap.data!;
          if (items.isEmpty) {
            return const EmptyView(
              icon: Icons.notifications_off_outlined,
              title: 'Nada por aqui ainda',
              subtitle: 'Avisaremos sobre orçamentos, pagamentos e atualizações dos seus serviços.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final n = items[i];
              final accent = Theme.of(context).colorScheme.primary;
              return ListTile(
                tileColor: n.unread ? accent.withValues(alpha: 0.06) : null,
                leading: CircleAvatar(
                  backgroundColor: accent.withValues(alpha: 0.12),
                  child: Icon(_icon(n.kind), color: accent),
                ),
                title: Text(n.title, style: TextStyle(fontWeight: n.unread ? FontWeight.w800 : FontWeight.w600)),
                subtitle: Text('${n.body ?? ''}\n${relativeTime(n.createdAt)}'),
                isThreeLine: true,
                onTap: () {
                  service.markRead(n.id);
                  if (n.jobId != null) onOpenJob(context, n.jobId!);
                },
              );
            },
          );
        },
      ),
    );
  }
}
