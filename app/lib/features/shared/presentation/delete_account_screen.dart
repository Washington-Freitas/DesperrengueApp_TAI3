import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/account_models.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/storage/local_prefs.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../auth/presentation/auth_gate.dart';
import '../../provider/presentation/pix_withdraw_screen.dart';

/// Excluir conta (LGPD, art. 18, VI) com **guardrail financeiro**.
///
///  * Saldo > 0  → NÃO exclui: BottomSheet pedindo o Pix para conta própria.
///  * Valores em custódia / serviço em andamento → NÃO exclui: aguarde concluir.
///  * Saldo = 0 e sem pendências → chama a Edge Function `excluir-conta`, que envia
///    o Dossiê de Despedida (PDF) por e-mail e SÓ DEPOIS apaga os dados e a conta.
/// O servidor repete a checagem (a tela é só experiência; a regra é do banco).
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _providers = ProviderService();
  final _confirm = TextEditingController();
  bool _busy = false;

  String get _email => Supabase.instance.client.auth.currentUser?.email ?? 'seu e-mail';
  bool get _typed => _confirm.text.trim().toUpperCase() == 'EXCLUIR';

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      final status = await _providers.deletionStatus();
      if (!mounted) return;
      if (status.hasBalance) {
        await _showPixSheet(status);
        return;
      }
      if (status.hasOngoing) {
        await _showOngoingSheet(status);
        return;
      }
      await _runOffboarding();
    } on DeletionBlocked {
      if (mounted) showSnack(context, 'Há saldo, valores em custódia ou serviço em andamento. Verifique e tente de novo.', error: true);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runOffboarding() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(children: [
            SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
            SizedBox(width: 16),
            Expanded(child: Text('Gerando seu Dossiê de Despedida e excluindo seus dados...')),
          ]),
        ),
      ),
    );
    try {
      await _providers.deleteAccount();
    } catch (e) {
      navigator.pop(); // fecha o diálogo de progresso
      rethrow;
    }
    // Sucesso: a conta não existe mais. Limpa o aparelho e volta ao Login.
    await LocalPrefs.remove(LocalPrefs.keyLastProfile);
    try {
      await ProfileService().signOut();
    } catch (_) {/* sessão já invalidada no servidor */}
    messenger.showSnackBar(SnackBar(content: Text('Conta excluída. Enviamos o Dossiê de Despedida para $_email.'), duration: const Duration(seconds: 8)));
    navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AuthGate()), (_) => false);
  }

  Future<void> _showPixSheet(DeletionStatus s) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => _BlockSheet(
        icon: Icons.warning_amber_rounded,
        title: '⚠️ Você possui fundos retidos',
        message: 'Transfira seu dinheiro para uma conta bancária externa de sua titularidade via Pix antes de excluir sua conta.\n\nSaldo disponível: ${brl(s.available)}.',
        actionLabel: 'Transferir via Pix',
        actionIcon: Icons.pix_rounded,
        onAction: () async {
          Navigator.pop(sheet);
          final done = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => PixWithdrawScreen(available: s.available)));
          if (done == true && mounted) showSnack(context, 'Saldo transferido. Agora você já pode excluir a conta.');
        },
      ),
    );
  }

  Future<void> _showOngoingSheet(DeletionStatus s) {
    final parts = <String>[
      if (s.activeJobs > 0) '${s.activeJobs} serviço(s) em andamento',
      if (s.held > 0) '${brl(s.held)} em custódia',
    ];
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => _BlockSheet(
        icon: Icons.hourglass_top_rounded,
        title: 'Ainda há pendências',
        message: 'Para proteger você e a outra parte, só é possível excluir a conta depois de concluir ou cancelar tudo: ${parts.isEmpty ? 'serviços e valores em aberto' : parts.join(' e ')}.',
        actionLabel: 'Entendi',
        onAction: () => Navigator.pop(sheet),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Scaffold(
      appBar: AppBar(title: const Text('Excluir conta')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          const InfoBanner('Esta ação é permanente e não pode ser desfeita.', tone: BannerTone.danger, icon: Icons.delete_forever_rounded),
          const SectionTitle('O que acontece'),
          _Bullet(Icons.mail_outline_rounded, 'Você recebe o Dossiê de Despedida (PDF) em $_email, com seu histórico, total gasto, total economizado e total de lucro.'),
          const _Bullet(Icons.delete_sweep_rounded, 'Excluímos seu perfil, documentos, fotos, mensagens e endereços.'),
          const _Bullet(Icons.gavel_rounded, 'Mantemos só os registros financeiros exigidos por lei, sem nome nem vínculo com você.'),
          const _Bullet(Icons.lock_outline_rounded, 'Se você é cliente e profissional, os DOIS perfis são excluídos.'),
          const SizedBox(height: 18),
          Text('Para confirmar, digite EXCLUIR', style: TextStyle(fontWeight: FontWeight.w800, color: tk.text)),
          const SizedBox(height: 8),
          TextField(
            controller: _confirm,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'EXCLUIR'),
          ),
        ],
      ),
      bottomNavigationBar: BottomBar(
        child: FilledButton.icon(
          onPressed: (_typed && !_busy) ? _delete : null,
          style: FilledButton.styleFrom(backgroundColor: tk.danger, foregroundColor: AppTokens.onColor(tk.danger)),
          icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.delete_forever_rounded),
          label: const Text('Excluir minha conta'),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 22, color: tk.textMuted),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: TextStyle(height: 1.4, color: tk.text))),
      ]),
    );
  }
}

class _BlockSheet extends StatelessWidget {
  const _BlockSheet({required this.icon, required this.title, required this.message, required this.actionLabel, required this.onAction, this.actionIcon});

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final IconData? actionIcon;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 44, color: tk.warningInk),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: tk.text)),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center, style: TextStyle(height: 1.4, color: tk.textMuted)),
          const SizedBox(height: 20),
          PrimaryButton(label: actionLabel, icon: actionIcon, onPressed: onAction),
        ]),
      ),
    );
  }
}
