// lib/features/mandi_prices/screens/edit_listing_screen.dart
// ══════════════════════════════════════════════════════════════
// Edit an existing vendor listing.
// Item and mode are LOCKED — only unit, price, stock, notes editable.
// Pre-fills every field for "effortless" updates.
// ══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_service.dart';
import '../models/unit.dart';
import '../models/vendor_listing.dart';
import '../widgets/unit_picker.dart';

class EditListingScreen extends StatefulWidget {
  final VendorListing listing;
  const EditListingScreen({super.key, required this.listing});

  @override
  State<EditListingScreen> createState() => _EditListingScreenState();
}

class _EditListingScreenState extends State<EditListingScreen> {
  Unit? _unit;
  late StockStatus _stock;
  late TextEditingController _priceCtrl;
  late TextEditingController _notesCtrl;

  bool _submitting = false;
  bool _loadingUnits = true;

  @override
  void initState() {
    super.initState();
    _stock = widget.listing.stockStatus;
    final p = widget.listing.price;
    _priceCtrl = TextEditingController(text: p == p.truncate() ? p.toInt().toString() : p.toString());
    _notesCtrl = TextEditingController(text: widget.listing.notes ?? '');
    _loadUnit();
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUnit() async {
    try {
      final json = await ApiService.getUnits();
      if (!mounted) return;
      final all = json.map((j) => Unit.fromJson(j)).toList();
      Unit? found;
      for (final u in all) {
        if (u.id == widget.listing.unitId) { found = u; break; }
      }
      setState(() {
        _unit = found;
        _loadingUnits = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingUnits = false);
    }
  }

  Future<void> _pickUnit() async {
    final picked = await showUnitPicker(context);
    if (picked != null) setState(() => _unit = picked);
  }

  Future<void> _submit() async {
    final price = double.tryParse(_priceCtrl.text.trim());
    if (price == null || price <= 0) return _snack('Sahi price daalein');
    if (_unit == null) return _snack('Unit chunein');

    setState(() => _submitting = true);
    try {
      await ApiService.updateVendorListing(widget.listing.id, {
        'unit_id':      _unit!.id,
        'price':        price,
        'stock_status': _stock.apiValue,
        'notes':        _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
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

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Listing delete karein?', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Text('Yeh listing app se hat jayegi.', style: GoogleFonts.inter()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: GoogleFonts.inter())),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.deleteVendorListing(widget.listing.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: GoogleFonts.inter())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.listing;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Edit Listing',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w600, fontSize: 20, color: Colors.white)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: Colors.white),
            onPressed: _delete,
            tooltip: 'Delete',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Locked: Item + Mode
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.itemNameHindi ?? l.itemName ?? '—',
                      style: GoogleFonts.notoSansDevanagari(
                        fontSize: 17, fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(l.itemName ?? '—',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textHint)),
                  ],
                )),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: l.mode == TradeMode.sell ? AppColors.ctaLight : AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: l.mode == TradeMode.sell ? AppColors.ctaBorder : AppColors.primaryBorder),
                  ),
                  child: Text('${l.mode.labelEn} · ${l.mode.labelHi}',
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: l.mode == TradeMode.sell ? AppColors.cta : AppColors.primary)),
                ),
              ]),
            ),
            const SizedBox(height: 6),
            Text('Item aur mode badle nahi ja sakte — sirf price/unit/stock/notes edit ho sakte hain',
              style: GoogleFonts.inter(fontSize: 10, color: AppColors.textHint, fontStyle: FontStyle.italic)),

            const SizedBox(height: 20),
            _label('Unit', required: true),
            const SizedBox(height: 8),
            _loadingUnits
              ? Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(children: [
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
                    const SizedBox(width: 12),
                    Text('Loading...', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textHint)),
                  ]),
                )
              : InkWell(
                  onTap: _pickUnit,
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
                        _unit == null
                          ? 'Unit chunein'
                          : (_unit!.nameHindi != null ? '${_unit!.name} · ${_unit!.nameHindi}' : _unit!.name),
                        style: _unit == null
                          ? GoogleFonts.inter(fontSize: 14, color: AppColors.textHint)
                          : GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                      )),
                      Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textHint),
                    ]),
                  ),
                ),

            const SizedBox(height: 20),
            _label('Price (₹)', required: true),
            const SizedBox(height: 8),
            TextField(
              controller: _priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
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
            Row(children: [
              _stockChip(StockStatus.inStock),
              const SizedBox(width: 8),
              _stockChip(StockStatus.limited),
              const SizedBox(width: 8),
              _stockChip(StockStatus.outOfStock),
            ]),

            const SizedBox(height: 20),
            _label('Notes (optional)'),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              style: GoogleFonts.inter(fontSize: 14),
              decoration: _inputDecoration('Notes...'),
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
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('Save Changes',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
            )),
          ],
        ),
      ),
    );
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
        child: Text(s.labelFor(widget.listing.mode),
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppColors.textSecondary)),
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