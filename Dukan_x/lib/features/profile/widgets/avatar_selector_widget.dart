// Avatar Selector Widget
// Grid view for selecting a professional avatar
//
// Created: 2024-12-26
// Author: DukanX Team

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/avatar_constants.dart';
import '../../../models/vendor_profile.dart';
import 'avatar_display_widget.dart';

class AvatarSelectorWidget extends StatefulWidget {
  final AvatarData? selectedAvatar;
  final Function(AvatarData) onSelected;

  const AvatarSelectorWidget({
    super.key,
    this.selectedAvatar,
    required this.onSelected,
  });

  @override
  State<AvatarSelectorWidget> createState() => _AvatarSelectorWidgetState();
}

class _AvatarSelectorWidgetState extends State<AvatarSelectorWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _categories = [
    AvatarConstants.categoryMale,
    AvatarConstants.categoryFemale,
    AvatarConstants.categoryNeutral,
  ];

  @override
  void initState() {
    super.initState();
    // Default to the category of selected avatar, or Male (0) if none
    int initialIndex = 0;
    if (widget.selectedAvatar != null) {
      initialIndex = _categories.indexOf(widget.selectedAvatar!.category);
      if (initialIndex == -1) initialIndex = 0;
    }
    _tabController = TabController(
      length: _categories.length,
      vsync: this,
      initialIndex: initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab Bar
        TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1E3A8A),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF1E3A8A),
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Male'),
            Tab(text: 'Female'),
            Tab(text: 'Business'),
          ],
        ),

        // Grid Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _categories.map((category) {
              final avatars = AvatarConstants.avatars
                  .where((a) => a.category == category)
                  .toList();

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                itemCount: avatars.length,
                itemBuilder: (context, index) {
                  final def = avatars[index];
                  final isSelected = widget.selectedAvatar?.avatarId == def.id;

                  return GestureDetector(
                    onTap: () {
                      widget.onSelected(
                        AvatarData(avatarId: def.id, category: def.category),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1E3A8A).withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(
                                color: const Color(0xFF1E3A8A),
                                width: 2,
                              )
                            : Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AvatarDisplayWidget(
                            avatar: AvatarData(
                              avatarId: def.id,
                              category: def.category,
                            ),
                            size: 60,
                            showBorder: false,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            def.label,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? const Color(0xFF1E3A8A)
                                  : Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
