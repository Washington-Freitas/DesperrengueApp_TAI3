import 'package:flutter/material.dart';

import '../models/marketplace_models.dart';
import 'app_theme.dart';
import 'widgets.dart';

/// Rótulo + cor do status da demanda, na visão de quem está olhando.
({String label, Color color, IconData icon}) jobStatusStyle(Job job, {bool provider = false}) {
  if (job.isEmergency && job.status == JobStatus.open) {
    return (label: provider ? 'Emergência aberta' : 'Buscando profissional', color: AppColors.danger, icon: Icons.bolt_rounded);
  }
  switch (job.status) {
    case JobStatus.open:
      return (
        label: provider ? 'Aguardando cliente' : (job.quoteCount > 0 ? '${job.quoteCount} orçamento(s)' : 'Aguardando orçamento'),
        color: AppColors.info,
        icon: Icons.hourglass_top_rounded,
      );
    case JobStatus.awaitingPayment:
      return (label: provider ? 'Aguardando pagamento' : 'Pagar para reservar', color: AppColors.warningInk, icon: Icons.payments_outlined);
    case JobStatus.inProgress:
      return (label: 'Em andamento', color: AppColors.success, icon: Icons.play_circle_outline_rounded);
    case JobStatus.awaitingApproval:
      return (label: 'Aguardando aprovação', color: AppColors.warningInk, icon: Icons.fact_check_outlined);
    case JobStatus.completed:
      return (label: 'Concluído', color: AppColors.successInk, icon: Icons.check_circle_outline_rounded);
    case JobStatus.canceled:
      return (label: 'Cancelado', color: AppColors.muted, icon: Icons.cancel_outlined);
    case JobStatus.disputed:
      return (label: 'Em mediação', color: AppColors.danger, icon: Icons.gavel_rounded);
  }
}

class JobStatusChip extends StatelessWidget {
  const JobStatusChip(this.job, {super.key, this.provider = false});

  final Job job;
  final bool provider;

  @override
  Widget build(BuildContext context) {
    final s = jobStatusStyle(job, provider: provider);
    return StatusChip(s.label, color: s.color, icon: s.icon);
  }
}
