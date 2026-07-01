// Amount to Words Converter - Multi-Language Support
// Converts numeric amounts to words in Indian numbering system (Lakh/Crore)
//
// Created: 2024-12-26
// Author: DukanX Team

import '../../../services/invoice_pdf_service.dart' show InvoiceLanguage;

/// Multi-language amount to words converter
/// Supports Indian numbering system (Lakh, Crore) for all languages
class AmountToWords {
  /// Convert amount to words in specified language
  static String convert(double amount, InvoiceLanguage language) {
    switch (language) {
      case InvoiceLanguage.hindi:
        return _convertToHindi(amount);
      case InvoiceLanguage.marathi:
        return _convertToMarathi(amount);
      default:
        return _convertToEnglish(amount);
    }
  }

  // ========== ENGLISH CONVERSION ==========

  static String _convertToEnglish(double amount) {
    if (amount == 0) return 'Rupees Zero Only';

    final rupees = amount.floor();
    final paise = ((amount - rupees) * 100).round();

    String result = 'Rupees ${_numberToWordsEnglish(rupees)}';
    if (paise > 0) {
      result += ' and ${_numberToWordsEnglish(paise)} Paise';
    }
    result += ' Only';

    return result;
  }

  static String _numberToWordsEnglish(int number) {
    if (number == 0) return 'Zero';

    const ones = [
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen',
    ];
    const tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety',
    ];

