import 'package:flutter_test/flutter_test.dart';

import 'package:desperrengue_app/core/utils/smart_transcript_formatter.dart';

String f(String raw, {List<String>? segments}) => SmartTranscriptFormatter.format(raw, segments: segments);

void main() {
  group('SmartTranscriptFormatter', () {
    test('vazio e só espaço devolvem vazio', () {
      expect(f(''), '');
      expect(f('   \n  '), '');
    });

    test('capitaliza o início e fecha com ponto final', () {
      expect(f('o chuveiro parou de esquentar'), 'O chuveiro parou de esquentar.');
    });

    test('vírgula antes de conjunções adversativas/explicativas', () {
      expect(
        f('o disjuntor desarma toda hora mas já troquei o chuveiro'),
        'O disjuntor desarma toda hora, mas já troquei o chuveiro.',
      );
      expect(
        f('preciso de ajuda hoje porque a água não sai'),
        'Preciso de ajuda hoje, porque a água não sai.',
      );
    });

    test('não duplica vírgula já existente', () {
      expect(f('o disjuntor desarma, mas ninguém resolve'), 'O disjuntor desarma, mas ninguém resolve.');
    });

    test('perguntas ganham ponto de interrogação', () {
      expect(f('vocês conseguem vir amanhã'), 'Vocês conseguem vir amanhã?');
      expect(f('quanto custa a visita'), 'Quanto custa a visita?');
      expect(f('tem como trocar hoje'), 'Tem como trocar hoje?');
      expect(f('dá pra consertar sem quebrar a parede'), 'Dá pra consertar sem quebrar a parede?');
      expect(f('fica pronto hoje né'), 'Fica pronto hoje né?');
    });

    test('afirmações NÃO viram pergunta', () {
      expect(f('a pia está vazando muito'), 'A pia está vazando muito.');
    });

    test('vários períodos: respeita pontuação existente e capitaliza cada um', () {
      expect(
        f('a torneira vaza. já tentei fechar o registro! não adiantou'),
        'A torneira vaza. Já tentei fechar o registro! Não adiantou.',
      );
    });

    test('comandos falados de pontuação', () {
      expect(f('a pia entupiu vírgula e a água não desce ponto final'), 'A pia entupiu, e a água não desce.');
      expect(f('vocês atendem sábado ponto de interrogação'), 'Vocês atendem sábado?');
      expect(f('socorro ponto de exclamação'), 'Socorro!');
    });

    test('remove hesitações e palavras repetidas por gagueira', () {
      expect(f('ééé o o chuveiro hum parou'), 'O chuveiro parou.');
      expect(f('ahn a a tomada está solta'), 'A tomada está solta.');
    });

    test('preserva decimais', () {
      expect(f('preciso de uma prateleira de 2.5 metros'), 'Preciso de uma prateleira de 2.5 metros.');
    });

    test('segmentos por pausa: curto vira vírgula, período cheio vira ponto', () {
      expect(
        f('', segments: ['o chuveiro queimou', 'e preciso trocar hoje']),
        'O chuveiro queimou, e preciso trocar hoje.',
      );
      expect(
        f('', segments: ['o chuveiro queimou de vez ontem à noite', 'preciso trocar hoje']),
        'O chuveiro queimou de vez ontem à noite. Preciso trocar hoje.',
      );
    });

    test('texto longo sem pontuação é quebrado em marcadores de discurso', () {
      final out = f(
        'minha casa é antiga e a fiação já deu problema outras vezes aí hoje o chuveiro começou a desarmar o disjuntor toda vez que ligo',
      );
      expect(out.split('.').where((s) => s.trim().isNotEmpty).length, greaterThanOrEqualTo(2));
      expect(out, startsWith('Minha casa'));
      expect(out, contains('Aí hoje'));
      expect(out.endsWith('.'), isTrue);
    });

    test('é idempotente para texto já organizado', () {
      const ok = 'O disjuntor desarma, mas ninguém resolve. Vocês conseguem vir amanhã?';
      expect(f(ok), ok);
    });

    test('append junta ao texto digitado sem duplicar pontuação', () {
      expect(SmartTranscriptFormatter.append('', 'Olá.'), 'Olá.');
      expect(SmartTranscriptFormatter.append('Já digitei isto.', 'Falei isto.'), 'Já digitei isto. Falei isto.');
      expect(SmartTranscriptFormatter.append('Sem ponto', 'Falei isto.'), 'Sem ponto. Falei isto.');
      expect(SmartTranscriptFormatter.append('Texto', ''), 'Texto');
    });
  });
}
