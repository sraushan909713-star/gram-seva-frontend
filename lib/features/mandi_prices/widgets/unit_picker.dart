// lib/features/mandi_prices/widgets/unit_picker.dart
// ══════════════════════════════════════════════════════════════
// Unit picker bottom sheet. Same pattern as item picker, simpler form.
// ══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_service.dart';
import '../models/unit.dart';

Future<Unit?> showUnitPicker(BuildContext context) {
  return showModalBottomSheet<Unit>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cardBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _UnitPickerSheet(),
  );
}

class _UnitPickerSheet extends StatefulWidget {
  const _UnitPickerSheet();

  @override
  State<_UnitPickerSheet> createState() => _UnitPickerSheetState();
}

class _UnitPickerSheetState extends State<_UnitPickerSheet> {
  bool _loading = true;
  bool _addingNew = false;
  bool _submitting = false;

  List<Unit> _units = [];
  final _nameCtrl = TextEditingController();
  final _nameHindiCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameHindiCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUnits() async {
    try {
      final json = await ApiService.getUnits();
      if (!mounted) return;
      setState(() {
        _units = json.map((j) => Unit.fromJson(j as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitNewUnit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Unit ka naam zaruri hai');
      return;
    }
    setState(() => _submitting = true);
    try {
      final json = await ApiService.createUnit(
        name: name,
        nameHindi: _nameHindiCtrl.text.trim().isEmpty ? null : _nameHindiCtrl.text.trim(),
      );
      final newUnit = Unit.fromJson(json);
      if (!mounted) return;
      Navigator.pop(context, newUnit);
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
    final height = MediaQuery.of(context).size.height * 0.7;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SizedBox(
        height: height,
        child: SafeArea(
          child: Column(children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            if (_addingNew) ..._buildAddNew() else ..._buildList(),
          ]),
        ),
      ),
    );
  }

  List<Widget> _buildList() {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: Row(children: [
          Text('Select unit',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18, fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)),
          const SizedBox(width: 8),
          Text('· Unit chunein',
            style: GoogleFonts.notoSansDevanagari(
              fontSize: 12, color: AppColors.textHint)),
        ]),
      ),
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
              Text('Add new unit',
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
          : _units.isEmpty
            ? Center(child: Text('Koi unit nahi hai',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textHint)))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                itemCount: _units.length,
                itemBuilder: (_, i) {
                  final unit = _units[i];
                  return InkWell(
                    onTap: () => Navigator.pop(context, unit),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      child: Row(children: [
                        Expanded(child: Row(children: [
                          Text(unit.name,
                            style: GoogleFonts.inter(
                              fontSize: 15, fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                          if (unit.nameHindi != null) ...[
                            const SizedBox(width: 8),
                            Text('· ${unit.nameHindi}',
                              style: GoogleFonts.notoSansDevanagari(
                                fontSize: 13, color: AppColors.textHint)),
                          ],
                        ])),
                        if (unit.isCustom)
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
                },
              ),
      ),
    ];
  }

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
          Text('Add new unit',
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
              RichText(text: TextSpan(
                text: 'Name (English)',
                style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary),
                children: [TextSpan(
                  text: ' *',
                  style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.bold))],
              )),
              const SizedBox(height: 6),
              TextField(
                controller: _nameCtrl,
                style: GoogleFonts.inter(fontSize: 14),
                decoration: _inputDecoration('e.g. bori, packet'),
              ),
              const SizedBox(height: 16),
              Text('Name (Hindi) — optional',
                style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: _nameHindiCtrl,
                style: GoogleFonts.notoSansDevanagari(fontSize: 14),
                decoration: _inputDecoration('e.g. बोरी'),
              ),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: _submitting ? null : _submitNewUnit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _submitting
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Add Unit',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
              )),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    ];
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