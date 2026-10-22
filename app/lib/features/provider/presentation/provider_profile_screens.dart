import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/services/app_session.dart';
import '../../../core/services/draft_store.dart';
import '../../../core/services/media_service.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/image_picking.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';

/// Editar Perfil (protótipo P02): foto, título, bio, especialidades, preços.
/// Em [setupMode] vira o 1º passo do cadastro inicial (botão "Continuar").
class EditProviderProfileScreen extends StatefulWidget {
  const EditProviderProfileScreen({super.key, this.setupMode = false, this.onDone});

  final bool setupMode;
  final VoidCallback? onDone;

  @override
  State<EditProviderProfileScreen> createState() => _EditProviderProfileScreenState();
}

class _EditProviderProfileScreenState extends State<EditProviderProfileScreen> {
  final _profiles = ProfileService();
  final _providers = ProviderService();
  final _bio = TextEditingController();
  final _headline = TextEditingController();
  final _hourly = TextEditingController();
  final _visit = TextEditingController(text: '30');
  final _specialties = <String>{};
  double _radius = 15;
  String? _avatarUrl;
  String _name = '';
  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;
  Timer? _saveTimer;
  String? _draftKey;

  @override
  void initState() {
    super.initState();
    if (widget.setupMode) {
      _draftKey = DraftStore.keyFor('provider_setup');
      for (final c in [_bio, _headline, _hourly, _visit]) {
        c.addListener(_scheduleDraft);
      }
    }
    _load();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _bio.dispose();
    _headline.dispose();
    _hourly.dispose();
    _visit.dispose();
    super.dispose();
  }

