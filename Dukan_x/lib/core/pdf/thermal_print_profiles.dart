enum PrintPaperSize { mm58, mm80, a4 }

class ThermalPrintProfile {
  final PrintPaperSize size;
  final double pageWidthMm;
  final int maxCharsPerLine;

  const ThermalPrintProfile({
    required this.size,
    required this.pageWidthMm,
    required this.maxCharsPerLine,
  });
}

const thermal58Profile = ThermalPrintProfile(
  size: PrintPaperSize.mm58,
  pageWidthMm: 58,
  maxCharsPerLine: 32,
);

const thermal80Profile = ThermalPrintProfile(
  size: PrintPaperSize.mm80,
  pageWidthMm: 80,
  maxCharsPerLine: 44,
);

const a4Profile = ThermalPrintProfile(
  size: PrintPaperSize.a4,
  pageWidthMm: 210,
  maxCharsPerLine: 90,
);
