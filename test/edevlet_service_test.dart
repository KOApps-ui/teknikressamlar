import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:teknik_ressamlar/core/services/edevlet_service.dart';

void main() {
  group('EDevletService Tests', () {
    test('Mask barcode formats correctly', () {
      expect(EDevletService.maskBarcode('1234'), '••••••••');
      expect(EDevletService.maskBarcode('ABCDEFGH'), 'AB •••• GH');
      expect(EDevletService.maskBarcode('YOK-2023-TR-9841'), 'YOK- •••••••• 9841');
      expect(EDevletService.maskBarcode('B2886F454378A2'), 'B288 •••••••• 78A2');
    });

    test('Extracts barcode from simulated e-Devlet YÖK PDF document', () async {
      final document = PdfDocument();
      final page = document.pages.add();
      page.graphics.drawString(
        'T.C. YÜKSEKÖĞRETİM KURULU BAŞKANLIĞI\n'
        'MEZUNİYET BELGESİ\n'
        'Ad Soyad: KEMALEDDİN ÖZÇELİK\n'
        'Üniversite: YILDIZ TEKNİK ÜNİVERSİTESİ\n'
        'Fakülte: MİMARLIK FAKÜLTESİ\n'
        'Bölüm: YAPI RESSAMLIĞI\n'
        'Barkod Numarası : YOK-2023-TR-9841\n'
        'Bu belge https://turkiye.gov.tr/belge-dogrulama adresinden veya karekod ile doğrulanabilir.',
        PdfStandardFont(PdfFontFamily.helvetica, 10),
      );
      final bytes = document.saveSync();
      document.dispose();

      final result = await EDevletService.extractFromPdfBytes(bytes);
      expect(result.success, true);
      expect(result.barcode, 'YOK-2023-TR-9841');
      expect(result.institution, contains('YÖK'));
      expect(result.maskedBarcode, 'YOK- •••••••• 9841');
    });

    test('Extracts alphanumeric e-Devlet barcode format', () async {
      final document = PdfDocument();
      final page = document.pages.add();
      page.graphics.drawString(
        'T.C. MİLLÎ EĞİTİM BAKANLIĞI\n'
        'MESLEKİ VE TEKNİK ANADOLU LİSESİ DİPLOMA BİLGİSİ\n'
        'Barkod No : B2886F454378A2\n'
        'Doğrulama: turkiye.gov.tr/belge-dogrulama',
        PdfStandardFont(PdfFontFamily.helvetica, 10),
      );
      final bytes = document.saveSync();
      document.dispose();

      final result = await EDevletService.extractFromPdfBytes(bytes);
      expect(result.success, true);
      expect(result.barcode, 'B2886F454378A2');
      expect(result.institution, contains('MEB'));
      expect(result.maskedBarcode, 'B288 •••••••• 78A2');
    });
  });
}
