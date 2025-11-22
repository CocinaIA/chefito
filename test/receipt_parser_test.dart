import 'package:flutter_test/flutter_test.dart';
import 'package:chefito/services/receipt_parser.dart';

void main() {
  group('ReceiptParser.cleanCandidates', () {
    test('filters admin noise and numbers/units', () {
      final input = [
        'BOGOTA DC',
        'gran contribuyente',
        'TABLE 5',
        'pan integral 500g',
        'Leche 2L',
        'Cebolla x3',
        'ARROZ 1000',
      ];
  final out = ReceiptParser.cleanCandidates(input);
  // Debug print to verify output
  // ignore: avoid_print
  print('CLEAN OUT: ' + out.join(', '));
      // noise removed
      expect(out.any((e) => e.toLowerCase().contains('bogota')), isFalse);
      expect(out.any((e) => e.toLowerCase().contains('gran contribuyente')), isFalse);
      expect(out.any((e) => e.toLowerCase().contains('table')), isFalse);
      // food kept and cleaned
  expect(out.contains('pan integral'), isTrue);
      expect(out.any((e) => e.toLowerCase() == 'leche'), isTrue);
      expect(out.any((e) => e.toLowerCase() == 'cebolla'), isTrue);
      expect(out.any((e) => e.toLowerCase() == 'arroz'), isTrue);
    });
  });
}
