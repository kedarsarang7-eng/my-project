// ============================================================================
// ID CARD DESIGNER EVENTS
// ============================================================================

import 'package:equatable/equatable.dart';
import 'id_card_models.dart';

abstract class IDCardDesignerEvent extends Equatable {
  const IDCardDesignerEvent();

  @override
  List<Object?> get props => [];
}

/// Load staff data for ID card creation
class LoadStaffForIDCard extends IDCardDesignerEvent {
  final String staffId;

  const LoadStaffForIDCard({required this.staffId});

  @override
  List<Object?> get props => [staffId];
}

/// Update ID card settings
class UpdateSettings extends IDCardDesignerEvent {
  final IDCardSettings settings;

  const UpdateSettings(this.settings);

  @override
  List<Object?> get props => [settings];
}

/// Update staff photo
class UpdatePhoto extends IDCardDesignerEvent {
  final String photoPath;

  const UpdatePhoto({required this.photoPath});

  @override
  List<Object?> get props => [photoPath];
}

/// Print ID card to printer
class PrintIDCard extends IDCardDesignerEvent {
  const PrintIDCard();
}

/// Export ID card to file
class ExportIDCard extends IDCardDesignerEvent {
  final String format; // 'PDF' or 'PNG'
  final String? filePath;

  const ExportIDCard({required this.format, this.filePath});

  @override
  List<Object?> get props => [format, filePath];
}

/// Email ID card to staff
class EmailIDCard extends IDCardDesignerEvent {
  const EmailIDCard();
}

/// Print all staff cards (batch)
class PrintAllCards extends IDCardDesignerEvent {
  const PrintAllCards();
}

/// Download ID card template
class DownloadTemplate extends IDCardDesignerEvent {
  const DownloadTemplate();
}
