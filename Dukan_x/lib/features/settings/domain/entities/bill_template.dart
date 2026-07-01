import 'package:equatable/equatable.dart';

class BillTemplate extends Equatable {
  final String id;
  final String name;
  final bool showLogo;
  final bool showShopName;
  final bool showAddress;
  final bool showPhone;
  final bool showTax;
  final String headerAlignment; // 'left', 'center', 'right'
  final String footerText;

  const BillTemplate({
    this.id = 'default',
    this.name = 'Standard',
    this.showLogo = true,
    this.showShopName = true,
    this.showAddress = true,
    this.showPhone = true,
    this.showTax = true,
    this.headerAlignment = 'center',
    this.footerText = 'Thank you for shopping!',
  });

  @override
  List<Object?> get props => [
    id,
    name,
    showLogo,
    showShopName,
    showAddress,
    showPhone,
    showTax,
    headerAlignment,
    footerText,
  ];

  BillTemplate copyWith({
    String? id,
    String? name,
    bool? showLogo,
    bool? showShopName,
    bool? showAddress,
    bool? showPhone,
    bool? showTax,
    String? headerAlignment,
    String? footerText,
  }) {
    return BillTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      showLogo: showLogo ?? this.showLogo,
      showShopName: showShopName ?? this.showShopName,
      showAddress: showAddress ?? this.showAddress,
      showPhone: showPhone ?? this.showPhone,
      showTax: showTax ?? this.showTax,
      headerAlignment: headerAlignment ?? this.headerAlignment,
      footerText: footerText ?? this.footerText,
    );
  }
}
