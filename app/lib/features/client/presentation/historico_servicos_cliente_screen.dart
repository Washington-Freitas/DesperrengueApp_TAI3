import 'package:flutter/material.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/services/job_service.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/job_labels.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import 'detalhe_servico_cliente_screen.dart';

/// Carrega os serviços encerrados do cliente (produção: query em `jobs`).
typedef FinishedJobsLoader = Future<List<Job>> Function();

/// Histórico de serviços do cliente: concluídos e cancelados, mais recentes primeiro.
class HistoricoServicosClienteScreen extends StatefulWidget {
  const HistoricoServicosClienteScreen({super.key, @visibleForTesting this.loader});

  final FinishedJobsLoader? loader;

  @override
  State<HistoricoServicosClienteScreen> createState() => _HistoricoServicosClienteScreenState();
}

class _HistoricoServicosClienteScreenState extends State<HistoricoServicosClienteScreen> {
  late Future<List<Job>> _future = _load();

  Future<List<Job>> _load() => widget.loader != null ? widget.loader!() : JobService().fetchMyFinishedJobs();

  Future<void> _reload() async {
    final f = _load();
    setState(() => _future = f);
    try {
      await f;
    } catch (_) {
      // O erro já é exibido pelo FutureBuilder.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tk.surface,
      appBar: AppBar(title: const Text('Histórico de serviços')),
      body: FutureBuilder<List<Job>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) {
            return ErrorView(message: 'Não foi possível carregar seu histórico.', onRetry: _reload);
          }
          final jobs = snap.data ?? const <Job>[];
          if (jobs.isEmpty) {
            return const EmptyView(
              icon: Icons.history_rounded,
              title: 'Nenhum serviço encerrado ainda',
              subtitle: 'Quando um serviço for concluído ou cancelado, ele aparece aqui para você rever.',
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              itemCount: jobs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _HistoryItem(job: jobs[i]),
            ),
          );
        },
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final when = job.approvedAt ?? job.finishedAt ?? job.createdAt;
    final canceled = job.status == JobStatus.canceled;
    return AppCard(
      onTap: () => openClientServiceDetail(context, job.id),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: categoryColor(job.category),
            child: Icon(categoryIcon(job.category), color: AppColors.ink.withValues(alpha: 0.75)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  '${job.code} • ${dateShort(when)}',
                  style: TextStyle(color: context.tk.textMuted, fontSize: 12.5),
                ),
                const SizedBox(height: 6),
                JobStatusChip(job),
              ],
            ),
          ),
          if (!canceled && job.agreedPrice != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(brl(job.agreedPrice), style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text('pago', style: TextStyle(color: context.tk.textMuted, fontSize: 11.5)),
                ],
              ),
            ),
          Icon(Icons.chevron_right_rounded, color: context.tk.textMuted),
        ],
      ),
    );
  }
}
