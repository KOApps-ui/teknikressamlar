import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class EDevletExtractionResult {
  final bool success;
  final String? barcode;
  final String? maskedBarcode;
  final String? institution;
  final String? documentTitle;
  final String? rawText;
  final String? errorMessage;

  final String? taxNumber;

  const EDevletExtractionResult({
    required this.success,
    this.barcode,
    this.maskedBarcode,
    this.taxNumber,
    this.institution,
    this.documentTitle,
    this.rawText,
    this.errorMessage,
  });
}

class EDevletService {
  static const String verificationUrl = 'https://www.turkiye.gov.tr/belge-dogrulama';

  /// PDF dosyasından e-Devlet barkod numarasını, Vergi Levhasını ve belge bilgilerini otomatik ayıklar.
  static Future<EDevletExtractionResult> extractFromPdfBytes(List<int> bytes) async {
    PdfDocument? document;
    try {
      document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);
      final text = extractor.extractText();

      if (text.trim().isEmpty) {
        return const EDevletExtractionResult(
          success: false,
          errorMessage: 'PDF dosyasından metin okunamadı (Taranmış resim PDF olabilir).',
        );
      }

      // Kurum ve Belge Türü tespiti
      String? institution;
      String documentTitle = 'e-Devlet Barkodlu Belge';
      final upperText = text.toUpperCase();

      if (upperText.contains('VERGİ LEVHASI') ||
          upperText.contains('VERGI LEVHASI') ||
          upperText.contains('GELİR İDARESİ') ||
          upperText.contains('GELIR IDARESI') ||
          upperText.contains('GİB') ||
          upperText.contains('GIB')) {
        institution = 'GİB / Barkodlu Vergi Levhası';
        documentTitle = 'GİB Barkodlu Vergi Levhası';
      } else if (upperText.contains('YÜKSEK') ||
          upperText.contains('YUKSEK') ||
          upperText.contains('YÖK') ||
          upperText.contains('YOK') ||
          upperText.contains('ÜNİVERSİTE') ||
          upperText.contains('UNIVERSITE') ||
          upperText.contains('MEZUN')) {
        institution = 'YÖK / Üniversite Mezuniyeti';
        documentTitle = 'e-Devlet Barkodlu Mezuniyet Belgesi';
      } else if (upperText.contains('MİLL') ||
          upperText.contains('MILL') ||
          upperText.contains('MLL') ||
          upperText.contains('MEB') ||
          upperText.contains('LİSE') ||
          upperText.contains('LISE') ||
          upperText.contains('LSE') ||
          upperText.contains('DİPLOMA') ||
          upperText.contains('DPLOMA')) {
        institution = 'MEB / Teknik Lise & Meslek Diploması';
        documentTitle = 'MEB Barkodlu Diploma Belgesi';
      } else if (upperText.contains('MESLEKİ YETERLİLİK') || upperText.contains('MYK')) {
        institution = 'MYK / Mesleki Yeterlilik Belgesi';
        documentTitle = 'MYK Barkodlu Mesleki Yeterlilik Belgesi';
      } else {
        institution = 'e-Devlet Resmi Belgesi';
      }

      // VKN (Vergi Kimlik Numarası) Arama
      String? taxNumber;
      final vknMatch = RegExp(r'(?:Vergi\s*Kimlik\s*(?:Numara(?:s[ıiIİ]?)?|No)?|VKN)\s*[:\-=]?\s*([0-9]{10})', caseSensitive: false).firstMatch(text);
      if (vknMatch != null && vknMatch.group(1) != null) {
        taxNumber = vknMatch.group(1)!.trim();
      }

      // Barkod Deseni Arama
      final barcode = _findBarcodeInText(text) ?? taxNumber;

      if (barcode != null && barcode.isNotEmpty) {
        return EDevletExtractionResult(
          success: true,
          barcode: barcode,
          maskedBarcode: maskBarcode(barcode),
          taxNumber: taxNumber,
          institution: institution,
          documentTitle: documentTitle,
          rawText: text,
        );
      }

      return EDevletExtractionResult(
        success: false,
        rawText: text,
        institution: institution,
        errorMessage: 'Belgede geçerli bir e-Devlet barkod numarası bulunamadı.',
      );
    } catch (e) {
      return EDevletExtractionResult(
        success: false,
        errorMessage: 'PDF okuma hatası: $e',
      );
    } finally {
      document?.dispose();
    }
  }

  /// Metin içerisindeki e-Devlet barkod formatlarını tespit eder.
  static String? _findBarcodeInText(String text) {
    // 1. İki nokta veya ayraçlı formatlar: "Barkod Numarası : XXX", "Barkod No: XXX", "Doğrulama Kodu: XXX"
    final labelPatterns = [
      RegExp(r'(?:Barkod\s*(?:Numara(?:s[ıiIİ]?)?|No)?|Do[ğgG]?rulama\s*Kodu|Belge\s*(?:Takip\s*)?No|Barkod)\s*[:\-=]\s*([A-Za-z0-9\-]{6,36})', caseSensitive: false),
      RegExp(r'(?:Barkod\s*(?:Numara(?:s[ıiIİ]?)?|No)|Do[ğgG]?rulama\s*Kodu|Belge\s*No)\s+([A-Za-z0-9\-]{6,36})', caseSensitive: false),
      RegExp(r'turkiye\.gov\.tr\/belge-dogrulama[^\n\r]*\n\s*([A-Za-z0-9\-]{6,36})', caseSensitive: false),
      RegExp(r'belge-dogrulama[^\n\r]*\n\s*([A-Za-z0-9\-]{6,36})', caseSensitive: false),
      RegExp(r'\b([A-Za-z0-9]{4}-[A-Za-z0-9]{4}-[A-Za-z0-9]{4,10})\b'),
    ];

    for (final pattern in labelPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.group(1) != null) {
        final candidate = match.group(1)!.trim().replaceAll(' ', '');
        if (candidate.length >= 6 && _isValidBarcodeChars(candidate)) {
          return candidate.toUpperCase();
        }
      }
    }

    // 2. e-Devlet karekod altındaki standalone 10-24 karakterlik alfasayısal kodlar
    final standaloneRegex = RegExp(r'\b([A-Za-z0-9]{8,24})\b');
    final matches = standaloneRegex.allMatches(text);
    for (final m in matches) {
      final str = m.group(1)!.trim();
      // Hem rakam hem harf içermeli, 'MEZUNIYET', 'TURKIYE', 'BELGESI' gibi düz kelimeleri ele
      final hasDigit = RegExp(r'[0-9]').hasMatch(str);
      final hasLetter = RegExp(r'[A-Za-z]').hasMatch(str);
      if (hasDigit && hasLetter && _isValidBarcodeChars(str)) {
        return str.toUpperCase();
      }
    }

    return null;
  }

  static bool _isValidBarcodeChars(String str) {
    // Türkçe özel karakterler veya geçersiz semboller içermemeli
    return RegExp(r'^[A-Za-z0-9\-]+$').hasMatch(str);
  }

  /// Barkod numarasını maskeleyerek güvenli/kısmi biçimde döndürür.
  /// Örn: "YOK-2023-TR-9841" -> "YOK- •••••••• -9841"
  /// Örn: "B2886F454378A2"   -> "B288 •••••••• 78A2"
  static String maskBarcode(String barcode) {
    final clean = barcode.trim();
    if (clean.length <= 4) return '••••••••';
    if (clean.length <= 8) {
      return '${clean.substring(0, 2)} •••• ${clean.substring(clean.length - 2)}';
    }
    final prefix = clean.substring(0, 4);
    final suffix = clean.substring(clean.length - 4);
    return '$prefix •••••••• $suffix';
  }

  /// Barkodu panoya kopyalar ve kullanıcıya şık bir bildirim gösterir.
  static Future<void> copyToClipboard(BuildContext context, String barcode) async {
    await Clipboard.setData(ClipboardData(text: barcode.trim()));
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.statusSuccess,
          duration: const Duration(seconds: 4),
          content: Row(
            children: [
              const Icon(Icons.copy, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'e-Devlet Barkod No panoya kopyalandı! turkiye.gov.tr/belge-dogrulama adresinde teyit edebilirsiniz.',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  /// turkiye.gov.tr/belge-dogrulama adresini tarayıcıda açar, barkodu kopyalar.
  static Future<void> openOfficialVerificationPortal(BuildContext context, {String? barcode}) async {
    if (barcode != null && barcode.trim().isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: barcode.trim()));
    }

    final uri = Uri.parse(verificationUrl);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.statusDanger,
            content: Text('e-Devlet doğrulama sayfası tarayıcıda açılamadı.'),
          ),
        );
      } else if (context.mounted && barcode != null && barcode.trim().isNotEmpty) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.statusSuccess,
            duration: const Duration(seconds: 5),
            content: const Text(
              '✓ Barkod No kopyalandı! Açılan e-Devlet sayfasında "Barkod Numarası" kutusuna yapıştırarak doğrulayabilirsiniz.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.statusDanger,
            content: Text('Sayfa açılırken hata: $e'),
          ),
        );
      }
    }
  }
}
