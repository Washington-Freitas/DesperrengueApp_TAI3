import 'package:desperrengue_app/main.dart'; // Importa o seu novo main.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Verifica se a app arranca sem erros', (
    WidgetTester tester,
  ) async {
    // Constrói a nossa app e aciona o primeiro frame, envolvendo-a no ProviderScope exigido pelo Riverpod
    await tester.pumpWidget(const ProviderScope(child: DesperrengueApp()));

    // Verifica se encontra a palavra "Desperrengue" no ecrã (que está no título do LoginScreen)
    expect(find.text('Desperrengue'), findsWidgets);
  });
}
