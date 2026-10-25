import 'package:flutter_test/flutter_test.dart';
import 'package:photo_cleaner/scanner/receipt_text.dart';

void main() {
  test('foldText strips Vietnamese diacritics', () {
    expect(foldText('Tổng cộng'), 'tong cong');
    expect(foldText('HÓA ĐƠN BÁN HÀNG'), 'hoa don ban hang');
    expect(foldText('Cảm ơn quý khách'), 'cam on quy khach');
  });

  test('Vietnamese receipt is recognised', () {
    const t = '''CỬA HÀNG TIỆN LỢI ABC
HÓA ĐƠN BÁN HÀNG
Bánh mì 1 x 25.000 25.000
Nước suối 2 x 10.000 20.000
Sữa tươi 1 x 32.000 32.000
Tổng cộng 77.000
Tiền mặt 100.000
Tiền thừa 23.000
Cảm ơn quý khách''';
    expect(looksLikeReceiptText(t), true);
  });

  test('English receipt is recognised', () {
    const t = '''COFFEE HOUSE
Latte 2 x 4.50 9.00
Croissant 1 x 3.25 3.25
Subtotal 12.25
Tax 0.98
Total 13.23
Thank you for visiting see you again soon''';
    expect(looksLikeReceiptText(t), true);
  });

  test('a few words or a landscape caption is rejected', () {
    expect(looksLikeReceiptText(''), false);
    expect(looksLikeReceiptText('Sunset at the beach 2024'), false);
  });

  test('long plain text page counts as a document', () {
    final t = List.filled(90, 'lorem ipsum dolor').join(' ');
    expect(looksLikeReceiptText(t), true);
  });

  test('enough words but no signals is rejected', () {
    const t = 'this is a photo of my dog playing in the garden with a ball on a sunny day today';
    expect(looksLikeReceiptText(t), false);
  });

  test('keywords match whole words only', () {
    // "private" contains "vat", "taxi" contains "tax": must not count as receipt signals.
    const t = 'the private taxi ride through the valley was lovely and we saw many birds on the way home';
    expect(looksLikeReceiptText(t), false);
  });
}
