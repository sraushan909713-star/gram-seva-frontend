// lib/features/mandi_prices/widgets/item_picker.dart
// ══════════════════════════════════════════════════════════════
// Item picker bottom sheet.
// Returns the selected (or newly created) Item, or null if dismissed.
// Has two modes: list (default) and add-new (inline form).
// ══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_service.dart';
import '../models/item.dart';

/// Public API: show the item picker. Awaits the user's choice.
Future<Item?> showItemPicker(BuildContext context) {
  return showModalBottomSheet<Item>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cardBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _ItemPickerSheet(),
  );
}

class _ItemPickerSheet extends StatefulWidget {
  const _ItemPickerSheet();

  @override
  State<_ItemPickerSheet> createState() => _ItemPickerSheetState();
}

class _ItemPickerSheetState extends State<_ItemPickerSheet> {
  bool _loading = true;
  bool _addingNew = false;
  bool _submitting = false;

  List<Item> _items = [];
  String _search = '';

  final _nameCtrl = TextEditingController();
  final _nameHindiCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameHindiCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    try {
      final json = await ApiService.getItems();
      if (!mounted) return;
      setState(() {
        _items = json.map((j) => Item.fromJson(j as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Item> get _filtered {
    if (_search.isEmpty) return _items;
    final q = _search.toLowerCase();
    return _items.where((i) =>
      i.name.toLowerCase().contains(q) ||
      (i.nameHindi?.toLowerCase().contains(q) ?? false)
    ).toList();
  }

  Future<void> _submitNewItem() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Item ka naam zaruri hai');
      return;
    }

    setState(() => _submitting = true);
    try {
      final json = await ApiService.createItem(
        name: name,
        nameHindi: _nameHindiCtrl.text.trim().isEmpty
            ? null
            : _nameHindiCtrl.text.trim(),
      );
      final newItem = Item.fromJson(json);
      if (!mounted) return;
      Navigator.pop(context, newItem);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        _snack(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: GoogleFonts.inter())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final height = MediaQuery.of(context).size.height * 0.82;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SizedBox(
        height: height,
        child: SafeArea(
          child: Column(children: [
            _dragHandle(),
            if (_addingNew) ..._buildAddNew() else ..._buildList(),
          ]),
        ),
      ),
    );
  }

  Widget _dragHandle() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      width: 40, height: 4,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  // ══ List mode ═══════════════════════════════════════════════
  List<Widget> _buildList() {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: Row(children: [
          Text('Select item',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18, fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)),
          const SizedBox(width: 8),
          Text('· Item chunein',
            style: GoogleFonts.notoSansDevanagari(
              fontSize: 12, color: AppColors.textHint)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          onChanged: (v) => setState(() => _search = v),
          style: GoogleFonts.inter(fontSize: 14),
          decoration: _inputDecoration('Search item...').copyWith(
            prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textHint),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: InkWell(
          onTap: () => setState(() => _addingNew = true),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryBorder),
            ),
            child: Row(children: [
              Icon(Icons.add_circle_outline, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text('Add new item',
                style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: AppColors.primary)),
              const Spacer(),
              Icon(Icons.arrow_forward_ios, color: AppColors.primary, size: 12),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _filtered.isEmpty
            ? Center(child: Text('Koi item nahi mila',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textHint)))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                itemCount: _filtered.length,
                itemBuilder: (_, i) => _itemRow(_filtered[i]),
              ),
      ),
    ];
  }

  Widget _itemRow(Item item) {
    return InkWell(
      onTap: () => Navigator.pop(context, item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.nameHindi ?? item.name,
                style: GoogleFonts.notoSansDevanagari(
                  fontSize: 15, fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(item.name,
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.textHint)),
            ],
          )),
          if (item.isCustom)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Custom',
                style: GoogleFonts.inter(
                  fontSize: 9, color: AppColors.primary,
                  fontWeight: FontWeight.w600)),
            ),
        ]),
      ),
    );
  }

  // ══ Add-new mode ════════════════════════════════════════════
  List<Widget> _buildAddNew() {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 20, 12),
        child: Row(children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios, size: 18, color: AppColors.textPrimary),
            onPressed: () => setState(() {
              _addingNew = false;
              _nameCtrl.clear();
              _nameHindiCtrl.clear();
            }),
          ),
          const SizedBox(width: 4),
          Text('Add new item',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18, fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)),
        ]),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _formLabel('Name (English)', required: true),
              const SizedBox(height: 6),
              TextField(
                controller: _nameCtrl,
                style: GoogleFonts.inter(fontSize: 14),
                decoration: _inputDecoration('e.g. Chawal, Sarso Tel'),
              ),
              const SizedBox(height: 16),
              _formLabel('Name (Hindi) — optional'),
              const SizedBox(height: 6),
              TextField(
                controller: _nameHindiCtrl,
                style: GoogleFonts.notoSansDevanagari(fontSize: 14),
                decoration: _inputDecoration('e.g. चावल, सरसों का तेल'),
              ),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: _submitting ? null : _submitNewItem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _submitting
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Add Item',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
              )),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _formLabel(String text, {bool required = false}) {
    return RichText(
      text: TextSpan(
        text: text,
        style: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: AppColors.textSecondary),
        children: required ? [TextSpan(
          text: ' *',
          style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.bold))] : null,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textHint),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.primary)),
    );
  }
}