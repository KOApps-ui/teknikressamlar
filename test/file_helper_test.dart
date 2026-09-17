import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teknik_ressamlar/core/utils/file_helper.dart';

void main() {
  group('FileHelper Tests', () {
    test('Resolves icons for various file extensions', () {
      expect(FileHelper.getFileIcon('dwg'), Icons.architecture);
      expect(FileHelper.getFileIcon('dxf'), Icons.architecture);
      expect(FileHelper.getFileIcon('step'), Icons.view_in_ar);
      expect(FileHelper.getFileIcon('sldprt'), Icons.precision_manufacturing);
      expect(FileHelper.getFileIcon('rvt'), Icons.apartment);
      expect(FileHelper.getFileIcon('pdf'), Icons.picture_as_pdf);
      expect(FileHelper.getFileIcon('zip'), Icons.folder_zip);
      expect(FileHelper.getFileIcon('docx'), Icons.description);
      expect(FileHelper.getFileIcon('xlsx'), Icons.table_chart);
    });

    test('Shortens long file names with balanced truncation', () {
      expect(FileHelper.formatFileName('kisa.dwg', maxLength: 20), 'kisa.dwg');

      const longName = 'Celik_Sanayi_Yapisi_Aks_Plani_Detay_Kesit_Rev04.dwg';
      final formatted = FileHelper.formatFileName(longName, maxLength: 24);
      expect(formatted.length <= 26, true);
      expect(formatted.startsWith('Celik_'), true);
      expect(formatted.endsWith('.dwg'), true);
      expect(formatted.contains('...'), true);
    });

    test('Formats file sizes cleanly', () {
      expect(FileHelper.formatFileSize(500), '500 B');
      expect(FileHelper.formatFileSize(1024 * 150), '150.0 KB');
      expect(FileHelper.formatFileSize(1024 * 1024 * 25), '25.0 MB');
    });
  });
}
