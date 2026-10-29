import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/theme_controller.dart';
import '../../../core/ui/app_tokens.dart';

/// Seletor de aparência (Automático · Claro · Escuro), persistido no cache.
/// Entrada: `showThemePicker(context)` a partir do Perfil (cliente e profissional).
Future<void> showThemePicker(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _ThemePickerSheet(),
    );

/// Linha de menu "Aparência" com o valor atual — usada nos dois perfis.
class AppearanceTile extends ConsumerWidget {
  const AppearanceTile({super.key, required this.accent, required this.soft});

  final Color accent;
  final Color soft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(backgroundColor: soft, child: Icon(mode.icon, color: accent)),
      title: const Text('Aparência', style: TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('Tema ${mode.label.toLowerCase()}'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => showThemePicker(context),
    );
  }
}

class _ThemePickerSheet extends ConsumerWidget {
  const _ThemePickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider);
    final tk = context.tk;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Aparência', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: tk.text)),
            const SizedBox(height: 4),
            Text('O modo escuro usa fundo #121212 e cores suavizadas para cansar menos a vista.', style: TextStyle(color: tk.textMuted, fontSize: 13)),
            const SizedBox(height: 12),
            RadioGroup<AppThemeMode>(
              groupValue: current,
              onChanged: (v) {
                if (v != null) ref.read(themeModeProvider.notifier).select(v);
              },
              child: Column(
                children: [
                  for (final m in AppThemeMode.values)
                    RadioListTile<AppThemeMode>(
                      contentPadding: EdgeInsets.zero,
                      value: m,
                      secondary: Icon(m.icon),
                      title: Text(m.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: m == AppThemeMode.system ? const Text('Segue o tema do aparelho') : null,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
