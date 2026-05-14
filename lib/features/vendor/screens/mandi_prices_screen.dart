// lib/features/vendor/screens/mandi_prices_screen.dart
// ─────────────────────────────────────────────────────────────
// Mandi Prices screen — shows vendor crop and animal feed prices.
// Villagers check today's rates without travelling to the mandi.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MandiPricesScreen extends StatefulWidget {
  const MandiPricesScreen({super.key});

  @override
  State<MandiPricesScreen> createState() => _MandiPricesScreenState();
}

class _MandiPricesScreenState extends State<MandiPricesScreen> {

  List<dynamic> _listings = [];
  bool _loading = true;
  String _selectedFilter = 'all';
  String? _userRole;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadListings();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() {
      _userRole = prefs.getString('user_role');
      _userId   = prefs.getString('user_id');
    });
  }

  Future<void> _loadListings() async {
    try {
      final data = await ApiService.getVendorListings(
        category: _selectedFilter == 'all' ? null : _selectedFilter,
      );
      if (mounted) setState(() {
        _listings = data;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      _loading = true;
    });
    _loadListings();
  }

  // — Time ago helper ───────────────────────────────────────
  String _timeAgo(String? dateStr) {
    if (dateStr == null) return 'Unknown';
    try {
      final dt = DateTime.parse(dateStr + 'Z').toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24)  return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }

  // — Stock status pill ─────────────────────────────────────
  Widget _stockPill(String status) {
    Color bg, text, border;
    String label;
    switch (status) {
      case 'in_stock':
        bg = AppColors.primaryLight; text = AppColors.primary;
        border = AppColors.primaryBorder; label = 'In stock';
        break;
      case 'limited':
        bg = AppColors.ctaLight; text = AppColors.cta;
        border = AppColors.ctaBorder; label = 'Limited';
        break;
      default:
        bg = const Color(0xFFFEE2E2); text = const Color(0xFF991B1B);
        border = const Color(0xFFFCA5A5); label = 'Out of stock';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10, fontWeight: FontWeight.w500, color: text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Crop Prices',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton:
          (_userRole == 'vendor' || _userRole == 'super_admin')
              ? FloatingActionButton.extended(
                  backgroundColor: AppColors.primary,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => _AddListingScreen(
                              onSaved: _loadListings,
                            )),
                  ),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: Text('Add Price',
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                )
              : null,
      body: SafeArea(
        child: Column(
          children: [
            // ✅ tagline banner
            Container(
              width: double.infinity,
              color: AppColors.primary,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'बेचें और खरीदें सही दाम पे',
                style: GoogleFonts.notoSansDevanagari(
                  color: Colors.white70, fontSize: 13),
              ),
            ),

            // — Filter chips ──────────────────────────────
            const SizedBox(height: 8),
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final f in [
                    {'key': 'all',         'label': 'All'},
                    {'key': 'crops',       'label': 'Crops'},
                    {'key': 'animal_feed', 'label': 'Animal Feed'},
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => _applyFilter(f['key']!),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: _selectedFilter == f['key']
                                ? AppColors.primary
                                : AppColors.cardBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _selectedFilter == f['key']
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                          ),
                          child: Text(
                            f['label']!,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _selectedFilter == f['key']
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // — Listings ──────────────────────────────────
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary))
                  : _listings.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('🌾',
                                  style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 12),
                              Text(
                                'No prices listed yet.',
                                style: GoogleFonts.inter(
                                    color: AppColors.textHint,
                                    fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: _loadListings,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(14),
                            itemCount: _listings.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final item = _listings[i];
                              final isCrop =
                                  item['category'] == 'crops';
                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.cardBg,
                                  borderRadius:
                                      BorderRadius.circular(14),
                                  border: Border.all(
                                      color: AppColors.border),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [

                                    // Product name + price
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment
                                              .spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment
                                                    .start,
                                            children: [
                                              Text(
                                                item['product_name'] ??
                                                    '',
                                                style: GoogleFonts.inter(
                                                  fontSize: 15,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                  color: AppColors
                                                      .textPrimary,
                                                ),
                                              ),
                                              if (item['product_name_hindi'] != null)
                                                Text(
                                                  item['product_name_hindi'],
                                                  style: GoogleFonts
                                                      .notoSansDevanagari(
                                                    fontSize: 11,
                                                    color: AppColors
                                                        .textHint,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '₹${(item['price'] % 1 == 0) ? item['price'].toInt() : item['price']}',
                                              style: GoogleFonts
                                                  .playfairDisplay(
                                                fontSize: 20,
                                                fontWeight:
                                                    FontWeight.w600,
                                                color: isCrop
                                                    ? AppColors.primary
                                                    : AppColors.cta,
                                              ),
                                            ),
                                            Text(
                                              item['unit'] ?? '',
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                color: AppColors.textHint,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 8),

                                    // Vendor badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isCrop
                                            ? AppColors.primaryLight
                                            : AppColors.ctaLight,
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isCrop
                                              ? AppColors.primaryBorder
                                              : AppColors.ctaBorder,
                                        ),
                                      ),
                                      child: Text(
                                        '${item['vendor_name']} · ${isCrop ? 'Crops' : 'Animal Feed'}',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: isCrop
                                              ? AppColors.primary
                                              : AppColors.cta,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 8),

                                    Divider(
                                        color: AppColors.border,
                                        height: 1),

                                    const SizedBox(height: 8),

                                    // Timestamp + stock status
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment
                                              .spaceBetween,
                                      children: [
                                        Text(
                                          'Updated ${_timeAgo(item['updated_at'])}',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: AppColors.textHint,
                                          ),
                                        ),
                                        _stockPill(
                                            item['stock_status'] ??
                                                'in_stock'),
                                      ],
                                    ),

                                    // Notes if any
                                    if (item['notes'] != null) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        item['notes'],
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  // Edit/Delete — vendor sees own, admin sees all
                                    if (_userRole == 'admin' ||
                                        _userRole == 'super_admin' ||
                                        (_userRole == 'vendor' &&
                                            item['vendor_id'] == _userId)) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          if (_userRole == 'vendor')
                                            GestureDetector(
                                              onTap: () =>
                                                  Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        _EditListingScreen(
                                                          listing:
                                                              item,
                                                          onSaved:
                                                              _loadListings,
                                                        )),
                                              ),
                                              child: Container(
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                    horizontal: 10,
                                                    vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: AppColors
                                                      .primaryLight,
                                                  borderRadius:
                                                      BorderRadius
                                                          .circular(20),
                                                  border: Border.all(
                                                      color: AppColors
                                                          .primaryBorder),
                                                ),
                                                child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                          Icons
                                                              .edit_outlined,
                                                          size: 12,
                                                          color: AppColors
                                                              .primary),
                                                      const SizedBox(
                                                          width: 4),
                                                      Text('Edit',
                                                          style: GoogleFonts
                                                              .inter(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600,
                                                            color: AppColors
                                                                .primary,
                                                          )),
                                                    ]),
                                              ),
                                            ),
                                          const SizedBox(width: 8),
                                          GestureDetector(
                                            onTap: () async {
                                              final bool? confirm = await showDialog(
                                                context: context,
                                                builder: (_) =>
                                                    AlertDialog(
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(
                                                              16)),
                                                  title: Text(
                                                      'Delete Listing',
                                                      style: GoogleFonts
                                                          .playfairDisplay(
                                                        fontWeight:
                                                            FontWeight
                                                                .w700,
                                                        color:
                                                            Colors.red,
                                                      )),
                                                  content: Text(
                                                      'Remove this price listing?',
                                                      style: GoogleFonts
                                                          .inter(
                                                              fontSize:
                                                                  13)),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context,
                                                              false),
                                                      child: Text(
                                                          'Cancel',
                                                          style: GoogleFonts
                                                              .inter(
                                                                  color: Colors
                                                                      .grey)),
                                                    ),
                                                    ElevatedButton(
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor:
                                                            Colors.red,
                                                        shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                    10)),
                                                      ),
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context,
                                                              true),
                                                      child: Text(
                                                          'Delete',
                                                          style: GoogleFonts
                                                              .inter(
                                                                  color: Colors
                                                                      .white)),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (confirm == true) {
                                                await ApiService
                                                    .deleteVendorListing(
                                                        item['id']);
                                                _loadListings();
                                              }
                                            },
                                            child: Container(
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                  horizontal: 10,
                                                  vertical: 5),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                    0xFFFEF2F2),
                                                borderRadius:
                                                    BorderRadius
                                                        .circular(20),
                                                border: Border.all(
                                                    color: const Color(
                                                        0xFFFCA5A5)),
                                              ),
                                              child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                        Icons
                                                            .delete_outline_rounded,
                                                        size: 12,
                                                        color: Colors
                                                            .red),
                                                    const SizedBox(
                                                        width: 4),
                                                    Text('Delete',
                                                        style: GoogleFonts
                                                            .inter(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight
                                                                  .w600,
                                                          color:
                                                              Colors.red,
                                                        )),
                                                  ]),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ADD LISTING SCREEN — vendor/admin only
