import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/collection.dart';

class CollectionSelector extends StatefulWidget {
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final String? label;

  const CollectionSelector({
    super.key,
    required this.selectedId,
    required this.onChanged,
    this.label = "Select Collection",
    this.isDense = false,
  });

  final bool isDense;

  @override
  State<CollectionSelector> createState() => _CollectionSelectorState();
}

class _CollectionSelectorState extends State<CollectionSelector> {
  final FirestoreService _dbService = FirestoreService();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isDropdownOpen = false;

  void _toggleDropdown() {
    if (_isDropdownOpen) {
      _closeDropdown();
    } else {
      _showDropdown();
    }
  }

  void _showDropdown() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0.0, size.height + 5.0),
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFF1E1E1E), // Match app theme
            shadowColor: Colors.black54,
            child: StreamBuilder<List<Collection>>(
              stream: _dbService.getEditableCollectionsStream(),
              builder: (context, snapshot) {
                final collections = snapshot.data ?? [];

                return TapRegion(
                  groupId: 'collection-dropdown-${widget.hashCode}',
                  onTapOutside: (_) => _closeDropdown(),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: collections.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              "No collections available.",
                              style: TextStyle(color: Colors.white54),
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: collections.length,
                            itemBuilder: (context, index) {
                              final col = collections[index];
                              final isSelected = col.id == widget.selectedId;

                              return InkWell(
                                onTap: () {
                                  widget.onChanged(col.id);
                                  _closeDropdown();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.folder_outlined,
                                        size: 18,
                                        color: isSelected
                                            ? const Color(0xFFBB86FC)
                                            : Colors.grey,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          col.name,
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.white70,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(
                                          Icons.check,
                                          color: Color(0xFFBB86FC),
                                          size: 18,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isDropdownOpen = true);
  }

  void _closeDropdown() {
    _overlayEntry?.remove();
    setState(() => _isDropdownOpen = false);
  }

  @override
  void didUpdateWidget(covariant CollectionSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If external selection changed, we might want to close dropdown or update UI,
    // but since UI is rebuilt on build(), usually fine.
    // However, ensure overlay matches size if layout changes (rare here)
  }

  @override
  void dispose() {
    if (_isDropdownOpen) {
      _overlayEntry?.remove();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Collection>>(
      stream: _dbService.getEditableCollectionsStream(),
      builder: (context, snapshot) {
        final collections = snapshot.data ?? [];

        // Ensure selected ID is valid logic (kept from previous implementation)
        String? validSelectedId = widget.selectedId;
        String displayLabel = widget.label ?? "Select Collection";

        if (collections.isNotEmpty) {
          // Auto-select first logic
          if (validSelectedId == null ||
              !collections.any((c) => c.id == validSelectedId)) {
            validSelectedId = collections.first.id;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (widget.selectedId != validSelectedId && mounted) {
                widget.onChanged(validSelectedId);
              }
            });
          } else {
            // Find name for display
            final selectedCol = collections.firstWhere(
              (c) => c.id == validSelectedId,
            );
            displayLabel = selectedCol.name;
          }
        } else {
          displayLabel = "No Collections";
        }

        return TapRegion(
          groupId: 'collection-dropdown-${widget.hashCode}',
          child: CompositedTransformTarget(
            link: _layerLink,
            child: GestureDetector(
              onTap: collections.isEmpty ? null : _toggleDropdown,
              child: Container(
                padding: widget.isDense
                    ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                    : const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: widget.isDense
                      ? null
                      : Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        displayLabel,
                        style: TextStyle(
                          fontSize: 16,
                          color: (validSelectedId == null)
                              ? Colors.white38
                              : Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      _isDropdownOpen
                          ? Icons.arrow_drop_up
                          : Icons.arrow_drop_down,
                      color: Colors.white70,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