  void _scheduleDraft() {
    if (_draftKey == null || _loading) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () => DraftStore.write(_draftKey!, {
          'bio': _bio.text,
          'headline': _headline.text,
          'hourly': _hourly.text,
          'visit': _visit.text,
          'specialties': _specialties.toList(),
          'radius': _radius,
        }));
  }

  /// No cadastro inicial, reaplica o que o usuário já tinha digitado antes de sair.
  Future<void> _applyDraft() async {
    final key = _draftKey;
    if (key == null) return;
    final d = await DraftStore.read(key);
    if (d == null || !mounted) return;
    setState(() {
      String s(String k) => (d[k] as String?) ?? '';
      if (s('bio').isNotEmpty) _bio.text = s('bio');
      if (s('headline').isNotEmpty) _headline.text = s('headline');
      if (s('hourly').isNotEmpty) _hourly.text = s('hourly');
      if (s('visit').isNotEmpty) _visit.text = s('visit');
      final sp = (d['specialties'] as List?)?.cast<String>() ?? const <String>[];
      if (sp.isNotEmpty) {
        _specialties
          ..clear()
          ..addAll(sp);
      }
      final r = (d['radius'] as num?)?.toDouble();
      if (r != null) _radius = r.clamp(1, 100);
    });
  }

  Future<void> _load() async {
    try {
      final p = await _profiles.fetchCurrent();
      final row = await _providers.myProviderRow();
      if (!mounted) return;
      setState(() {
        _name = p?.fullName ?? '';
        _avatarUrl = p?.avatarUrl;
        _bio.text = p?.bio ?? '';
        _headline.text = (row?['headline'] as String?) ?? '';
        _specialties.addAll(((row?['specialties'] as List?) ?? const []).cast<String>());
        final h = (row?['hourly_rate'] as num?)?.toDouble();
        if (h != null) _hourly.text = h.toStringAsFixed(h % 1 == 0 ? 0 : 2).replaceAll('.', ',');
        final v = (row?['visit_fee'] as num?)?.toDouble();
        if (v != null) _visit.text = v.toStringAsFixed(v % 1 == 0 ? 0 : 2).replaceAll('.', ',');
        _radius = ((row?['service_radius_km'] as num?)?.toDouble() ?? 15).clamp(1, 100);
        _loading = false;
      });
      await _applyDraft();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showSnack(context, friendlyError(e), error: true);
      }
    }
  }

  Future<void> _changePhoto() async {
    final img = await pickImage(context);
    if (img == null) return;
    setState(() => _uploading = true);
    try {
      final url = await MediaService().uploadPublic(img.bytes, img.ext, prefix: 'avatar');
      await _profiles.updateProfile({'avatar_url': url});
      if (mounted) setState(() => _avatarUrl = url);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (_specialties.isEmpty) {
      showSnack(context, 'Escolha ao menos uma especialidade.', error: true);
      return;
    }
    if (_bio.text.trim().length < 20) {
      showSnack(context, 'Conte um pouco sobre você (mín. 20 caracteres).', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await _profiles.updateProfile({'bio': _bio.text.trim()});
      await _providers.saveProviderProfile(
        headline: _headline.text.trim().isEmpty ? _specialties.first : _headline.text.trim(),
        specialties: _specialties.toList(),
        hourlyRate: parseBrl(_hourly.text),
        visitFee: parseBrl(_visit.text) ?? 30,
        radiusKm: _radius.round(),
      );
      AppSession.instance.refreshProfile();
      _saveTimer?.cancel();
      if (_draftKey != null) await DraftStore.clear(_draftKey!);
      if (!mounted) return;
      if (widget.setupMode) {
        widget.onDone?.call();
      } else {
        showSnack(context, 'Perfil atualizado!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.setupMode ? 'Seu perfil profissional' : 'Editar perfil'),
        automaticallyImplyLeading: !widget.setupMode,
      ),
      body: _loading
          ? const LoadingView()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                if (widget.setupMode) ...[
                  const StepperBar(total: 3, current: 1),
                  const SizedBox(height: 16),
                  const Text('Mostre quem você é', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text('Clientes escolhem quem tem foto, boa descrição e especialidades claras.',
                      style: TextStyle(color: AppColors.muted, height: 1.4)),
                  const SizedBox(height: 18),
                ],
                Center(
                  child: Stack(
                    children: [
                      UserAvatar(url: _avatarUrl, name: _name.isEmpty ? '?' : _name, radius: 62),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Material(
                          color: accent,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _uploading ? null : _changePhoto,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: _uploading
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const Text('Título profissional', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 8),
                TextField(controller: _headline, maxLength: 60, decoration: const InputDecoration(hintText: 'Ex: Eletricista residencial', counterText: '')),
                const SizedBox(height: 16),
                const Text('Sobre mim', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 8),
                TextField(
                  controller: _bio,
                  maxLines: 5,
                  maxLength: 500,
                  decoration: const InputDecoration(hintText: 'Descreva sua experiência em até 500 caracteres...'),
                ),
                const SizedBox(height: 8),
                const Text('Minhas especialidades', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in kCategories)
                      FilterChip(
                        label: Text('${_specialties.contains(c.name) ? '✓' : '+'} ${c.name}'),
                        selected: _specialties.contains(c.name),
                        showCheckmark: false,
                        selectedColor: accent,
                        labelStyle: TextStyle(color: _specialties.contains(c.name) ? Colors.white : AppColors.ink, fontWeight: FontWeight.w700),
                        onSelected: (v) {
                          setState(() => v ? _specialties.add(c.name) : _specialties.remove(c.name));
                          _scheduleDraft();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _visit,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Taxa de visita (R\$)', prefixText: 'R\$ '),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _hourly,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Valor/hora (opcional)', prefixText: 'R\$ '),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Raio de atendimento: ${_radius.round()} km', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                Slider(
                    value: _radius,
                    min: 1,
                    max: 100,
                    divisions: 99,
                    label: '${_radius.round()} km',
                    onChanged: (v) {
                      setState(() => _radius = v);
                      _scheduleDraft();
                    }),
              ],
            ),
      bottomNavigationBar: BottomBar(
        child: PrimaryButton(
          label: widget.setupMode ? 'Continuar' : 'Salvar alterações',
          trailingArrow: widget.setupMode,
          loading: _saving,
          onPressed: _loading ? null : _save,
        ),
      ),
    );
  }
}

/// Meu Portfólio (protótipo P03): fotos públicas dos trabalhos.
class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key, this.setupMode = false, this.onDone});

  final bool setupMode;
  final VoidCallback? onDone;

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  final _providers = ProviderService();
  late Future<List<PortfolioItem>> _future = _providers.portfolio(_providers.uid);
  bool _uploading = false;

  void _reload() => setState(() { _future = _providers.portfolio(_providers.uid); });

  Future<void> _add() async {
    final img = await pickImage(context);
    if (img == null) return;
    setState(() => _uploading = true);
    try {
      final path = await MediaService().uploadPublicPath(img.bytes, img.ext, prefix: 'portfolio');
      await _providers.addPortfolio(path);
      _reload();
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete(PortfolioItem item) async {
    final ok = await confirmDialog(context, title: 'Excluir foto?', message: 'Ela deixará de aparecer no seu perfil.', confirmLabel: 'Excluir', destructive: true);
    if (!ok) return;
    try {
      await _providers.deletePortfolio(item.id);
      _reload();
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meu Portfólio'), automaticallyImplyLeading: !widget.setupMode),
      body: FutureBuilder<List<PortfolioItem>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          final items = snap.data ?? const [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              if (widget.setupMode) ...[
                const StepperBar(total: 3, current: 2),
                const SizedBox(height: 16),
              ],
              const Text('Mostre a qualidade do seu trabalho para atrair mais clientes.', style: TextStyle(color: AppColors.muted, fontSize: 15, height: 1.4)),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  InkWell(
                    onTap: _uploading ? null : _add,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF3F8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF9FB3C8), width: 1.5),
                      ),
                      child: Center(
                        child: _uploading
                            ? const CircularProgressIndicator()
                            : const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_photo_alternate_outlined, size: 36, color: Color(0xFF0B3A6B)),
                                  SizedBox(height: 6),
                                  Text('Adicionar', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0B3A6B))),
                                ],
                              ),
                      ),
                    ),
                  ),
                  for (final it in items)
                    Stack(
                      fit: StackFit.expand,
                      children: [
                        PublicImage(path: it.imagePath, radius: 16),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => _delete(it),
                              child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.danger)),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 18),
                  child: InfoBanner('Fotos de antes e depois aumentam muito a confiança. Você também pode adicionar depois.', tone: BannerTone.info),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: widget.setupMode
          ? BottomBar(child: PrimaryButton(label: 'Continuar', trailingArrow: true, onPressed: widget.onDone))
          : null,
    );
  }
}

