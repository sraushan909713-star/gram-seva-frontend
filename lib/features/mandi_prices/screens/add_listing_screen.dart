// lib/features/mandi_prices/screens/add_listing_screen.dart
// ══════════════════════════════════════════════════════════════
// Add a new vendor listing. Used by vendor / admin / super_admin.
// Mode toggle, item picker, unit picker, price, stock, notes.
// ══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_service.dart';
import '../models/item.dart';
import '../models/unit.dart';
import '../models/vendor_listing.dart';
import '../widgets/item_picker.dart';
import '../widgets/unit_picker.dart';

class AddListingScreen extends StatefulWidget {
  const AddListingScreen({super.key});

  @override
  State<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends State<AddListingScreen> {
  TradeMode _mode = TradeMode.sell;
  Item? _item;
  Unit? _unit;
  StockStatus _stock = StockStatus.inStock;

  final _priceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _submitting = false;
  List<Unit> _allUnits = [];

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUnits() async {
    try {
      final json = await ApiService.getUnits();
      if (!mounted) return;
      setState(() => _allUnits = json.map((j) => Unit.fromJson(j)).toList());
    } catch (_) {}
  }

  Future<void> _pickItem() async {
    final picked = await showItemPicker(context);
    if (picked == null) return;
    setState(() {
      _item = picked;
      // Auto-fill unit from item's default if user hasn't already picked one
      if (_unit == null && picked.defaultUnitId != null) {
        for (final u in _allUnits) {
          if (u.id == picked.defaultUnitId) {
            _unit = u;
            break;
          }
        }
      }
    });
  }

  Future<void> _pickUnit() async {
    final picked = await showUnitPicker(context);
    if (picked != null) setState(() => _unit = picked);
  }

  Future<void> _submit() async {
    if (_item == null)  return _snack('Item chunein');
    if (_unit == null)  return _snack('Unit chunein');
    final price = double.tryParse(_priceCtrl.text.trim());
    if (price == null || price <= 0) return _snack('Sahi price daalein');

    setState(() => _submitting = true);
    try {
      await ApiService.createVendorListing({
        'item_id':       _item!.id,
        'unit_id':       _unit!.id,
        'mode':          _mode.apiValue,
        'price':         price,
        'stock_status':  _stock.apiValue,
        if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
        'village_id':    '1',
      });
      if (!mounted) return;
      Navigator.pop(context, true);
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Naya Listing',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w600, fontSize: 20, color: Colors.white)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Mode', required: true),
            const SizedBox(height: 8),
            _buildModeToggle(),
            const SizedBox(height: 20),

            _label('Item', required: true),
            const SizedBox(height: 8),
            _buildPickerField(
              value: _item == null
                  ? null
                  : '${_item!.nameHindi ?? _item!.name} · ${_item!.name}',
              placeholder: 'Item chunein',
              onTap: _pickItem,
            ),
            const SizedBox(height: 20),

            _label('Unit', required: true),
            const SizedBox(height: 8),
            _buildPickerField(
              value: _unit == null
                  ? null
                  : _unit!.nameHindi != null
                      ? '${_unit!.name} · ${_unit!.nameHindi}'
                      : _unit!.name,
              placeholder: 'Unit chunein',
              onTap: _pickUnit,
            ),
            const SizedBox(height: 20),

            _label('Price (₹)', required: true),
            const SizedBox(height: 8),
            TextField(
              controller: _priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
              ],
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
              decoration: _inputDecoration('e.g. 45').copyWith(
                prefixText: '₹ ',
                prefixStyle: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(height: 20),

            _label('Stock status'),
            const SizedBox(height: 8),
            _buildStockChips(),
            const SizedBox(height: 20),

            _label('Notes (optional)'),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              style: GoogleFonts.inter(fontSize: 14),
              decoration: _inputDecoration('e.g. Premium basmati, fresh stock arrived today'),
            ),
            const SizedBox(height: 28),

            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _submitting
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('Add Listing',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Row(children: [
      _modeOption(TradeMode.sell),
      const SizedBox(width: 8),
      _modeOption(TradeMode.buy),
    ]);
  }

  Widget _modeOption(TradeMode mode) {
    final active = _mode == mode;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _mode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? AppColors.primary : AppColors.border),
        ),
        alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(mode.labelEn,
            style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: active ? Colors.white : AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(mode.labelHi,
            style: GoogleFonts.notoSansDevanagari(
              fontSize: 11,
              color: active ? Colors.white70 : AppColors.textHint).copyWith(
                height: 1.0,
                leadingDistribution: TextLeadingDistribution.even,
              )),
        ]),
      ),
    ));
  }

  Widget _buildPickerField({
    required String? value,
    required String placeholder,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Expanded(child: Text(
            value ?? placeholder,
            style: value == null
              ? GoogleFonts.inter(fontSize: 14, color: AppColors.textHint)
              : GoogleFonts.notoSansDevanagari(
                  fontSize: 14, fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary),
          )),
          Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textHint),
        ]),
      ),
    );
  }

  Widget _buildStockChips() {
    return Row(children: [
      _stockChip(StockStatus.inStock),
      const SizedBox(width: 8),
      _stockChip(StockStatus.limited),
      const SizedBox(width: 8),
      _stockChip(StockStatus.outOfStock),
    ]);
  }

  Widget _stockChip(StockStatus s) {
    final active = _stock == s;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _stock = s),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? AppColors.primary : AppColors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          s.labelFor(_mode),
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppColors.textSecondary),
        ),
      ),
    ));
  }

  Widget _label(String text, {bool required = false}) {
    return RichText(text: TextSpan(
      text: text,
      style: GoogleFonts.inter(
        fontSize: 12, fontWeight: FontWeight.w600,
        color: AppColors.textSecondary),
      children: required ? [TextSpan(
        text: ' *',
        style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.bold))] : null,
    ));
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textHint),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.primary)),
    );
  }
}