// ══════════════════════════════════════════════════════════════
class _AddListingScreen extends StatefulWidget {
  final VoidCallback onSaved;
  const _AddListingScreen({required this.onSaved});

  @override
  State<_AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends State<_AddListingScreen> {
  final _nameCtrl  = TextEditingController();
  final _hindiCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _category    = 'crops';
  String _unit        = 'per kg';
  String _stockStatus = 'in_stock';
  bool   _saving      = false;

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _priceCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Product name and price are required.',
            style: GoogleFonts.inter()),
        backgroundColor: Colors.red,
      ));
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiService.createVendorListing({
        'product_name':       _nameCtrl.text.trim(),
        'product_name_hindi': _hindiCtrl.text.trim().isEmpty
            ? null : _hindiCtrl.text.trim(),
        'price':              double.parse(_priceCtrl.text.trim()),
        'unit':               _unit,
        'category':           _category,
        'stock_status':       _stockStatus,
        'notes':              _notesCtrl.text.trim().isEmpty
            ? null : _notesCtrl.text.trim(),
        'village_id':         '1',
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Listing added!', style: GoogleFonts.inter()),
          backgroundColor: AppColors.primary,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString(), style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) => _ListingForm(
        title:       'Add Price',
        nameCtrl:    _nameCtrl,
        hindiCtrl:   _hindiCtrl,
        priceCtrl:   _priceCtrl,
        notesCtrl:   _notesCtrl,
        category:    _category,
        unit:        _unit,
        stockStatus: _stockStatus,
        saving:      _saving,
        onCategoryChanged:    (v) => setState(() => _category    = v),
        onUnitChanged:        (v) => setState(() => _unit        = v),
        onStockStatusChanged: (v) => setState(() => _stockStatus = v),
        onSave: _save,
      );
}