/// Meus Certificados (protótipo P04): cofre de qualificações.
class CertificatesScreen extends StatefulWidget {
  const CertificatesScreen({super.key});

  @override
  State<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends State<CertificatesScreen> {
  final _providers = ProviderService();
  late Future<List<Certificate>> _future = _providers.myCertificates();

  void _reload() => setState(() { _future = _providers.myCertificates(); });

  Future<void> _add() async {
    final title = TextEditingController();
    final issuer = TextEditingController();
    final year = TextEditingController();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Adicionar registro ou certificado', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Título (ex: Técnico em Eletrotécnica)')),
            const SizedBox(height: 10),
            TextField(controller: issuer, decoration: const InputDecoration(labelText: 'Emissor (ex: SENAI, CREA-MG)')),
            const SizedBox(height: 10),
            TextField(
              controller: year,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Ano de emissão (opcional)'),
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: 'Salvar no cofre', onPressed: () => Navigator.pop(ctx, true)),
          ],
        ),
      ),
    );
    if (saved == true && title.text.trim().isNotEmpty) {
      try {
        final y = int.tryParse(year.text.trim());
        await _providers.addCertificate(
          title: title.text.trim(),
          issuer: issuer.text.trim().isEmpty ? null : issuer.text.trim(),
          issuedAt: y == null ? null : DateTime(y),
        );
        _reload();
      } catch (e) {
        if (mounted) showSnack(context, friendlyError(e), error: true);
      }
    }
    title.dispose();
    issuer.dispose();
    year.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meus Certificados')),
      body: FutureBuilder<List<Certificate>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          final items = snap.data ?? const [];
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Center(child: CircleAvatar(radius: 34, backgroundColor: Color(0xFFE6EEFB), child: Icon(Icons.verified_user_rounded, size: 34, color: Color(0xFF0B3A6B)))),
              const SizedBox(height: 12),
              const Text('Certificações', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('Comprovar suas qualificações ajuda a conquistar a confiança dos clientes.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, height: 1.4)),
              const SizedBox(height: 18),
              for (final c in items)
                AppCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      const CircleAvatar(backgroundColor: AppColors.surface, child: Icon(Icons.workspace_premium_rounded, color: Color(0xFF0B3A6B))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                            Text([c.issuer, if (c.issuedAt != null) 'Emitido em ${c.issuedAt!.year}'].whereType<String>().join(' • '),
                                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                            const SizedBox(height: 6),
                            const StatusChip('Em análise', color: AppColors.warningInk, icon: Icons.schedule_rounded),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.muted),
                        onPressed: () async {
                          await _providers.deleteCertificate(c.id);
                          _reload();
                        },
                      ),
                    ],
                  ),
                ),
              if (items.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: Text('Nenhum certificado ainda.', style: TextStyle(color: AppColors.muted)))),
              const SizedBox(height: 8),
              SecondaryButton(label: '+ Adicionar registro ou certificado', onPressed: _add),
              const SizedBox(height: 12),
              const Center(child: Text('🔒 Seus dados são protegidos e visíveis só para você e a equipe.', style: TextStyle(fontSize: 12, color: AppColors.muted), textAlign: TextAlign.center)),
            ],
          );
        },
      ),
    );
  }
}
