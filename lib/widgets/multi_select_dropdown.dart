import 'package:flutter/material.dart';

class MultiSelectDropdown extends StatefulWidget {
  final List<String> items;
  final List<String> selectedItems;
  final Function(List<String>) onChanged;
  final String hint;

  const MultiSelectDropdown({
    super.key,
    required this.items,
    required this.selectedItems,
    required this.onChanged,
    this.hint = "Select Items",
  });

  @override
  State<MultiSelectDropdown> createState() => _MultiSelectDropdownState();
}

class _MultiSelectDropdownState extends State<MultiSelectDropdown> {
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
            child: TapRegion(
              onTapOutside: (_) => _closeDropdown(),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 250),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: widget.items.isEmpty 
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text("No items available", style: TextStyle(color: Colors.white54)),
                    )
                  : ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: widget.items.length,
                    itemBuilder: (context, index) {
                      final item = widget.items[index];
                      final isSelected = widget.selectedItems.contains(item);
          
                      return CheckboxListTile(
                        title: Text(item, style: const TextStyle(color: Colors.white)),
                        value: isSelected,
                        activeColor: const Color(0xFFBB86FC),
                        checkColor: Colors.black,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        onChanged: (bool? checked) {
                          List<String> newSelection = List.from(widget.selectedItems);
                          if (checked == true) {
                            newSelection.add(item);
                          } else {
                            newSelection.remove(item);
                          }
                          widget.onChanged(newSelection);
                          _overlayEntry!.markNeedsBuild();
                        },
                      );
                    },
                  ),
              ),
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
  void didUpdateWidget(covariant MultiSelectDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isDropdownOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _overlayEntry?.markNeedsBuild();
      });
    }
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
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggleDropdown,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.selectedItems.isEmpty
                      ? widget.hint
                      : widget.selectedItems.join(", "),
                  style: TextStyle(
                    fontSize: 16, 
                    color: widget.selectedItems.isEmpty ? Colors.white38 : Colors.white
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                _isDropdownOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
