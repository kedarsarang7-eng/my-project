import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desktop_drop/desktop_drop.dart';

import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../../core/api/api_client.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/pharmacy/paise.dart';
import '../../../core/pharmacy/product_mrp_entry_validator.dart';
import 'package:http/http.dart' as http;
import '../../barcode/widgets/desktop_usb_scanner.dart';

/// Add/Edit Product Sheet
/// Features:
/// - Product form with pharmacy-specific fields
/// - Image upload with S3 presigned URLs
/// - Drag-drop image support (desktop)
/// - Image compression + thumbnail generation
/// - Barcode scanning support
class AddProductSheet extends ConsumerStatefulWidget {
  final String businessType;
  final Map<String, dynamic>? product; // For editing

  const AddProductSheet({super.key, required this.businessType, this.product});

  @override
  ConsumerState<AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends ConsumerState<AddProductSheet> {
  // PHARMACY MRP bounds (Requirements 8.5, 8.6): MRP is stored as integer
  // paise and must fall within [1, 99,999,999] paise — i.e. ₹0.01 to
  // ₹999,999.99 inclusive. The bounds/parsing rule lives in
  // [ProductMrpEntryValidator] so it can be unit/property tested.
  static const int _minMrpPaise = ProductMrpEntryValidator.minMrpPaise;
  static const int _maxMrpPaise = ProductMrpEntryValidator.maxMrpPaise;

  late TextEditingController _nameController;
  late TextEditingController _barcodeController;
  late TextEditingController _priceController;
  late TextEditingController _costController;
  late TextEditingController _stockController;
  late TextEditingController _batchNoController;
  late TextEditingController _strengthController;
  late TextEditingController _manufacturerController;

  String? _selectedCategory;
  DateTime? _expiryDate;
  io.File? _imageFile;
  double _gstRate = 12.0; // User-selectable GST rate

  String? _s3ImageKey;
  String? _s3ThumbnailKey;
  bool _isUploading = false;
  bool _isSaving = false;

  final ImagePicker _imagePicker = ImagePicker();
  late ApiClient _apiClient;

  @override
  void initState() {
    super.initState();
    _apiClient = sl<ApiClient>();
    _initializeControllers();
    if (widget.product != null) {
      _loadProductData();
    }
  }

  void _initializeControllers() {
    _nameController = TextEditingController(
      text: widget.product?['name'] ?? '',
    );
    _barcodeController = TextEditingController(
      text: widget.product?['barcode'] ?? '',
    );
    _priceController = TextEditingController(
      text: widget.product?['price']?.toString() ?? '',
    );
    _costController = TextEditingController(
      text: widget.product?['cost']?.toString() ?? '',
    );
    _stockController = TextEditingController(
      text: widget.product?['stock']?.toString() ?? '0',
    );
    _batchNoController = TextEditingController(
      text: widget.product?['batchNo'] ?? '',
    );
    _strengthController = TextEditingController(
      text: widget.product?['strength'] ?? '',
    );
    _manufacturerController = TextEditingController(
      text: widget.product?['manufacturer'] ?? '',
    );

    _selectedCategory = widget.product?['category'];
    if (widget.product?['gstRate'] != null) {
      _gstRate = (widget.product!['gstRate'] as num).toDouble();
    }
    if (widget.product?['expiryDate'] != null) {
      _expiryDate = DateTime.fromMillisecondsSinceEpoch(
        widget.product!['expiryDate'] as int,
      );
    }

    _s3ImageKey = widget.product?['s3ImageKey'];
    _s3ThumbnailKey = widget.product?['s3ThumbnailKey'];
  }

  void _loadProductData() {
    // Data already loaded in initializeControllers
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _stockController.dispose();
    _batchNoController.dispose();
    _strengthController.dispose();
    _manufacturerController.dispose();
    super.dispose();
  }

  /// Pick image from gallery
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final file = io.File(pickedFile.path);
        await _processAndUploadImage(file);
      }
    } catch (e) {
      _showError('Error picking image: $e');
    }
  }

  /// Handle drag-drop on desktop
  Future<void> _handleDroppedFile(DropDoneDetails details) async {
    if (details.files.isNotEmpty) {
      final file = io.File(details.files.first.path);
      if (_isImageFile(file)) {
        await _processAndUploadImage(file);
      } else {
        _showError('Please drop an image file (JPG, PNG)');
      }
    }
  }

  /// Check if file is an image
  bool _isImageFile(io.File file) {
    final name = file.path.toLowerCase();
    return name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.gif');
  }

  /// Compress image and upload to S3
  Future<void> _processAndUploadImage(io.File imageFile) async {
    _isUploading = true;

    try {
      // Compress image
      final compressedFile = await _compressImage(imageFile);

      // Get presigned upload URL
      final uploadResponse = await _apiClient.post(
        '/products/${widget.product?['id'] ?? 'new'}/image-upload-url?businessType=${widget.businessType}',
        body: {
          'originalFileName': compressedFile.path.split('/').last,
          'fileType': 'image/jpeg',
          'fileSize': compressedFile.lengthSync(),
        },
      );

      if (uploadResponse.statusCode != 200) {
        throw Exception('Failed to get upload URL');
      }

      final uploadData = uploadResponse.data!;
      final uploadUrl = uploadData['uploadUrl'];
      _s3ImageKey = uploadData['s3Key'];
      _s3ThumbnailKey = uploadData['s3ThumbnailKey'];

      // Upload image to S3
      await _uploadToS3(uploadUrl, compressedFile);

      setState(() {
        _imageFile = compressedFile;
        _isUploading = false;
      });

      _showSuccess('Image uploaded successfully');
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      _showError('Image upload failed: $e');
    }
  }

  /// Compress image to reduce size
  Future<io.File> _compressImage(io.File file) async {
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      '${file.parent.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      quality: 80,
      rotate: 0,
    );

    if (result == null) {
      return file; // If compression fails, use original
    }
    return io.File(result.path);
  }

  /// Upload compressed image to S3 using presigned URL
  Future<void> _uploadToS3(String presignedUrl, io.File file) async {
    final bytes = await file.readAsBytes();

    final response = await http.put(
      Uri.parse(presignedUrl),
      headers: {'Content-Type': 'image/jpeg'},
      body: bytes,
    );

    if (response.statusCode != 200) {
      throw Exception('S3 upload failed: ${response.statusCode}');
    }
  }

  /// Safe numeric parsers — return null on empty/invalid input
  double? _parseDouble(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  int? _parseInt(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  /// PHARMACY: Convert a rupee MRP string into a whole number of integer paise.
  ///
  /// Delegates to [ProductMrpEntryValidator] so the rule has a single,
  /// testable source. Returns null when the text is not a non-negative number
  /// with up to two decimals (Requirements 8.5, 8.6).
  int? _mrpRupeesToWholePaise(String text) =>
      ProductMrpEntryValidator.rupeesToWholePaise(text);

  /// Save product
  Future<void> _saveProduct() async {
    final name = _nameController.text.trim();
    final priceText = _priceController.text.trim();
    final stockText = _stockController.text.trim();

    if (name.isEmpty) {
      _showError('Product name is required');
      return;
    }
    if (priceText.isEmpty) {
      _showError('MRP / selling price is required');
      return;
    }
    final price = _parseDouble(priceText);
    if (price == null) {
      _showError('MRP must be a valid number');
      return;
    }
    if (price <= 0) {
      _showError('MRP must be greater than ₹0');
      return;
    }
    // PHARMACY: MRP must map to a whole integer paise value in
    // [1, 99,999,999] paise (₹0.01 to ₹999,999.99). Non-integer paise and
    // out-of-range values are rejected and the product is not saved
    // (Requirements 8.5, 8.6). Gated to the pharmacy branch so the other 18
    // verticals are unchanged (Requirement 5.3).
    if (widget.businessType == 'pharmacy') {
      final mrpPaise = _mrpRupeesToWholePaise(priceText);
      if (mrpPaise == null) {
        _showError(
          'MRP must be a positive integer paise value (up to 2 decimal places, e.g. ₹49.50).',
        );
        return;
      }
      if (mrpPaise < _minMrpPaise || mrpPaise > _maxMrpPaise) {
        _showError(
          'MRP must be between ₹${Paise.toDisplay(_minMrpPaise)} and ₹${Paise.toDisplay(_maxMrpPaise)}.',
        );
        return;
      }
    }
    final cost = _parseDouble(_costController.text);
    if (_costController.text.trim().isNotEmpty && cost == null) {
      _showError('Cost price must be a valid number');
      return;
    }
    final stock = _parseInt(stockText) ?? 0;

    setState(() => _isSaving = true);

    try {
      final body = {
        'name': name,
        'barcode': _barcodeController.text.isNotEmpty
            ? _barcodeController.text.trim()
            : null,
        'category': _selectedCategory,
        'price': price,
        'cost': cost,
        'stock': stock,
        'batchNo': _batchNoController.text.trim().isNotEmpty
            ? _batchNoController.text.trim()
            : null,
        'strength': _strengthController.text.trim().isNotEmpty
            ? _strengthController.text.trim()
            : null,
        'manufacturer': _manufacturerController.text.trim().isNotEmpty
            ? _manufacturerController.text.trim()
            : null,
        'expiryDate': _expiryDate?.millisecondsSinceEpoch,
        'gstRate': _gstRate,
        's3ImageKey': _s3ImageKey,
        's3ThumbnailKey': _s3ThumbnailKey,
      };

      final endpoint = widget.product != null
          ? '/products/${widget.product!['id']}?businessType=${widget.businessType}'
          : '/products?businessType=${widget.businessType}';
      final method = widget.product != null ? 'PUT' : 'POST';

      final response = method == 'POST'
          ? await _apiClient.post(endpoint, body: body)
          : await _apiClient.put(endpoint, body: body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.product != null ? 'Product updated' : 'Product created',
              ),
            ),
          );
        }
      } else {
        throw Exception('Failed to save product');
      }
    } catch (e) {
      _showError('Error saving product: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Future<void> _scanBarcode() async {
    final barcode = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.qr_code_scanner,
                    size: 24,
                    color: Colors.teal,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Scan Drug Barcode',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Scan the barcode on the drug package to auto-fill the barcode field.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              DesktopUsbScanner(
                onProductScanned: (p) => Navigator.pop(ctx, p.barcode),
                onProductNotFound: (code) => Navigator.pop(ctx, code),
              ),
            ],
          ),
        ),
      ),
    );

    if (barcode == null || barcode.isEmpty) return;
    setState(() => _barcodeController.text = barcode);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Barcode captured: $barcode'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.product != null ? 'Edit Product' : 'Add Product',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Image Upload Section
              _buildImageUploadSection(),
              const SizedBox(height: 24),
              // Product Name (Required)
              _buildTextField(
                controller: _nameController,
                label: 'Product Name *',
                hint: 'e.g., Aspirin 500mg Tablet',
                icon: Icons.medication,
              ),
              const SizedBox(height: 12),
              // Barcode (with scan button)
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _barcodeController,
                      label: 'Barcode',
                      hint: 'Scan or enter barcode',
                      icon: Icons.barcode_reader,
                      keyboardType: TextInputType.text,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: _scanBarcode,
                      icon: const Icon(Icons.qr_code_scanner, size: 18),
                      label: const Text('Scan'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Price (Required)
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _priceController,
                      label: 'MRP *',
                      hint: '0.00',
                      icon: Icons.currency_rupee,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _costController,
                      label: 'Cost Price',
                      hint: '0.00',
                      icon: Icons.attach_money,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Stock (Required)
              _buildTextField(
                controller: _stockController,
                label: 'Stock *',
                hint: '0',
                icon: Icons.inventory_2,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              // Pharmacy-Specific Fields
              _buildTextField(
                controller: _batchNoController,
                label: 'Batch No',
                hint: 'e.g., BATCH123',
              ),
              const SizedBox(height: 12),
              // Expiry Date
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _expiryDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 1825)),
                  );
                  if (date != null) {
                    setState(() => _expiryDate = date);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _expiryDate == null
                              ? 'Select Expiry Date'
                              : 'Expiry: ${_expiryDate!.toString().split(' ').first}',
                          style: TextStyle(
                            color: _expiryDate == null
                                ? Colors.grey[600]
                                : Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Strength
              _buildTextField(
                controller: _strengthController,
                label: 'Strength',
                hint: 'e.g., 500mg, 10ml',
              ),
              const SizedBox(height: 12),
              // Manufacturer
              _buildTextField(
                controller: _manufacturerController,
                label: 'Manufacturer',
                hint: 'e.g., Cipla Ltd',
              ),
              const SizedBox(height: 12),
              // GST Rate
              DropdownButtonFormField<double>(
                value: _gstRate,
                decoration: InputDecoration(
                  labelText: 'GST Rate',
                  prefixIcon: const Icon(Icons.percent),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 0.0, child: Text('0% — Exempt')),
                  DropdownMenuItem(value: 5.0, child: Text('5%')),
                  DropdownMenuItem(value: 12.0, child: Text('12%')),
                  DropdownMenuItem(value: 18.0, child: Text('18%')),
                ],
                onChanged: (v) => setState(() => _gstRate = v ?? 12.0),
              ),
              const SizedBox(height: 24),
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProduct,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              widget.product != null
                                  ? 'Update Product'
                                  : 'Create Product',
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageUploadSection() {
    return DropTarget(
      onDragDone: _handleDroppedFile,
      onDragEntered: (_) {},
      onDragExited: (_) {},
      child: GestureDetector(
        onTap: _isUploading ? null : _pickImage,
        child: Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.grey[300]!,
              width: 2,
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[50],
          ),
          child: _imageFile != null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(_imageFile!, fit: BoxFit.cover),
                    if (_isUploading)
                      Container(
                        color: Colors.black54,
                        child: const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isUploading ? 'Uploading...' : 'Tap or drag image here',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'JPG, PNG (max 10MB)',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}
