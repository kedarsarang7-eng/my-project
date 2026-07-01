import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/vendor_profile.dart';
import '../../../services/vendor_profile_service.dart';
import '../widgets/avatar_display_widget.dart';
import '../widgets/avatar_selector_widget.dart';
import '../../../models/business_type.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class VendorProfileScreen extends StatefulWidget {
  const VendorProfileScreen({super.key});

  @override
  State<VendorProfileScreen> createState() => _VendorProfileScreenState();
}

class _VendorProfileScreenState extends State<VendorProfileScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _service = VendorProfileService();

  // Controllers
  late TextEditingController _vendorNameController;
  late TextEditingController _mobileController;
  late TextEditingController _emailController;
  late TextEditingController _shopNameController;
  late TextEditingController _shopAddressController;
  late TextEditingController _shopMobileController;
  late TextEditingController _gstinController;

  // Invoice Settings Controllers
  late TextEditingController _taglineController;
  late TextEditingController _fssaiController;
  late TextEditingController _upiIdController;
  late TextEditingController _returnPolicyController;

  // State
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanges = false;
  String? _logoUrl;
  XFile? _pendingLogoFile;
  Uint8List? _pendingLogoBytes;
  AvatarData? _selectedAvatar;
  String? _selectedBusinessType;

  // Signature and Stamp
  String? _signatureUrl;
  String? _stampUrl;
  Uint8List? _pendingSignatureBytes;
  Uint8List? _pendingStampBytes;

  // Animation
  late AnimationController _saveButtonController;
  late Animation<double> _saveButtonAnimation;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _initAnimations();
    _loadProfile();
  }

  void _initControllers() {
    _vendorNameController = TextEditingController();
    _mobileController = TextEditingController();
    _emailController = TextEditingController();
    _shopNameController = TextEditingController();
    _shopAddressController = TextEditingController();
    _shopMobileController = TextEditingController();
    _gstinController = TextEditingController();

    // Invoice Settings Controllers
    _taglineController = TextEditingController();
    _fssaiController = TextEditingController();
    _upiIdController = TextEditingController();
    _returnPolicyController = TextEditingController();

    // Listen for changes
    final controllers = [
      _vendorNameController,
      _mobileController,
      _emailController,
      _shopNameController,
      _shopAddressController,
      _shopMobileController,
      _gstinController,
      _taglineController,
      _fssaiController,
      _upiIdController,
      _returnPolicyController,
    ];

    for (final controller in controllers) {
      controller.addListener(_onFieldChanged);
    }
  }

  void _initAnimations() {
    _saveButtonController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _saveButtonAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _saveButtonController, curve: Curves.easeOut),
    );
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
      _saveButtonController.forward();
    }
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    try {
      final profile = await _service.loadProfile();
      if (profile != null && mounted) {
        _vendorNameController.text = profile.vendorName;
        _mobileController.text = profile.mobileNumber;
        _emailController.text = profile.email ?? '';
        _shopNameController.text = profile.shopName;
        _shopAddressController.text = profile.shopAddress;
        _shopMobileController.text = profile.shopMobile;
        _gstinController.text = profile.gstin ?? '';
        _logoUrl = await _service.resolveLogoUrl(profile.shopLogoUrl);
        _selectedAvatar = profile.avatar;
        _selectedBusinessType = profile.businessType;

        // Invoice Settings
        _taglineController.text = profile.businessTagline ?? '';
        _fssaiController.text = profile.fssaiNumber ?? '';
        _upiIdController.text = profile.upiId ?? '';
        _returnPolicyController.text = profile.returnPolicy ?? '';
        _signatureUrl = profile.signatureImageUrl;
        _stampUrl = profile.stampImageUrl;
      }
    } catch (e) {
      _showError('Failed to load profile: $e');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasChanges = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Resolve the value to persist in shopLogoUrl: a new upload yields a
      // storage *key*; otherwise keep whatever the loaded profile already had
      // (also a key) rather than the resolved display URL in _logoUrl.
      final currentProfile = _service.profile ?? VendorProfile.empty('');
      String? logoStored = currentProfile.shopLogoUrl;
      if (_pendingLogoFile != null) {
        logoStored = await _service.uploadShopLogo(_pendingLogoFile!);
      } else if (_logoUrl == null) {
        // User cleared the logo.
        logoStored = null;
      }

      // Create updated profile
      final profile = currentProfile.copyWith(
        vendorName: _vendorNameController.text.trim(),
        mobileNumber: _mobileController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        shopName: _shopNameController.text.trim(),
        shopAddress: _shopAddressController.text.trim(),
        shopMobile: _shopMobileController.text.trim(),
        gstin: _gstinController.text.trim().isEmpty
            ? null
            : _gstinController.text.trim().toUpperCase(),
        shopLogoUrl: logoStored,
        avatar: _selectedAvatar,
        businessType: _selectedBusinessType,
        // Invoice Settings
        businessTagline: _taglineController.text.trim().isEmpty
            ? null
            : _taglineController.text.trim(),
        fssaiNumber: _fssaiController.text.trim().isEmpty
            ? null
            : _fssaiController.text.trim(),
        upiId: _upiIdController.text.trim().isEmpty
            ? null
            : _upiIdController.text.trim(),
        returnPolicy: _returnPolicyController.text.trim().isEmpty
            ? null
            : _returnPolicyController.text.trim(),
        // Note: Signature/Stamp stored as local bytes until Firebase upload is implemented
        signatureImageUrl: _signatureUrl,
        stampImageUrl: _stampUrl,
      );

      final success = await _service.saveProfile(profile);

      if (success && mounted) {
        _logoUrl = await _service.resolveLogoUrl(logoStored);
        _pendingLogoFile = null;
        _pendingLogoBytes = null;
        _pendingSignatureBytes = null;
        _pendingStampBytes = null;

        setState(() {
          _hasChanges = false;
          _isSaving = false;
        });
        _saveButtonController.reverse();

        _showSuccess('Profile saved successfully!');
      } else {
        throw Exception('Failed to save profile');
      }
    } catch (e) {
      _showError('Failed to save profile: $e');
      setState(() => _isSaving = false);
    }
  }

  Future<void> _pickLogo() async {
    try {
      final picker = ImagePicker();
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blue),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.green),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              if (_logoUrl != null || _pendingLogoFile != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Remove Logo'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _logoUrl = null;
                      _pendingLogoFile = null;
                      _pendingLogoBytes = null;
                      _hasChanges = true;
                    });
                    _saveButtonController.forward();
                  },
                ),
            ],
          ),
        ),
      );

      if (source == null) return;

      final image = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        final bytes = await image.readAsBytes();
        setState(() {
          _pendingLogoFile = image;
          _pendingLogoBytes = bytes;
          _hasChanges = true;
        });
        _saveButtonController.forward();
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _pickSignature() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 200,
        imageQuality: 90,
      );

      if (image != null && mounted) {
        final bytes = await image.readAsBytes();
        setState(() {
          _pendingSignatureBytes = bytes;
          _hasChanges = true;
        });
        _saveButtonController.forward();
      }
    } catch (e) {
      _showError('Failed to pick signature: $e');
    }
  }

  Future<void> _pickStamp() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 200,
        maxHeight: 200,
        imageQuality: 90,
      );

      if (image != null && mounted) {
        final bytes = await image.readAsBytes();
        setState(() {
          _pendingStampBytes = bytes;
          _hasChanges = true;
        });
        _saveButtonController.forward();
      }
    } catch (e) {
      _showError('Failed to pick stamp: $e');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              message,
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    _vendorNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _shopNameController.dispose();
    _shopAddressController.dispose();
    _shopMobileController.dispose();
    _gstinController.dispose();
    _taglineController.dispose();
    _fssaiController.dispose();
    _upiIdController.dispose();
    _returnPolicyController.dispose();
    _saveButtonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Vendor Profile',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        actions: [
          if (_hasChanges)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Discard Changes',
              onPressed: () {
                _loadProfile();
                _saveButtonController.reverse();
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: BoundedBox(
                maxWidth: 800,
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo Upload Section
                    _buildLogoSection(isDark),
                    const SizedBox(height: 24),

                    // Info Banner
                    _buildInfoBanner(isDark),
                    const SizedBox(height: 24),

                    // Personal Details Section
                    _buildSectionHeader(
                      'Vendor Personal Details',
                      Icons.person,
                      isDark,
                    ),
                    const SizedBox(height: 12),
                    _buildPersonalDetailsCard(isDark),
                    const SizedBox(height: 24),

                    // Shop Details Section
                    _buildSectionHeader(
                      'Shop / Business Details',
                      Icons.store,
                      isDark,
                    ),
                    const SizedBox(height: 12),
                    _buildShopDetailsCard(isDark),
                    const SizedBox(height: 24),

                    // Invoice Settings Section
                    _buildSectionHeader(
                      'Invoice Settings',
                      Icons.settings_outlined,
                      isDark,
                    ),
                    const SizedBox(height: 12),
                    _buildInvoiceSettingsCard(isDark),
                    const SizedBox(height: 24),

                    // Invoice Preview Section
                    _buildSectionHeader(
                      'Invoice Preview',
                      Icons.receipt_long,
                      isDark,
                    ),
                    const SizedBox(height: 12),
                    _buildInvoicePreview(isDark),
                    const SizedBox(height: 100), // Space for FAB
                  ],
                ),
              ),
            ),
          ),
        ),
      floatingActionButton: _buildSaveButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  void _showAvatarSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Choose Avatar',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AvatarSelectorWidget(
                selectedAvatar: _selectedAvatar,
                onSelected: (avatar) {
                  setState(() {
                    _selectedAvatar = avatar;
                    _hasChanges = true;
                  });
                  _saveButtonController.forward();
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoSection(bool isDark) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Shop Logo
          Column(
            children: [
              GestureDetector(
                onTap: _pickLogo,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: _buildLogoImage(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _pickLogo,
                child: Text(
                  'Shop Logo',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(width: 32),
          // Avatar
          Column(
            children: [
              GestureDetector(
                onTap: _showAvatarSelector,
                child: AvatarDisplayWidget(
                  avatar: _selectedAvatar,
                  size: 100,
                  showBorder: true,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _showAvatarSelector,
                child: Text(
                  'Owner Avatar',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogoImage() {
    if (_pendingLogoBytes != null) {
      return Image.memory(
        _pendingLogoBytes!,
        fit: BoxFit.cover,
        width: 120,
        height: 120,
      );
    }

    if (_logoUrl != null) {
      return Image.network(
        _logoUrl!,
        fit: BoxFit.cover,
        width: 120,
        height: 120,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        },
        errorBuilder: (_, _, _) =>
            const Icon(Icons.store_rounded, size: 48, color: Colors.grey),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_rounded,
          size: 40,
          color: Colors.grey.shade400,
        ),
        const SizedBox(height: 4),
        Text(
          'Upload Logo',
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildInfoBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E3A8A).withOpacity(0.1),
            const Color(0xFF3B82F6).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3A8A).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.info_outline,
              color: Color(0xFF1E3A8A),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invoice Data Source',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'These details will automatically appear on all your invoices.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isDark ? Colors.white70 : Colors.grey.shade700,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalDetailsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTextField(
            controller: _vendorNameController,
            label: 'Vendor Name',
            hint: 'Enter your name',
            icon: Icons.person_outline,
            isDark: isDark,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Vendor name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _mobileController,
            label: 'Mobile Number',
            hint: '10-digit mobile number',
            icon: Icons.phone_android,
            isDark: isDark,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Mobile number is required';
              }
              if (!VendorProfile.isValidMobile(value)) {
                return 'Enter valid 10-digit mobile number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _emailController,
            label: 'Email ID (Optional)',
            hint: 'email@example.com',
            icon: Icons.email_outlined,
            isDark: isDark,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value != null &&
                  value.isNotEmpty &&
                  !VendorProfile.isValidEmail(value)) {
                return 'Enter valid email address';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildShopDetailsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTextField(
            controller: _shopNameController,
            label: 'Shop Name',
            hint: 'Enter your business name',
            icon: Icons.store_rounded,
            isDark: isDark,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Shop name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _shopAddressController,
            label: 'Shop Address',
            hint: 'Full business address',
            icon: Icons.location_on_outlined,
            isDark: isDark,
            maxLines: 3,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Shop address is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _shopMobileController,
            label: 'Shop Mobile Number',
            hint: '10-digit mobile number',
            icon: Icons.phone_rounded,
            isDark: isDark,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Shop mobile is required';
              }
              if (!VendorProfile.isValidMobile(value)) {
                return 'Enter valid 10-digit mobile number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _gstinController,
            label: 'GSTIN (Optional)',
            hint: 'e.g., 22AAAAA0000A1Z5',
            icon: Icons.receipt_outlined,
            isDark: isDark,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              UpperCaseTextFormatter(),
              LengthLimitingTextInputFormatter(15),
            ],
            validator: (value) {
              if (value != null &&
                  value.isNotEmpty &&
                  !VendorProfile.isValidGstin(value)) {
                return 'Enter valid GSTIN format';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          // Business Type Dropdown
          DropdownButtonFormField<String>(
            value: _selectedBusinessType,
            decoration: InputDecoration(
              labelText: 'Business Type',
              hintText: 'Select your business type',
              prefixIcon: Icon(
                Icons.category,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                ),
              ),
            ),
            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            items: BusinessType.values.map((type) {
              return DropdownMenuItem<String>(
                value: type.name, // Storing enum name as string
                child: Row(
                  children: [
                    Icon(type.icon, size: 18, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      type.displayName,
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedBusinessType = value;
                _hasChanges = true;
              });
              _saveButtonController.forward();
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a business type';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceSettingsCard(bool isDark) {
    // Determine visibility based on Business Type
    final type = _selectedBusinessType?.toLowerCase() ?? '';
    final isFoodBusiness =
        type.contains('restaurant') ||
        type.contains('grocery') ||
        type.contains('vegetable') ||
        type.contains('wholesale');
    final isServiceBusiness =
        type.contains('service') ||
        type.contains('clinic') ||
        type.contains('consultancy');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTextField(
            controller: _taglineController,
            label: 'Business Tagline',
            hint: 'e.g., "Best Quality at Best Price"',
            icon: Icons.campaign_outlined,
            isDark: isDark,
          ),

          // Conditional FSSAI Field (Food Businesses Only)
          if (isFoodBusiness) ...[
            const SizedBox(height: 16),
            _buildTextField(
              controller: _fssaiController,
              label: 'FSSAI Number',
              hint: '14-digit FSSAI license',
              icon: Icons.restaurant_menu_rounded,
              isDark: isDark,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(14),
              ],
            ),
          ],

          const SizedBox(height: 16),
          _buildTextField(
            controller: _upiIdController,
            label: 'UPI ID (For QR Code)',
            hint: 'mobile@upi',
            icon: Icons.qr_code_rounded,
            isDark: isDark,
          ),

          const SizedBox(height: 16),
          _buildTextField(
            controller: _returnPolicyController,
            label: isServiceBusiness ? 'Service Terms' : 'Return Policy',
            hint: isServiceBusiness
                ? 'e.g., Warranty void if opened...'
                : 'e.g., No returns after 7 days...',
            icon: isServiceBusiness
                ? Icons.policy_rounded
                : Icons.assignment_return_outlined,
            isDark: isDark,
            maxLines: 2,
          ),
          const SizedBox(height: 24),

          // Signature and Stamp Section
          Row(
            children: [
              Icon(
                Icons.draw,
                size: 18,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                'Digital Signature & Stamp',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Signature Box
              Expanded(
                child: _buildImageUploadBox(
                  title: 'Signature',
                  icon: Icons.gesture,
                  bytes: _pendingSignatureBytes,
                  isDark: isDark,
                  onTap: _pickSignature,
                  onClear: () {
                    setState(() {
                      _pendingSignatureBytes = null;
                      _signatureUrl = null;
                      _hasChanges = true;
                    });
                    _saveButtonController.forward();
                  },
                ),
              ),
              const SizedBox(width: 16),
              // Stamp Box
              Expanded(
                child: _buildImageUploadBox(
                  title: 'Stamp',
                  icon: Icons.circle,
                  bytes: _pendingStampBytes,
                  isDark: isDark,
                  onTap: _pickStamp,
                  onClear: () {
                    setState(() {
                      _pendingStampBytes = null;
                      _stampUrl = null;
                      _hasChanges = true;
                    });
                    _saveButtonController.forward();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageUploadBox({
    required String title,
    required IconData icon,
    required Uint8List? bytes,
    required bool isDark,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    final hasImage = bytes != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.grey.shade300,
            style: BorderStyle.solid,
          ),
        ),
        child: hasImage
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: 100,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: onClear,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
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
                    icon,
                    size: 28,
                    color: isDark ? Colors.white38 : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Upload $title',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.words,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      validator: validator,
      style: GoogleFonts.inter(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: isDark ? Colors.white54 : Colors.grey),
        labelStyle: TextStyle(
          color: isDark ? Colors.white70 : Colors.grey.shade700,
        ),
        hintStyle: TextStyle(
          color: isDark ? Colors.white30 : Colors.grey.shade400,
        ),
        filled: true,
        fillColor: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildInvoicePreview(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Invoice Header Preview
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo placeholder
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    if (_logoUrl != null || _pendingLogoBytes != null)
                      Expanded(child: _buildLogoImage()),
                    if (_selectedAvatar != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: AvatarDisplayWidget(
                          avatar: _selectedAvatar,
                          size: 28, // Small avatar in preview
                          showBorder: true,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _shopNameController.text.isEmpty
                          ? 'Your Shop Name'
                          : _shopNameController.text,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _shopAddressController.text.isEmpty
                          ? 'Shop Address'
                          : _shopAddressController.text,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          // Details Row
          Row(
            children: [
              _buildPreviewDetail(
                'Mobile',
                _shopMobileController.text.isEmpty
                    ? '9876543210'
                    : _shopMobileController.text,
              ),
              _buildPreviewDetail(
                'GSTIN',
                _gstinController.text.isEmpty ? 'N/A' : _gstinController.text,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'This is how your invoice header will look',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewDetail(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildSaveButton() {
    if (!_hasChanges) return null;

    return FadeTransition(
      opacity: _saveButtonAnimation,
      child: ScaleTransition(
        scale: _saveButtonAnimation,
        child: BoundedBox(
          maxWidth: 800,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveProfile,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(
                _isSaving ? 'Saving...' : 'Save Profile',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
                shadowColor: const Color(0xFF22C55E).withOpacity(0.4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Text formatter for uppercase input
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
