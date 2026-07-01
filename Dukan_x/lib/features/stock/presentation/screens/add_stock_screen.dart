import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../data/stock_service.dart';
import '../../../../widgets/glass_morphism.dart';
import '../../../../widgets/neon_button.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class AddStockScreen extends StatefulWidget {
  final String? initialBarcode;
  const AddStockScreen({super.key, this.initialBarcode});

  @override
  State<AddStockScreen> createState() => _AddStockScreenState();
}

class _AddStockScreenState extends State<AddStockScreen> {
  final _stockService = StockService();
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _categoryController = TextEditingController();
  final _sizeController = TextEditingController();
  final _qtyController = TextEditingController();
  final _priceController = TextEditingController();
  late TextEditingController _skuController;

  bool _isLoading = false;
  String? _statusMessage;
  File? _imageFile;

  // Mode: 'select', 'scanning', 'form'
  String _mode = 'select'; // Default will change in initState

  @override
  void initState() {
    super.initState();
    _skuController = TextEditingController(text: widget.initialBarcode ?? '');
    if (widget.initialBarcode != null) {
      _mode = 'form';
      // Trigger lookup if code provided
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _lookupInitialCode(widget.initialBarcode!);
      });
    }
  }

  Future<void> _lookupInitialCode(String code) async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Looking up barcode...";
    });
    try {
      final result = await _stockService.lookupBarcode(code);
      if (!mounted) return;
      if (result['found'] == true) {
        final data = result['data'];
        _nameController.text = data['name'] ?? '';
        _brandController.text = data['brand'] ?? '';
        _categoryController.text = data['category'] ?? '';
        _sizeController.text = data['size'] ?? '';
        if (result['source'] == 'inventory') {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Item already exists!")));
        }
      }
    } catch (e) {
      // ignore or log
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _categoryController.dispose();
    _sizeController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    _skuController.dispose();
    super.dispose();
  }

  // --- ACTIONS ---

  Future<void> _handleBarcodeScan() async {
    setState(() => _mode = 'scanning');
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final code = barcodes.first.rawValue;
      if (code != null) {
        // Stop scanning, assume code found
        setState(() {
          _mode = 'form'; // temporarily show form while loading?
          _isLoading = true;
          _statusMessage = "Looking up barcode...";
          _skuController.text = code;
        });

        try {
          final result = await _stockService.lookupBarcode(code);
          if (!mounted) return;
          if (result['found'] == true) {
            final data = result['data'];
            _nameController.text = data['name'] ?? '';
            _brandController.text = data['brand'] ?? '';
            _categoryController.text = data['category'] ?? '';
            _sizeController.text = data['size'] ?? '';
            // If duplicate/existing
            if (result['source'] == 'inventory') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Item already exists! Quantity will be added."),
                ),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("New Item. Please fill details.")),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text("Error: $e")));
          }
        } finally {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _statusMessage = null;
              _mode = 'form';
            });
          }
        }
      }
    }
  }

  Future<void> _handleCameraPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (picked != null) {
      if (!mounted) return;
      setState(() {
        _imageFile = File(picked.path);
        _mode = 'form';
        _isLoading = true;
        _statusMessage = "AI Analyzing Image...";
      });

      try {
        final analysis = await _stockService.analyzeImage(_imageFile!);
        if (!mounted) return;
        _nameController.text = analysis['name'] ?? '';
        _categoryController.text = analysis['category'] ?? '';
        _brandController.text = analysis['brand'] ?? '';
        _sizeController.text = analysis['size'] ?? '';
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("AI Error: $e")));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _statusMessage = null;
          });
        }
      }
    }
  }

  Future<void> _saveStock() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _statusMessage = "Saving to Inventory...";
    });

    try {
      final itemData = {
        "name": _nameController.text,
        "sku": _skuController.text,
        "brand": _brandController.text,
        "category": _categoryController.text,
        "unit": _sizeController.text, // Mapping size to unit for now
        "quantity": double.tryParse(_qtyController.text) ?? 0,
        "sellingPrice": double.tryParse(_priceController.text) ?? 0,
        "updatedAt": DateTime.now().toIso8601String(),
      };

      await _stockService.addStock(itemData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Stock Added Successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Return to list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Save Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UI BUILDERS ---

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Background handling
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          _mode == 'scanning' ? "Scan Barcode" : "Add New Stock",
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            _mode == 'select' ? Icons.close : Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () {
            if (_mode == 'select') Navigator.pop(context);
            if (_mode == 'scanning') setState(() => _mode = 'select');
            if (_mode == 'form') setState(() => _mode = 'select');
          },
        ),
      ),
      body: BoundedBox(
        maxWidth: 800,
        child: Stack(
        children: [
          // Gradient Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
                    : [const Color(0xFFE0C3FC), const Color(0xFF8EC5FC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          SafeArea(child: _buildBody(isDark)),

          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: GlassContainer(
                  padding: EdgeInsets.all(responsiveValue<double>(context, mobile: 16, tablet: 20, desktop: 24)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        _statusMessage ?? "Processing...",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_mode == 'scanning') {
      return Stack(
        children: [
          MobileScanner(onDetect: _onBarcodeDetected),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.greenAccent, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: GlassContainer(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.black54,
                child: Text(
                  "Point camera at barcode",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_mode == 'form') {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_imageFile != null)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _imageFile!,
                      height: 150,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              _buildTextField(
                "Product Name",
                _nameController,
                isDark,
                required: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      "Barcode/SKU",
                      _skuController,
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField("Brand", _brandController, isDark),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      "Price (₹)",
                      _priceController,
                      isDark,
                      isNum: true,
                      required: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      "Qty",
                      _qtyController,
                      isDark,
                      isNum: true,
                      required: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      "Category",
                      _categoryController,
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      "Size/Unit",
                      _sizeController,
                      isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              NeonButton(
                text: "Save to Inventory",
                icon: Icons.check,
                color: Colors.green,
                onPressed: _saveStock,
              ),
            ],
          ),
        ),
      );
    }

    // Default: Selection Mode
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GlassCard(
              onTap: _handleBarcodeScan,
              child: Column(
                children: const [
                  Icon(
                    Icons.qr_code_scanner,
                    size: 60,
                    color: Colors.blueAccent,
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Scan Barcode",
                    style: TextStyle(fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20), fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Recommended. Fast & Accurate.",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "OR",
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            GlassCard(
              onTap: _handleCameraPhoto,
              child: Column(
                children: const [
                  Icon(
                    Icons.camera_alt_outlined,
                    size: 60,
                    color: Colors.purpleAccent,
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Use Camera (AI)",
                    style: TextStyle(fontSize: responsiveValue<double>(context, mobile: 16, tablet: 18, desktop: 20), fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Snap a photo. AI will guess details.",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController ctrl,
    bool isDark, {
    bool isNum = false,
    bool required = false,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      validator: required
          ? (v) => v?.isEmpty == true ? 'Required' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        filled: true,
        fillColor: isDark
            ? Colors.white.withOpacity(0.1)
            : Colors.white.withOpacity(0.8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
