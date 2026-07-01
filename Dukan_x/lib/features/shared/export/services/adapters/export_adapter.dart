import '../../models/export_data.dart';

enum ExportFormat { pdf, excel, word }

abstract class ExportAdapter {
  /// Generates the document and returns the file bytes.
  Future<List<int>> generate(ExportData data);

  /// Returns the file extension (e.g., 'pdf', 'xlsx', 'docx').
  String get fileExtension;

  /// Returns the MIME type (e.g., 'application/pdf').
  String get contentType;
}
