class IngredientNormalizer {
  static final Map<String, String> _synonyms = {
    'jitomate': 'tomate',
    'tomates': 'tomate',
    'cebollas': 'cebolla',
    'papa': 'patata',
    'papas': 'patata',
    'patatas': 'patata',
    'aguacate': 'palta', // regional
    'aceite de oliva extra virgen': 'aceite de oliva',
  };

  /// Normalize raw ingredient candidates into canonical names.
  /// - lower case
  /// - remove common descriptors
  /// - map synonyms
  /// - singularize naive plurals (ending with 's')
  static List<String> normalize(List<String> raw) {
    final result = <String>{};
    for (var item in raw) {
      var s = item.toLowerCase().trim();
      // remove leading determiners/articles
      s = s.replaceFirst(RegExp(r'^\b(un|una|unos|unas|el|la|los|las)\b\s+'), '');
      // remove descriptors
      s = s.replaceAll(RegExp(r"\b(extra|virgen|org[aá]nico|fresco|mediano|grande|pequeño|premium)\b"), "");
      s = s.replaceAll(RegExp(r"\s{2,}"), " ").trim();

      // naive plural to singular
      if (s.endsWith('es')) {
        s = s.substring(0, s.length - 2);
      } else if (s.endsWith('s')) {
        s = s.substring(0, s.length - 1);
      }

      // synonyms
      if (_synonyms.containsKey(s)) {
        s = _synonyms[s]!;
      }

      // reduce to first 2 tokens max to avoid brand tails
      final tokens = s.split(' ').where((w) => w.isNotEmpty).toList();
      if (tokens.isEmpty) continue;
      s = tokens.take(2).join(' ');

      if (s.length >= 3) result.add(s);
    }
    return result.toList();
  }
}
