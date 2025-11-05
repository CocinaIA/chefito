class ReceiptParser {
  /// Very simple heuristics to extract potential ingredient lines from receipt text.
  /// - Splits by lines
  /// - Filters out lines with prices or totals
  /// - Removes quantities and units
  /// Returns raw ingredient candidates (not normalized)
  static List<String> parse(String text) {
  final lines = text
        .split(RegExp(r"\r?\n"))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

  final candidates = <String>[];
  // Expand blacklist to aggressively drop administrative/noise tokens often seen in receipts/NCR outputs
  final discardWords = RegExp(
    r"\b(total|iva|subtotal|impuestos|resumen|cambio|pago|rrn|cliente|consumidor|nit|nif|tel|telefono|direcci[oó]n|bogota|bogot[aá]|colombia|dc|fecha|hora|aut|autorizaci[oó]n|c[oó]digo|codigo|cod|valor|base|excluido|resoluci[oó]n|num|art|generaci[oó]n|gran\s+contribuyente|ncr|trx|entregados?|table|caja|factura|tienda|sucursal|vendedor|por|wendy|medio|pago|efectivo|cajero|turno|recibo|comprobante)\b",
    caseSensitive: false);
  final priceToken = RegExp(r"\b\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})\b");
  final longNumber = RegExp(r"\b\d{6,}\b");
  final leadingArticle = RegExp(r'^\b(un|una|unos|unas|el|la|los|las)\b\s+', caseSensitive: false);
  final foodHints = <String>{
    'jugo','naranja','arepa','tostada','sandwich','sándwich','pan','leche','arroz','pollo','carne','queso','tomate','cebolla','yogur','yogurt','pasta','aceite','harina','huevo','huevos','cereal','galleta','tortilla','sal','azucar','azúcar','cafe','café','jamon','jamón','pavo','atun','atún','yuca','platano','plátano','mezcla','salsa','nuez','manzana','pera','uva','maiz','maíz','lenteja','frijol','papa','papas','banano','banana','limon','limón','maracuya','maracuyá','fresa','cerdo','res','pescado','cerveza','vino','agua','refresco','gaseosa','yautia','zanahoria','pepino','lechuga','espinaca','ajo','jengibre','mantequilla','margarina','salchicha','salami','mortadela'
  };

    for (var line in lines) {
    if (line.length < 3) continue;

  // Remove leading prices and long numeric tokens but keep trailing description
    var work = line;
    // Remove prices anywhere
    work = work.replaceAll(priceToken, ' ');
    // Remove long codes (EAN/SKU)
    work = work.replaceAll(longNumber, ' ');
    // Remove quantities and units
    work = work
      .replaceAll(RegExp(r"\b(kg|g|gr|gramos|ml|l|lt|u|ud|uds|pack|bot|botella|pz|pz\.)\b",
        caseSensitive: false),
        " ")
      .replaceAll(RegExp(r"\b\d+[xX]?\b"), " ")
      .replaceAll(RegExp(r"\s{2,}"), " ")
      .trim();

      // remove trailing punctuation
    var cleaned = work.replaceAll(RegExp(r"[\.:,;-]+$"), "").trim();

      if (cleaned.isEmpty) continue;

    // discard administrative words
    if (discardWords.hasMatch(cleaned)) continue;

      // keep only letters and spaces mostly
      final lettersSpaces = cleaned.replaceAll(RegExp(r"[^A-Za-zÁÉÍÓÚáéíóúÑñ\s]"), "").trim();
      var phrase = lettersSpaces.replaceFirst(leadingArticle, '').trim();
      final tokens = phrase.split(' ').where((w) => w.isNotEmpty).toList();
      if (tokens.isEmpty) continue;

      // prefer items containing at least one food hint, or having >=2 tokens
      final hasHint = tokens.any((t) => foodHints.contains(t.toLowerCase()));
      if (!hasHint && tokens.length < 2) continue;

      // limit to 2-3 tokens to avoid cola administrativa
      if (tokens.length > 3) {
        phrase = tokens.take(3).join(' ');
      }

      candidates.add(phrase);
    }

    return candidates;
  }

  /// Cleans a list of candidate strings (e.g., from Nanonets) using the same
  /// heuristics as [parse]. Returns filtered short phrases likely to be foods.
  static List<String> cleanCandidates(List<String> raw) {
    final out = <String>{}; // use a set to dedupe

    final discardWords = RegExp(
      r"\b(total|iva|subtotal|impuestos|resumen|cambio|pago|rrn|cliente|consumidor|nit|nif|tel|telefono|direcci[oó]n|bogota|bogot[aá]|colombia|dc|fecha|hora|aut|autorizaci[oó]n|c[oó]digo|codigo|cod|valor|base|excluido|resoluci[oó]n|num|art|generaci[oó]n|gran\s+contribuyente|ncr|trx|entregados?|table|caja|factura|tienda|sucursal|vendedor|por|wendy|medio|pago|efectivo|cajero|turno|recibo|comprobante)\b",
      caseSensitive: false);
  final numbers = RegExp(r"\b\d{1,}(?:[.,]\d+)?\b");
  // patterns like "3x", "x3" or just "x" multipliers
  final multipliers = RegExp(r"\b\d+[xX]?\b|\b[xX]\d+\b|\b[xX]\b");
    final units = RegExp(r"\b(kg|g|gr|gramos|ml|l|lt|u|ud|uds|pack|bot|botella|pz|pz\.)\b", caseSensitive: false);
    final leadingArticle = RegExp(r'^\b(un|una|unos|unas|el|la|los|las)\b\s+', caseSensitive: false);

    bool looksFood(String s) {
      final tokens = s.toLowerCase().split(RegExp(r"\s+")).where((t)=>t.isNotEmpty).toList();
      if (tokens.isEmpty) return false;
      // must either contain a food hint OR be 2+ tokens
      const hints = {
        'jugo','naranja','arepa','tostada','sandwich','sándwich','pan','leche','arroz','pollo','carne','queso','tomate','cebolla','yogur','yogurt','pasta','aceite','harina','huevo','huevos','cereal','galleta','tortilla','sal','azucar','azúcar','cafe','café','jamon','jamón','pavo','atun','atún','yuca','platano','plátano','mezcla','salsa','nuez','manzana','pera','uva','maiz','maíz','lenteja','frijol','papa','papas','banano','banana','limon','limón','maracuya','maracuyá','fresa','cerdo','res','pescado','cerveza','vino','agua','refresco','gaseosa','zanahoria','pepino','lechuga','espinaca','ajo','jengibre','mantequilla','margarina','salchicha','salami','mortadela'
      };
      final hasHint = tokens.any(hints.contains);
      return hasHint || tokens.length >= 2;
    }

    for (var line in raw) {
      var s = line.trim();
      if (s.isEmpty) continue;
      if (discardWords.hasMatch(s)) continue;
      s = s.replaceAll(numbers, ' ');
  s = s.replaceAll(multipliers, ' ');
      s = s.replaceAll(units, ' ');
      s = s.replaceAll(RegExp(r"[^A-Za-zÁÉÍÓÚáéíóúÑñ\s]"), ' ').replaceAll(RegExp(r"\s{2,}"), ' ').trim();
      s = s.replaceFirst(leadingArticle, '').trim();
      if (s.length < 2) continue;
      // Drop stray unit/multiplier tokens at token level
      final unitTokens = {
        'kg','g','gr','gramos','ml','l','lt','u','ud','uds','pack','bot','botella','pz'
      };
      var toks = s.split(RegExp(r"\s+")).where((t)=>t.isNotEmpty).toList();
      toks = toks.where((t) {
        final tl = t.toLowerCase();
        if (unitTokens.contains(tl)) return false;
        if (tl == 'x') return false;
        return true;
      }).toList();
      if (toks.isEmpty) continue;
      s = toks.join(' ');
      if (!looksFood(s)) continue;
      // truncate to max 3 tokens
      toks = s.split(RegExp(r"\s+")).where((t)=>t.isNotEmpty).toList();
      if (toks.length > 3) s = toks.take(3).join(' ');
      out.add(s);
    }

    return out.toList();
  }
}