// ══════════════════════════════════════════════════════════════
// EDIT LISTING SCREEN — vendor only (own listings)
// ══════════════════════════════════════════════════════════════
class _EditListingScreen extends StatefulWidget {
  final Map<String, dynamic> listing;
  final VoidCallback onSaved;
  const _EditListingScreen({required this.listing, required this.onSaved});

  @override
  State<_EditListingScreen> createState() => _EditListingScreenState();
}

class _EditListingScreenState extends State<_EditListingScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _hindiCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _notesCtrl;
  late String _category;
  late String _unit;
  late String _stockStatus;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final l    = widget.listing;
    _nameCtrl  = TextEditingController(text: l['product_name'] ?? '');
    _hindiCtrl = TextEditingController(text: l['product_name_hindi'] ?? '');
    _priceCtrl = TextEditingController(text: l['price']?.toString() ?? '');
    _notesCtrl = TextEditingController(text: l['notes'] ?? '');
    _category    = l['category']    ?? 'crops';
    _unit        = l['unit']        ?? 'per kg';
    _stockStatus = l['stock_status']?? 'in_stock';
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _priceCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Product name and price are required.',
            style: GoogleFonts.inter()),
        backgroundColor: Colors.red,
      ));
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiService.updateVendorListing(widget.listing['id'], {
        'product_name':       _nameCtrl.text.trim(),
        'product_name_hindi': _hindiCtrl.text.trim().isEmpty
            ? null : _hindiCtrl.text.trim(),
        'price':              double.parse(_priceCtrl.text.trim()),
        'unit':               _unit,
        'category':           _category,
        'stock_status':       _stockStatus,
        'notes':              _notesCtrl.text.trim().isEmpty
            ? null : _notesCtrl.text.trim(),
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Listing updated!', style: GoogleFonts.inter()),
          backgroundColor: AppColors.primary,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString(), style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) => _ListingForm(
        title:       'Edit Price',
        nameCtrl:    _nameCtrl,
        hindiCtrl:   _hindiCtrl,
        priceCtrl:   _priceCtrl,
        notesCtrl:   _notesCtrl,
        category:    _category,
        unit:        _unit,
        stockStatus: _stockStatus,
        saving:      _saving,
        onCategoryChanged:    (v) => setState(() => _category    = v),
        onUnitChanged:        (v) => setState(() => _unit        = v),
        onStockStatusChanged: (v) => setState(() => _stockStatus = v),
        onSave: _save,
      );
}

