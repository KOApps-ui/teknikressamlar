import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FileHelper {
  /// Uzantıya göre uygun kategori ikonunu döndürür
  static IconData getFileIcon(String extension) {
    final ext = extension.toLowerCase().replaceAll('.', '').trim();
    switch (ext) {
      // 2D CAD & Çizim
      case 'dwg':
      case 'dxf':
        return Icons.architecture;

      // 3D CAD & Katı Model
      case 'step':
      case 'stp':
      case 'iges':
      case 'igs':
      case 'stl':
      case 'x_t':
      case 'x_b':
        return Icons.view_in_ar;

      // SolidWorks / Inventor / CATIA / Creo Parça & Montaj
      case 'sldprt':
      case 'sldasm':
      case 'ipt':
      case 'iam':
      case 'catpart':
      case 'catproduct':
      case 'prt':
      case 'asm':
        return Icons.precision_manufacturing;

      // BIM & Mimari
      case 'rvt':
      case 'rfa':
      case 'ifc':
      case 'nwd':
      case 'nwc':
        return Icons.apartment;

      // 3D Mesh / Tasarım
      case 'skp':
        return Icons.home_work;
      case '3ds':
      case 'obj':
      case 'fbx':
      case 'blend':
      case 'dae':
        return Icons.view_in_ar;

      // Belgeler
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
      case 'odt':
        return Icons.description;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
      case 'rtf':
      case 'md':
      case 'log':
        return Icons.article;

      // Görseller
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
      case 'svg':
      case 'bmp':
      case 'tif':
      case 'tiff':
      case 'gif':
        return Icons.image;

      // Video & Multimedya
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
      case 'webm':
        return Icons.video_file;

      // Arşivler
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return Icons.folder_zip;

      // Kod & CAD Scriptleri
      case 'lsp':
      case 'dcl':
      case 'scr':
      case 'py':
      case 'json':
      case 'xml':
        return Icons.code;

      default:
        return Icons.insert_drive_file;
    }
  }

  /// Uzantıya göre tematik rengi döndürür
  static Color getFileColor(String extension) {
    final ext = extension.toLowerCase().replaceAll('.', '').trim();
    switch (ext) {
      // 2D CAD (Blueprint Cyan)
      case 'dwg':
      case 'dxf':
        return AppTheme.cyanLine;

      // 3D CAD & Katı Model (Amber)
      case 'step':
      case 'stp':
      case 'iges':
      case 'igs':
      case 'sldprt':
      case 'sldasm':
      case 'ipt':
      case 'iam':
      case 'stl':
        return AppTheme.amberSteel;

      // BIM (Teal)
      case 'rvt':
      case 'rfa':
      case 'ifc':
      case 'nwd':
        return const Color(0xFF00E676);

      // 3D Mesh & SketchUp (Orange/Purple)
      case 'skp':
        return const Color(0xFFFF9100);
      case 'obj':
      case 'fbx':
      case '3ds':
      case 'blend':
        return const Color(0xFFE040FB);

      // PDF (Kırmızı)
      case 'pdf':
        return const Color(0xFFFF5252);

      // Metin & Ofis Belgeleri
      case 'doc':
      case 'docx':
        return const Color(0xFF448AFF);
      case 'xls':
      case 'xlsx':
      case 'csv':
        return const Color(0xFF00C853);
      case 'ppt':
      case 'pptx':
        return const Color(0xFFFF6D00);

      // Görseller
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
      case 'svg':
        return const Color(0xFFBA68C8);

      // Arşivler
      case 'zip':
      case 'rar':
      case '7z':
        return const Color(0xFFFFD54F);

      default:
        return AppTheme.textSubtle;
    }
  }

  /// Uzun dosya isimlerini dengeli şekilde (başlangıç + ... + uzantı) kısaltır.
  /// Örn: "Proje_Detay_Kiris_Kolon_Baglanti_Final_Rev03.dwg" -> "Proje_Detay...Rev03.dwg"
  static String formatFileName(String name, {int maxLength = 26}) {
    if (name.length <= maxLength) return name;

    final dotIndex = name.lastIndexOf('.');
    final ext = dotIndex != -1 ? name.substring(dotIndex) : '';
    final base = dotIndex != -1 ? name.substring(0, dotIndex) : name;

    final maxBaseLen = maxLength - ext.length - 3;
    if (maxBaseLen <= 4) {
      if (name.length > maxLength) {
        return '${name.substring(0, maxLength - 3)}...$ext';
      }
      return name;
    }

    final startLen = (maxBaseLen / 2).ceil();
    final endLen = (maxBaseLen / 2).floor();

    final startPart = base.substring(0, startLen);
    final endPart = base.substring(base.length - endLen);

    return '$startPart...$endPart$ext';
  }

  /// Dosya boyutunu okunabilir formata çevirir (KB / MB / GB)
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Şık ve modern dosya rozeti widget'ı
  static Widget buildFileIconBadge(String extension, {double size = 42}) {
    final color = getFileColor(extension);
    final icon = getFileIcon(extension);
    final cleanExt = extension.toLowerCase().replaceAll('.', '').trim();
    final displayExt = cleanExt.length > 5 ? cleanExt.substring(0, 5) : cleanExt;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: size * 0.45, color: color),
          const SizedBox(height: 1),
          Text(
            displayExt.toUpperCase(),
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