    if (number < 20) {
      return ones[number];
    }
    if (number < 100) {
      return '${tens[number ~/ 10]}${number % 10 > 0 ? ' ${ones[number % 10]}' : ''}';
    }
    if (number < 1000) {
      return '${ones[number ~/ 100]} Hundred${number % 100 > 0 ? ' ${_numberToWordsEnglish(number % 100)}' : ''}';
    }
    if (number < 100000) {
      return '${_numberToWordsEnglish(number ~/ 1000)} Thousand${number % 1000 > 0 ? ' ${_numberToWordsEnglish(number % 1000)}' : ''}';
    }
    if (number < 10000000) {
      return '${_numberToWordsEnglish(number ~/ 100000)} Lakh${number % 100000 > 0 ? ' ${_numberToWordsEnglish(number % 100000)}' : ''}';
    }
    return '${_numberToWordsEnglish(number ~/ 10000000)} Crore${number % 10000000 > 0 ? ' ${_numberToWordsEnglish(number % 10000000)}' : ''}';
  }

  // ========== HINDI CONVERSION ==========

  static const _hindiNumbers = [
    "\u0936\u0942\u0928\u094d\u092f", // शून्य
    "\u090f\u0915", // एक
    "\u0926\u094b", // दो
    "\u0924\u0940\u0928", // तीन
    "\u091a\u093e\u0930", // चार
    "\u092a\u093e\u0902\u091a", // पांच
    "\u091b\u0939", // छह
    "\u0938\u093e\u0924", // सात
    "\u0906\u0920", // आठ
    "\u0928\u094c", // नौ
    "\u0926\u0938", // दस
    "\u0917\u094d\u092f\u093e\u0930\u0939", // ग्यारह
    "\u092c\u093e\u0930\u0939", // बारह
    "\u0924\u0947\u0930\u0939", // तेरह
    "\u091a\u094c\u0926\u0939", // चौदह
    "\u092a\u0902\u0926\u094d\u0930\u0939", // पंद्रह
    "\u0938\u094b\u0932\u0939", // सोलह
    "\u0938\u0924\u094d\u0930\u0939", // सत्रह
    "\u0905\u0920\u093e\u0930\u0939", // अठारह
    "\u0909\u0928\u094d\u0928\u0940\u0938", // उन्नीस
    "\u092c\u0940\u0938", // बीस
    "\u0907\u0915\u094d\u0915\u0940\u0938", // इक्कीस
    "\u092c\u093e\u0908\u0938", // बाईस
    "\u0924\u0947\u0908\u0938", // तेईस
    "\u091a\u094c\u092c\u0940\u0938", // चौबीस
    "\u092a\u091a\u094d\u091a\u0940\u0938", // पच्चीस
    "\u091b\u092c\u094d\u092c\u0940\u0938", // छब्बीस
    "\u0938\u0924\u094d\u0924\u093e\u0908\u0938", // सत्ताईस
    "\u0905\u0920\u094d\u0920\u093e\u0908\u0938", // अठ्ठाईस
    "\u0909\u0928\u0924\u0940\u0938", // उनतीस
    "\u0924\u0940\u0938", // तीस
    "\u0907\u0915\u0924\u0940\u0938", // इकतीस
    "\u092c\u0924\u094d\u0924\u0940\u0938", // बत्तीस
    "\u0924\u0948\u0902\u0924\u0940\u0938", // तैंतीस
    "\u091a\u094c\u0902\u0924\u0940\u0938", // चौंतीस
    "\u092a\u0948\u0902\u0924\u0940\u0938", // पैंतीस
    "\u091b\u0924\u094d\u0924\u0940\u0938", // छत्तीस
    "\u0938\u0948\u0902\u0924\u0940\u0938", // सैंतीस
    "\u0905\u0921\u093c\u0924\u0940\u0938", // अड़तीस
    "\u0909\u0928\u0924\u093e\u0932\u0940\u0938", // उनतालीस
    "\u091a\u093e\u0932\u0940\u0938", // चालीस
    "\u0907\u0915\u0924\u093e\u0932\u0940\u0938", // इकतालीस
    "\u092c\u092f\u093e\u0932\u0940\u0938", // बयालीस
    "\u0924\u0948\u0902\u0924\u093e\u0932\u0940\u0938", // तैंतालीस
    "\u091a\u0935\u093e\u0932\u0940\u0938", // चवालीस
    "\u092a\u0948\u0902\u0924\u093e\u0932\u0940\u0938", // पैंतालीस
    "\u091b\u093f\u092f\u093e\u0932\u0940\u0938", // छियालीस
    "\u0938\u0948\u0902\u0924\u093e\u0932\u0940\u0938", // सैंतालीस
    "\u0905\u0921\u093c\u0924\u093e\u0932\u0940\u0938", // अड़तालीस
    "\u0909\u0928\u091a\u093e\u0938", // उनचास
    "\u092a\u091a\u093e\u0938", // पचास
    "\u0907\u0915\u094d\u092f\u093e\u0935\u0928", // इक्यावन
    "\u092c\u093e\u0935\u0928", // बावन
    "\u0924\u093f\u0930\u092a\u0928", // तिरपन
    "\u091a\u094c\u0935\u0928", // चौवन
    "\u092a\u091a\u092a\u0928", // पचपन
    "\u091b\u092a\u094d\u092a\u0928", // छप्पन
    "\u0938\u0924\u094d\u0924\u093e\u0935\u0928", // सत्तावन
    "\u0905\u0920\u094d\u0920\u093e\u0935\u0928", // अठ्ठावन
    "\u0909\u0928\u0938\u0920", // उनसठ
    "\u0938\u093e\u0920", // साठ
    "\u0907\u0915\u0938\u0920", // इकसठ
    "\u092c\u093e\u0938\u0920", // बासठ
    "\u0924\u093f\u0930\u0938\u0920", // तिरसठ
    "\u091a\u094c\u0902\u0938\u0920", // चौंसठ
    "\u092a\u0948\u0902\u0938\u0920", // पैंसठ
    "\u091b\u093f\u092f\u093e\u0938\u0920", // छियासठ
    "\u0938\u0930\u0938\u0920", // सरसठ
    "\u0905\u0921\u093c\u0938\u0920", // अड़सठ
    "\u0909\u0928\u0939\u0924\u094d\u0924\u0930", // उनहत्तर
    "\u0938\u0924\u094d\u0924\u0930", // सत्तर
    "\u0907\u0915\u0939\u0924\u094d\u0924\u0930", // इकहत्तर
    "\u092c\u0939\u0924\u094d\u0924\u0930", // बहत्तर
    "\u0924\u093f\u0939\u0924\u094d\u0924\u0930", // तिहत्तर
    "\u091a\u094c\u0939\u0924\u094d\u0924\u0930", // चौहत्तर
    "\u092a\u091a\u0939\u0924\u094d\u0924\u0930", // पचहत्तर
    "\u091b\u093f\u0939\u0924\u094d\u0924\u0930", // छिहत्तर
    "\u0938\u0924\u0939\u0924\u094d\u0924\u0930", // सतहत्तर
    "\u0905\u0920\u0939\u0924\u094d\u0924\u0930", // अठहत्तर
    "\u0909\u0928\u093e\u0938\u0940", // उनासी
    "\u0905\u0938\u094d\u0938\u0940", // अस्सी
    "\u0907\u0915\u094d\u092f\u093e\u0938\u0940", // इक्यासी
    "\u092c\u092f\u093e\u0938\u0940", // बयासी
    "\u0924\u093f\u0930\u093e\u0938\u0940", // तिरासी
    "\u091a\u094c\u0930\u093e\u0938\u0940", // चौरासी
    "\u092a\u091a\u093e\u0938\u0940", // पचासी
    "\u091b\u093f\u092f\u093e\u0938\u0940", // छियासी
    "\u0938\u0924\u094d\u0924\u093e\u0938\u0940", // सत्तासी
    "\u0905\u0920\u094d\u0920\u093e\u0938\u0940", // अठ्ठासी
    "\u0928\u0935\u093e\u0938\u0940", // नवासी
    "\u0928\u092c\u094d\u092c\u0947", // नब्बे
    "\u0907\u0915\u094d\u092f\u093e\u0928\u0935\u0947", // इक्यानवे
    "\u092c\u093e\u0928\u0935\u0947", // बानवे
    "\u0924\u093f\u0930\u093e\u0928\u0935\u0947", // तिरानवे
    "\u091a\u094c\u0930\u093e\u0928\u0935\u0947", // चौरानवे
    "\u092a\u0902\u091a\u093e\u0928\u0935\u0947", // पंचानवे
    "\u091b\u093f\u092f\u093e\u0928\u0935\u0947", // छियानवे
    "\u0938\u0924\u094d\u0924\u093e\u0928\u0935\u0947", // सत्तानवे
    "\u0905\u0920\u094d\u0920\u093e\u0928\u0935\u0947", // अठ्ठानवे
    "\u0928\u093f\u0928\u094d\u092f\u093e\u0928\u0935\u0947", // निन्यानवे
  ];

  static String _convertToHindi(double amount) {
    if (amount == 0) return '\u0930\u0941\u092a\u092f\u0947 \u0936\u0942\u0928\u094d\u092f \u092e\u093e\u0924\u094d\u0930';

    final rupees = amount.floor();
    final paise = ((amount - rupees) * 100).round();

    String result = '\u0930\u0941\u092a\u092f\u0947 ${_numberToWordsHindi(rupees)}';
    if (paise > 0) {
      result += ' \u0914\u0930 ${_numberToWordsHindi(paise)} \u092a\u0948\u0938\u0947';
    }
    result += ' \u092e\u093e\u0924\u094d\u0930';

    return result;
  }

  static String _numberToWordsHindi(int number) {
    if (number == 0) return '\u0936\u0942\u0928\u094d\u092f';

    if (number < 100) {
      return _hindiNumbers[number];
    }
    if (number < 1000) {
      final hundred = number ~/ 100;
      final remainder = number % 100;
      String result = '';
      if (hundred == 1) {
        result = '\u090f\u0915 \u0938\u094c'; // एक सौ
      } else {
        result = '${_hindiNumbers[hundred]} \u0938\u094c'; // X सौ
      }
      if (remainder > 0) {
        result += ' ${_numberToWordsHindi(remainder)}';
      }
      return result;
    }
    if (number < 100000) {
      final thousand = number ~/ 1000;
      final remainder = number % 1000;
      String result = '${_numberToWordsHindi(thousand)} \u0939\u091c\u093c\u093e\u0930'; // हज़ार
      if (remainder > 0) {
        result += ' ${_numberToWordsHindi(remainder)}';
      }
      return result;
    }
    if (number < 10000000) {
      final lakh = number ~/ 100000;
      final remainder = number % 100000;
      String result = '${_numberToWordsHindi(lakh)} \u0932\u093e\u0916'; // लाख
      if (remainder > 0) {
        result += ' ${_numberToWordsHindi(remainder)}';
      }
      return result;
    }
    final crore = number ~/ 10000000;
    final remainder = number % 10000000;
    String result = '${_numberToWordsHindi(crore)} \u0915\u0930\u094b\u0921\u093c'; // करोड़
    if (remainder > 0) {
      result += ' ${_numberToWordsHindi(remainder)}';
    }
    return result;
  }

  // ========== MARATHI CONVERSION ==========

  static const _marathiNumbers = [
    "\u0936\u0942\u0928\u094d\u092f", // शून्य
    "\u090f\u0915", // एक
    "\u0926\u094b\u0928", // दोन
    "\u0924\u0940\u0928", // तीन
    "\u091a\u093e\u0930", // चार
    "\u092a\u093e\u091a", // पाच
    "\u0938\u0939\u093e", // सहा
    "\u0938\u093e\u0924", // सात
    "\u0906\u0920", // आठ
    "\u0928\u090a", // नऊ
    "\u0926\u0939\u093e", // दहा
    "\u0905\u0915\u0930\u093e", // अकरा
    "\u092c\u093e\u0930\u093e", // बारा
    "\u0924\u0947\u0930\u093e", // तेरा
    "\u091a\u094c\u0926\u093e", // चौदा
    "\u092a\u0902\u0927\u0930\u093e", // पंधरा
    "\u0938\u094b\u0933\u093e", // सोळा
    "\u0938\u0924\u0930\u093e", // सतरा
    "\u0905\u0920\u093e\u0930\u093e", // अठरा
    "\u090f\u0915\u094b\u0923\u0940\u0938", // एकोणीस
    "\u0935\u0940\u0938", // वीस
    "\u090f\u0915\u0935\u0940\u0938", // एकवीस
    "\u092c\u093e\u0935\u0940\u0938", // बावीस
    "\u0924\u0947\u0935\u0940\u0938", // तेवीस
    "\u091a\u094b\u0935\u0940\u0938", // चोवीस
    "\u092a\u0902\u091a\u0935\u0940\u0938", // पंचवीस
    "\u0938\u0935\u094d\u0935\u0940\u0938", // सव्वीस
    "\u0938\u0924\u094d\u0924\u093e\u0935\u0940\u0938", // सत्तावीस
    "\u0905\u0920\u094d\u0920\u093e\u0935\u0940\u0938", // अठ्ठावीस
    "\u090f\u0915\u094b\u0923\u0924\u0940\u0938", // एकोणतीस
    "\u0924\u0940\u0938", // तीस
    "\u090f\u0915\u0924\u0940\u0938", // एकतीस
    "\u092c\u0924\u094d\u0924\u0940\u0938", // बत्तीस
    "\u0924\u0947\u0939\u0947\u0924\u0940\u0938", // तेहेतीस
    "\u091a\u094c\u0924\u0940\u0938", // चौतीस
    "\u092a\u0938\u0924\u0940\u0938", // पसतीस
    "\u091b\u0924\u094d\u0924\u0940\u0938", // छत्तीस
    "\u0938\u0926\u0924\u0940\u0938", // सदतीस
    "\u0905\u0921\u0924\u0940\u0938", // अडतीस
    "\u090f\u0915\u094b\u0923\u091a\u093e\u0933\u0940\u0938", // एकोणचाळीस
    "\u091a\u093e\u0933\u0940\u0938", // चाळीस
    "\u090f\u0915\u091a\u093e\u0933\u0940\u0938", // एकचाळीस
    "\u092c\u094e\u091a\u093e\u0933\u0940\u0938", // बेचाळीस
    "\u0924\u094d\u0930\u0948\u091a\u093e\u0933\u0940\u0938", // त्रैचाळीस
    "\u091a\u0935\u094e\u091a\u093e\u0933\u0940\u0938", // चवेचाळीस
    "\u092a\u0902\u091a\u0947\u091a\u093e\u0933\u0940\u0938", // पंचेचाळीस
    "\u0936\u094e\u091a\u093e\u0933\u0940\u0938", // शेचाळीस
    "\u0938\u0924\u094d\u0924\u0947\u091a\u093e\u0933\u0940\u0938", // सत्तेचाळीस
    "\u0905\u0920\u094d\u0920\u0947\u091a\u093e\u0933\u0940\u0938", // अठ्ठेचाळीस
    "\u090f\u0915\u094b\u0923\u092a\u0928\u094d\u0928\u093e\u0938", // एकोणपन्नास
    "\u092a\u0928\u094d\u0928\u093e\u0938", // पन्नास
    "\u090f\u0915\u093e\u0935\u0928\u094d\u0928", // एकावन्न
    "\u092c\u093e\u0935\u0928", // बावन
    "\u0924\u094d\u0930\u0947\u092a\u0928", // त्रेपन
    "\u091a\u094b\u092a\u0928", // चोपन
    "\u092a\u0902\u091a\u093e\u0935\u0928\u094d\u0928", // पंचावन्न
    "\u091b\u092a\u0928\u094d\u0928", // छपन्न
    "\u0938\u0924\u094d\u0924\u093e\u0935\u0928\u094d\u0928", // सत्तावन्न
    "\u0905\u0920\u094d\u0920\u093e\u0935\u0928\u094d\u0928", // अठ्ठावन्न
    "\u090f\u0915\u094b\u0923\u0938\u093e\u0920", // एकोणसाठ
    "\u0938\u093e\u0920", // साठ
    "\u090f\u0915\u0938\u0920", // एकसठ
    "\u092c\u093e\u0938\u0920", // बासठ
    "\u0924\u094d\u0930\u0947\u0938\u0920", // त्रेसठ
    "\u091a\u094c\u0938\u0920", // चौसठ
    "\u092a\u093e\u0938\u0920", // पासठ
    "\u0938\u0939\u093e\u0938\u0920", // सहासठ
    "\u0938\u0921\u0938\u0920", // सडसठ
    "\u0905\u0921\u0938\u0920", // अडसठ
    "\u090f\u0915\u094b\u0923\u0938\u0924\u094d\u0924\u0930", // एकोणसत्तर
    "\u0938\u0924\u094d\u0924\u0930", // सत्तर
    "\u090f\u0915\u0939\u0924\u094d\u0924\u0930", // एकहत्तर
    "\u092c\u093e\u0939\u0924\u094d\u0924\u0930", // बाहत्तर
    "\u0924\u094d\u0930\u094d\u092f\u093e\u0939\u0924\u094d\u0924\u0930", // त्र्याहत्तर
    "\u091a\u094c\u0931\u094d\u092f\u093e\u0939\u0924\u094d\u0924\u0930", // चौऱ्याहत्तर
    "\u092a\u0902\u091a\u094d\u092f\u093e\u0939\u0924\u094d\u0924\u0930", // पंच्याहत्तर
    "\u0936\u0939\u093e\u0924\u094d\u0924\u0930", // शहात्तर
    "\u0938\u0924\u094d\u092f\u093e\u0939\u0924\u094d\u0924\u0930", // सत्याहत्तर
    "\u0905\u0920\u094d\u0920\u094d\u092f\u093e\u0939\u0924\u094d\u0924\u0930", // अठ्ठ्याहत्तर
    "\u090f\u0915\u094b\u0923\u0910\u0902\u0936\u0940", // एकोणऐंशी
    "\u0910\u0902\u0936\u0940", // ऐंशी
    "\u090f\u0915\u093e\u0910\u0902\u0936\u0940", // एकाऐंशी
    "\u092c\u094d\u092f\u093e\u0910\u0902\u0936\u0940", // ब्याऐंशी
    "\u0924\u094d\u0930\u094d\u092f\u093e\u0910\u0902\u0936\u0940", // त्र्याऐंशी
    "\u091a\u094c\u0931\u094d\u092f\u093e\u0910\u0902\u0936\u0940", // चौऱ्याऐंशी
    "\u092a\u0902\u091a\u094d\u092f\u093e\u0910\u0902\u0936\u0940", // पंच्याऐंशी
    "\u0936\u0939\u093e\u0910\u0902\u0936\u0940", // शहाऐंशी
    "\u0938\u0924\u094d\u092f\u093e\u0910\u0902\u0936\u0940", // सत्याऐंशी
    "\u0905\u0920\u094d\u0920\u094d\u092f\u093e\u0910\u0902\u0936\u0940", // अठ्ठ्याऐंशी
    "\u090f\u0915\u094b\u0923\u0928\u0935\u094d\u0935\u0926", // एकोणनव्वद
    "\u0928\u0935\u094d\u0935\u0926", // नव्वद
    "\u090f\u0915\u093e\u0923\u094d\u0935\u0926", // एकाण्वद
    "\u092c\u094d\u092f\u093e\u0923\u094d\u0935\u0926", // ब्याण्वद
    "\u0924\u094d\u0930\u094d\u092f\u093e\u0923\u094d\u0935\u0926", // त्र्याण्वद
    "\u091a\u094c\u0931\u094d\u092f\u093e\u0923\u094d\u0935\u0926", // चौऱ्याण्वद
    "\u092a\u0902\u091a\u094d\u092f\u093e\u0923\u094d\u0935\u0926", // पंच्याण्वद
    "\u0936\u0939\u093e\u0923\u094d\u0935\u0926", // शहाण्वद
    "\u0938\u0924\u094d\u092f\u093e\u0923\u094d\u0935\u0926", // सत्याण्वद
    "\u0905\u0920\u094d\u0920\u094d\u092f\u093e\u0923\u094d\u0935\u0926", // अठ्ठ्याण्वद
    "\u0928\u0935\u094d\u092f\u093e\u0928\u0935\u094d\u0926", // नव्यान्वद
  ];

  static String _convertToMarathi(double amount) {
    if (amount == 0) return '\u0930\u0941\u092a\u092f\u0947 \u0936\u0942\u0928\u094d\u092f \u092e\u093e\u0924\u094d\u0930';

    final rupees = amount.floor();
    final paise = ((amount - rupees) * 100).round();

    String result = '\u0930\u0941\u092a\u092f\u0947 ${_numberToWordsMarathi(rupees)}';
    if (paise > 0) {
      result += ' \u0906\u0923\u093f ${_numberToWordsMarathi(paise)} \u092a\u0948\u0938\u0947';
    }
    result += ' \u092e\u093e\u0924\u094d\u0930';

    return result;
  }

  static String _numberToWordsMarathi(int number) {
    if (number == 0) return '\u0936\u0942\u0928\u094d\u092f';

    if (number < 100) {
      return _marathiNumbers[number];
    }
    if (number < 1000) {
      final hundred = number ~/ 100;
      final remainder = number % 100;
      String result = '';
      if (hundred == 1) {
        result = '\u090f\u0915\u0936\u0947'; // एकशे
      } else {
        result = '${_marathiNumbers[hundred]}\u0936\u0947'; // Xशे
      }
      if (remainder > 0) {
        result += ' ${_numberToWordsMarathi(remainder)}';
      }
      return result;
    }
    if (number < 100000) {
      final thousand = number ~/ 1000;
      final remainder = number % 1000;
      String result = '${_numberToWordsMarathi(thousand)} \u0939\u091c\u093e\u0930'; // हजार
      if (remainder > 0) {
        result += ' ${_numberToWordsMarathi(remainder)}';
      }
      return result;
    }
    if (number < 10000000) {
      final lakh = number ~/ 100000;
      final remainder = number % 100000;
      String result = '${_numberToWordsMarathi(lakh)} \u0932\u093e\u0916'; // लाख
      if (remainder > 0) {
        result += ' ${_numberToWordsMarathi(remainder)}';
      }
      return result;
    }
    final crore = number ~/ 10000000;
    final remainder = number % 10000000;
    String result = '${_numberToWordsMarathi(crore)} \u0915\u094b\u091f\u0940'; // कोटी
    if (remainder > 0) {
      result += ' ${_numberToWordsMarathi(remainder)}';
    }
    return result;
  }
}