// ══════════════════════════════════════════════════════════════
// SHARED FORM WIDGET — used by both Add and Edit screens
// ══════════════════════════════════════════════════════════════
class _ListingForm extends StatelessWidget {
  final String title;
  final TextEditingController nameCtrl, hindiCtrl, priceCtrl, notesCtrl;
  final String category, unit, stockStatus;
  final bool saving;
  final void Function(String) onCategoryChanged;
  final void Function(String) onUnitChanged;
  final void Function(String) onStockStatusChanged;
  final VoidCallback onSave;

  const _ListingForm({
    required this.title,
    required this.nameCtrl, required this.hindiCtrl,
    required this.priceCtrl, required this.notesCtrl,
    required this.category, required this.unit,
    required this.stockStatus, required this.saving,
    required this.onCategoryChanged, required this.onUnitChanged,
    required this.onStockStatusChanged, required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(title,
            style: GoogleFonts.playfairDisplay(
                fontSize: 20, fontWeight: FontWeight.w600,
                color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          _lbl('Product Name *'),
          _field(nameCtrl, 'e.g. Wheat / गेहूँ'),

          _lbl('Hindi Name (optional)'),
          _field(hindiCtrl, 'e.g. गेहूँ'),

          _lbl('Price (₹) *'),
          _field(priceCtrl, 'e.g. 25',
              keyboardType: TextInputType.number),

          _lbl('Unit'),
          _drop(
            value: unit,
            items: ['per kg', 'per quintal', 'per piece', 'per litre'],
            onChanged: onUnitChanged,
          ),

          _lbl('Category'),
          _drop(
            value: category,
            items: ['crops', 'animal_feed'],
            labels: {'crops': 'Crops', 'animal_feed': 'Animal Feed'},
            onChanged: onCategoryChanged,
          ),

          _lbl('Stock Status'),
          _drop(
            value: stockStatus,
            items: ['in_stock', 'limited', 'out_of_stock'],
            labels: {
              'in_stock':     'In Stock',
              'limited':      'Limited',
              'out_of_stock': 'Out of Stock',
            },
            onChanged: onStockStatusChanged,
          ),

          _lbl('Notes (optional)'),
          _field(notesCtrl, 'e.g. Fresh harvest available', maxLines: 2),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: saving ? null : onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: saving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text('Save',
                      style: GoogleFonts.inter(
                          color: Colors.white, fontSize: 14,
                          fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  Widget _lbl(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
      );

  Widget _field(TextEditingController c, String hint,
      {int maxLines = 1, TextInputType keyboardType = TextInputType.text}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextField(
          controller: c,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
                color: AppColors.textHint, fontSize: 13),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primary)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      );

  Widget _drop({
    required String value,
    required List<String> items,
    Map<String, String>? labels,
    required void Function(String) onChanged,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textPrimary),
              items: items
                  .map((v) => DropdownMenuItem(
                        value: v,
                        child:
                            Text(labels != null ? (labels[v] ?? v) : v),
                      ))
                  .toList(),
              onChanged: (v) => onChanged(v!),
            ),
          ),
        ),
      );
}
