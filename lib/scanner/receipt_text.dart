/// Text-based check used to refine the "Receipts & docs" heuristic after OCR.

const Map<String, String> _folds = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

final Map<int, String> _foldMap = {
  for (final e in _folds.entries)
    for (final r in e.value.runes) r: e.key,
};

/// Lower-cases and strips Vietnamese diacritics ("Tổng cộng" -> "tong cong").
String foldText(String s) {
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    b.write(_foldMap[r] ?? String.fromCharCode(r));
  }
  return b.toString();
}

const List<String> _keywords = [
  'total', 'subtotal', 'tong cong', 'tong tien', 'thanh toan', 'hoa don', 'invoice', 'receipt',
  'vat', 'thue', 'tax', 'cash', 'tien mat', 'tien thua', 'change', 'qty', 'so luong', 'don gia',
  'thanh tien', 'price', 'cam on', 'thank you', 'bill', 'ma so thue', 'payment', 'visa',
  'mastercard', 'so hoa don', 'order',
];

// Whole-word match, so "vat" does not fire inside "private" or "tax" inside "taxi".
final List<RegExp> _keywordRes = [for (final k in _keywords) RegExp('\\b$k\\b')];

final RegExp _money = RegExp(r'\b\d{1,3}([.,]\d{3})+\b|\b\d+[.,]\d{2}\b');
final RegExp _word = RegExp(r'[a-z0-9]{2,}');

/// True when recognised [text] looks like a receipt, invoice or text-heavy document.
bool looksLikeReceiptText(String text) {
  final t = foldText(text);
  final words = _word.allMatches(t).length;
  if (words < 12) return false;
  var hits = 0;
  for (final re in _keywordRes) {
    if (re.hasMatch(t)) hits++;
  }
  final money = _money.allMatches(t).length;
  if (hits >= 2) return true;
  if (hits >= 1 && money >= 2) return true;
  return words >= 80; // a full page of text (contract, letter, notes)
}
