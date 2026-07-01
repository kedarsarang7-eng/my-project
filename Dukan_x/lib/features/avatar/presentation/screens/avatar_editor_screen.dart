import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dukanx/features/avatar/domain/models/avatar_data.dart';
import 'package:dukanx/features/avatar/domain/models/avatar_config.dart';
import 'package:dukanx/features/avatar/presentation/state/avatar_editor_provider.dart';
import 'package:dukanx/features/avatar/presentation/widgets/avatar_preview_widget.dart';
import 'package:dukanx/core/responsive/responsive.dart';

class AvatarEditorScreen extends ConsumerStatefulWidget {
  const AvatarEditorScreen({super.key});

  @override
  ConsumerState<AvatarEditorScreen> createState() => _AvatarEditorScreenState();
}

class _AvatarEditorScreenState extends ConsumerState<AvatarEditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _categories = [
    'skin',
    'face',
    'hair',
    'eyes',
    'brows',
    'nose',
    'mouth',
    'beard',
    'glasses',
    'top',
    'bottom',
    'shoes',
    'acc',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);

    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(avatarEditorProvider.notifier).loadAvatar();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(avatarEditorProvider);
    final avatarData = editorState.currentData;
    final canUndo = editorState.historyIndex > 0;
    final canRedo = editorState.historyIndex < editorState.history.length - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Customize Avatar'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: canUndo
                ? () => ref.read(avatarEditorProvider.notifier).undo()
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: canRedo
                ? () => ref.read(avatarEditorProvider.notifier).redo()
                : null,
          ),
          TextButton(
            onPressed: editorState.isSaving
                ? null
                : () async {
                    await ref.read(avatarEditorProvider.notifier).save();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Avatar Saved!')),
                      );
                      Navigator.of(context).pop();
                    }
                  },
            child: editorState.isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'SAVE',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = context.isMobile;
            
            final previewWidget = Container(
              color: const Color(0xFFF8FAFC),
              child: Center(
                child: Hero(
                  tag: 'avatar_preview',
                  child: AvatarPreviewWidget(
                    avatarData: avatarData,
                    width: isMobile ? 220 : 300,
                    height: isMobile ? 220 : 300,
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ),
            );

            final editorPanel = Column(
              children: [
                // Category Tabs
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: Colors.blue[700],
                    unselectedLabelColor: Colors.grey[600],
                    indicatorSize: TabBarIndicatorSize.label,
                    tabs: _categories
                        .map(
                          (cat) => Tab(
                            text: AvatarConfig.categoryLabels[cat] ?? cat.toUpperCase(),
                          ),
                        )
                        .toList(),
                  ),
                ),
                // Asset Grid Area
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: _categories
                        .map((cat) => _buildAssetGrid(cat, avatarData))
                        .toList(),
                  ),
                ),
              ],
            );

            if (isMobile) {
              return Column(
                children: [
                  SizedBox(
                    height: 250,
                    width: double.infinity,
                    child: previewWidget,
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: editorPanel,
                  ),
                ],
              );
            } else {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 4,
                    child: previewWidget,
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    flex: 6,
                    child: editorPanel,
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildAssetGrid(String category, AvatarData currentData) {
    List<String> options = [];
    String? selectedValue;
    Function(String) onSelect;

    // Map category to config list and selection handler
    switch (category) {
      case 'skin':
        options = AvatarConfig.skinTones;
        selectedValue = currentData.skinTone;
        onSelect = (val) => ref
            .read(avatarEditorProvider.notifier)
            .updateAvatar(currentData.copyWith(skinTone: val));
        break;
      case 'face':
        options = AvatarConfig.faceShapes;
        selectedValue = currentData.faceShape;
        onSelect = (val) => ref
            .read(avatarEditorProvider.notifier)
            .updateAvatar(currentData.copyWith(faceShape: val));
        break;
      case 'hair':
        options = AvatarConfig.hairStyles;
        selectedValue = currentData.hairStyle;
        onSelect = (val) => ref
            .read(avatarEditorProvider.notifier)
            .updateAvatar(currentData.copyWith(hairStyle: val));
        break;
      case 'eyes':
        options = AvatarConfig.eyes;
        selectedValue = currentData.eyes;
        onSelect = (val) => ref
            .read(avatarEditorProvider.notifier)
            .updateAvatar(currentData.copyWith(eyes: val));
        break;
      case 'brows':
        options = AvatarConfig.eyebrows;
        selectedValue = currentData.eyebrows;
        onSelect = (val) => ref
            .read(avatarEditorProvider.notifier)
            .updateAvatar(currentData.copyWith(eyebrows: val));
        break;
      case 'nose':
        options = AvatarConfig.noses;
        selectedValue = currentData.nose;
        onSelect = (val) => ref
            .read(avatarEditorProvider.notifier)
            .updateAvatar(currentData.copyWith(nose: val));
        break;
      case 'mouth':
        options = AvatarConfig.mouths;
        selectedValue = currentData.mouth;
        onSelect = (val) => ref
            .read(avatarEditorProvider.notifier)
            .updateAvatar(currentData.copyWith(mouth: val));
        break;
      case 'beard':
        options = AvatarConfig.facialHair;
        selectedValue = currentData.facialHair ?? 'none';
        onSelect = (val) => ref
            .read(avatarEditorProvider.notifier)
            .updateAvatar(
              currentData.copyWith(facialHair: val == 'none' ? '' : val),
            );
        break;
      case 'glasses':
        options = AvatarConfig.glasses;
        selectedValue = currentData.glasses ?? 'none';
        onSelect = (val) => ref
            .read(avatarEditorProvider.notifier)
            .updateAvatar(
              currentData.copyWith(glasses: val == 'none' ? '' : val),
            );
        break;
      case 'top':
        options = AvatarConfig.tops;
        selectedValue = currentData.outfitTop;
        onSelect = (val) => ref
            .read(avatarEditorProvider.notifier)
            .updateAvatar(currentData.copyWith(outfitTop: val));
        break;
      case 'bottom':
        options = AvatarConfig.bottoms;
        selectedValue = currentData.outfitBottom;
        onSelect = (val) => ref
            .read(avatarEditorProvider.notifier)
            .updateAvatar(currentData.copyWith(outfitBottom: val));
        break;
      case 'shoes':
        options = AvatarConfig.shoes;
        selectedValue = currentData.outfitShoes;
        onSelect = (val) => ref
            .read(avatarEditorProvider.notifier)
            .updateAvatar(currentData.copyWith(outfitShoes: val));
        break;
      case 'acc':
        options = AvatarConfig.accessories;
        selectedValue = currentData.outfitAccessories ?? 'none';
        onSelect = (val) => ref
            .read(avatarEditorProvider.notifier)
            .updateAvatar(
              currentData.copyWith(outfitAccessories: val == 'none' ? '' : val),
            );
        break;
      default:
        options = [];
        onSelect = (_) {};
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.0,
      ),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final option = options[index];
        final isSelected =
            selectedValue == option ||
            (selectedValue == '' && option == 'none');

        return GestureDetector(
          onTap: () => onSelect(option),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.blue.withOpacity(0.1)
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // In a real app, this would be a thumbnail of the asset
                // For now, we use a placeholder icon or text
                if (category == 'skin')
                  CircleAvatar(
                    backgroundColor: _getSkinColor(option),
                    radius: 24,
                  )
                else
                  Icon(Icons.checkroom, color: Colors.grey[700], size: 32),

                const SizedBox(height: 8),
                Text(
                  option.replaceAll('_', ' '),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getSkinColor(String code) {
    if (code.contains('light')) return const Color(0xFFFFDFC4);
    if (code.contains('medium')) return const Color(0xFFE0AC69);
    if (code.contains('dark')) return const Color(0xFF8D5524);
    return Colors.grey;
  }
}
