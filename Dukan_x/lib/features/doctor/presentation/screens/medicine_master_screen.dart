import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/repository/products_repository.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/theme/futuristic_colors.dart';
import '../../../../widgets/desktop/desktop_content_container.dart';
import '../../../../widgets/modern_ui_components.dart';
import 'package:dukanx/core/responsive/responsive.dart';

/// Medicine Master Screen - Manage medicines for prescriptions
///
/// Features:
/// - List all medicines (products with category = 'medicine')
/// - Add new medicine with dosage, strength, price
/// - Edit existing medicine
/// - Search medicines
class MedicineMasterScreen extends ConsumerStatefulWidget {
  const MedicineMasterScreen({super.key});

  @override
  ConsumerState<MedicineMasterScreen> createState() =>
      _MedicineMasterScreenState();
}

class _MedicineMasterScreenState extends ConsumerState<MedicineMasterScreen> {
  final _productsRepo = sl<ProductsRepository>();
  final _searchController = TextEditingController();

  List<Product> _medicines = [];
  List<Product> _filteredMedicines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedicines();
  }

  Future<void> _loadMedicines() async {
    setState(() => _isLoading = true);

    try {
      final userId = sl<SessionManager>().ownerId ?? '';
      final result = await _productsRepo.getAll(userId: userId);

      if (result.data != null) {
        // Filter for medicines category
        setState(() {
          _medicines = result.data!
              .where(
                (p) =>
                    p.category?.toLowerCase() == 'medicine' ||
                    p.category?.toLowerCase() == 'medicines' ||
                    p.category?.toLowerCase() == 'drug',
              )
              .toList();
          _filteredMedicines = _medicines;
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterMedicines(String query) {
    if (query.isEmpty) {
      setState(() => _filteredMedicines = _medicines);
    } else {
      setState(() {
        _filteredMedicines = _medicines
            .where((m) => m.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopContentContainer(
      title: 'Medicine Master',
      subtitle: 'Manage prescription medicines',
      actions: [
        PrimaryButton(
          label: 'Add Medicine',
          icon: Icons.add,
          onPressed: () => _showMedicineDialog(null),
        ),
      ],
      child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search medicines...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: FuturisticColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _filterMedicines,
            ),
          ),

          // Medicines list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredMedicines.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredMedicines.length,
                    itemBuilder: (context, index) =>
                        _buildMedicineCard(_filteredMedicines[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medication_outlined,
            size: 64,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No medicines found',
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _showMedicineDialog(null),
            icon: const Icon(Icons.add),
            label: const Text('Add your first medicine'),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineCard(Product medicine) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: FuturisticColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: FuturisticColors.primary.withOpacity(0.2),
          child: Icon(Icons.medication, color: FuturisticColors.primary),
        ),
        title: Text(
          medicine.name,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                _buildInfoChip(
                  '₹${medicine.sellingPrice.toStringAsFixed(2)}',
                  Colors.green,
                ),
                const SizedBox(width: 8),
                if (medicine.unit.isNotEmpty)
                  _buildInfoChip(medicine.unit, Colors.blue),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white54),
          color: FuturisticColors.surface,
          onSelected: (value) {
            if (value == 'edit') {
              _showMedicineDialog(medicine);
            } else if (value == 'delete') {
              _deleteMedicine(medicine);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Future<void> _showMedicineDialog(Product? medicine) async {
    final nameController = TextEditingController(text: medicine?.name ?? '');
    final priceController = TextEditingController(
      text: medicine?.sellingPrice.toString() ?? '',
    );
    final unitController = TextEditingController(text: medicine?.unit ?? 'pcs');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FuturisticColors.surface,
        title: Text(
          medicine == null ? 'Add Medicine' : 'Edit Medicine',
          style: const TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Medicine Name *',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: priceController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Price (₹)',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: unitController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Medicine name is required')),
                );
                return;
              }

              final userId = sl<SessionManager>().ownerId ?? '';
              final price = double.tryParse(priceController.text) ?? 0.0;

              if (medicine == null) {
                // Create new medicine using createProduct
                await _productsRepo.createProduct(
                  userId: userId,
                  name: nameController.text,
                  category: 'medicine',
                  sellingPrice: price,
                  costPrice: price * 0.7,
                  unit: unitController.text,
                );
              } else {
                // Update existing
                final updated = medicine.copyWith(
                  name: nameController.text,
                  sellingPrice: price,
                  unit: unitController.text,
                  updatedAt: DateTime.now(),
                );

                await _productsRepo.updateProduct(updated, userId: userId);
              }

              if (context.mounted) Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: FuturisticColors.primary,
            ),
            child: Text(medicine == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      _loadMedicines();
    }
  }

  Future<void> _deleteMedicine(Product medicine) async {
    final userId = sl<SessionManager>().ownerId ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FuturisticColors.surface,
        title: const Text(
          'Delete Medicine?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${medicine.name}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _productsRepo.deleteProduct(medicine.id, userId: userId);
      _loadMedicines();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Medicine deleted')));
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
