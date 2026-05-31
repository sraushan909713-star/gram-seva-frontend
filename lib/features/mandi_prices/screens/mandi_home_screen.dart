// lib/features/mandi_prices/screens/mandi_home_screen.dart
// ══════════════════════════════════════════════════════════════
// Mandi home — villager view.
// Matches Gram Awaaz / Vikas Prastav / Schemes / Guides pattern:
//   • App bar: back + title + actions (refresh, filter) top-right
//   • Green strip with Hindi tagline below app bar
//   • Dark green filter band with Khareedein/Bechein pills
//   • Count + active-filter row beneath
//   • Item list with curated order and freshness colors
// ══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_service.dart';
import '../models/vendor_listing.dart';
import '../models/item.dart';
import 'item_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';                                   // ✅ ADD
import 'my_listings_screen.dart';                                                              // ✅ ADD

class MandiHomeScreen extends StatefulWidget {
  const MandiHomeScreen({super.key});

  @override
  State<MandiHomeScreen> createState() => _MandiHomeScreenState();
}

class _MandiHomeScreenState extends State<MandiHomeScreen> {

  TradeMode _mode = TradeMode.buy;
  String? _vendorFilterId;

  bool _loading = true;
  List<Item> _items = [];
  List<VendorListing> _listings = [];
  List<dynamic> _vendors = [];

  String? _userRole;                                                                            // ✅ ADD
  bool get _canManageListings =>
      _userRole == 'vendor' || _userRole == 'admin' || _userRole == 'super_admin';

  @override
  void initState() {
    super.initState();
    _loadAll();
    _loadUserRole();                                                                            // ✅ ADD
  }

  Future<void> _loadUserRole() async {                                                          // ✅ ADD
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _userRole = prefs.getString('user_role'));
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      // ✅ Villager intent ↔ vendor listing side.
      // Villager's "Khareedein" (buy) shows vendor SELL listings, and vice versa.
      final apiMode = _mode == TradeMode.buy ? 'sell' : 'buy';
      final results = await Future.wait([
        ApiService.getItems(),
        ApiService.getVendorListings(
          mode: apiMode,                                                    // ✅ inverted
          vendorId: _vendorFilterId,
        ),
        ApiService.getVendors(),
      ]);
      if (!mounted) return;

      final rawUsers = results[2] as List;
      final onlyVendors = rawUsers.where((u) {
        final role = u['role']?.toString().toLowerCase() ?? '';
        return role == 'vendor';
      }).toList();

      setState(() {
        _items    = (results[0] as List).map((j) => Item.fromJson(j)).toList();
        _listings = (results[1] as List).map((j) => VendorListing.fromJson(j)).toList();
        _vendors  = onlyVendors;
        _loading  = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ══ Aggregation ═════════════════════════════════════════════
  List<_ItemAggregate> _buildAggregates() {
    final byItem = <String, List<VendorListing>>{};
    for (final l in _listings) {
      byItem.putIfAbsent(l.itemId, () => []).add(l);
    }

    final aggregates = <_ItemAggregate>[];
    for (final item in _items) {
      final entries = byItem[item.id] ?? const <VendorListing>[];
      if (entries.isEmpty) continue;

      VendorListing? best;
      for (final tier in [StockStatus.inStock, StockStatus.limited, StockStatus.outOfStock]) {
        final pool = entries.where((e) => e.stockStatus == tier).toList();
        if (pool.isEmpty) continue;
        pool.sort((a, b) => _mode == TradeMode.buy
            ? a.price.compareTo(b.price)
            : b.price.compareTo(a.price));
        best = pool.first;
        break;
      }
      if (best == null) continue;

      aggregates.add(_ItemAggregate(
        item: item,
        bestListing: best,
        vendorCount: entries.length,
      ));
    }
    return aggregates;
  }

  // ══ Freshness ═══════════════════════════════════════════════
  _Freshness _freshnessOf(DateTime? updatedAt) {
    if (updatedAt == null) return _Freshness.stale;
    final diff = DateTime.now().toUtc().difference(updatedAt.toUtc());
    if (diff.inHours < 24) return _Freshness.fresh;
    if (diff.inDays  < 7)  return _Freshness.neutral;
    return _Freshness.stale;
  }

  Color _priceColorOf(_Freshness f) {
    switch (f) {
      case _Freshness.fresh:   return AppColors.primary;
      case _Freshness.neutral: return AppColors.textPrimary;
      case _Freshness.stale:   return AppColors.textHint;
    }
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    // ✅ Backend returns naive UTC timestamps without 'Z' suffix.
    // Dart parses these as local time by default — re-interpret as UTC explicitly.
    final dtUtc = dt.isUtc
        ? dt
        : DateTime.utc(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second);
    final diff = DateTime.now().toUtc().difference(dtUtc);
    if (diff.inMinutes < 1)  return 'Abhi abhi';                                    // ✅ <1 min reads natural
    if (diff.inMinutes < 60) return '${diff.inMinutes} min pehle';
    if (diff.inHours   < 24) return '${diff.inHours} ghante pehle';
    if (diff.inDays    < 2)  return 'Kal';
    return '${diff.inDays} din pehle';
  }

  // ══ Build ═══════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final aggregates = _buildAggregates();
    final hasFilter = _vendorFilterId != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: _canManageListings                                                  // ✅ ADD
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              onPressed: () async {
                await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MyListingsScreen()));
                _loadAll(); // refresh after returning, prices may have changed
              },
              icon: const Icon(Icons.inventory_2_outlined, color: Colors.white),
              label: Text('My Listings',
                style: GoogleFonts.inter(
                  color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
      appBar: AppBar(
        title: Text(
          'Mandi',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w600, fontSize: 20, color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll),                  // ✅ ADD — matches Gram Awaaz
          IconButton(                                                                         // ✅ filter action
            tooltip: 'Filter by vendor',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.filter_list_rounded),
                if (hasFilter)
                  Positioned(
                    top: -2, right: -2,
                    child: Container(
                      width: 9, height: 9,
                      decoration: BoxDecoration(
                        color: AppColors.cta,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _showVendorFilterSheet,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ══ Tagline strip (still primary green) ═════════════
          Container(
            width: double.infinity,
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),                                 // ✅ matched 14 padding
            child: Text(
              'बेचें और खरीदें सही दाम पे',
              style: GoogleFonts.notoSansDevanagari(
                color: Colors.white70, fontSize: 13,
              ),
            ),
          ),

          // ══ Filter band — dark green, matches Gram Awaaz ═══
          _buildFilterRow(),                                                                   // ✅ CHANGE — dark green band

          // ══ Count + active filter row ════════════════════════
          if (!_loading) _buildCountRow(aggregates.length, hasFilter),                         // ✅ ADD

          // ══ Item list ═══════════════════════════════════════
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                : aggregates.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: _loadAll,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                          itemCount: aggregates.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _buildItemCard(aggregates[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ══ Filter band — replicates Gram Awaaz _buildFilterRow ════
  Widget _buildFilterRow() {
    return Container(
      height: 50,
      color: AppColors.primaryDark,                                                            // ✅ matches Gram Awaaz
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Center(child: _ModeChip(
            label: 'खरीदें',
            isSelected: _mode == TradeMode.buy,
            onTap: () {
              if (_mode == TradeMode.buy) return;
              setState(() => _mode = TradeMode.buy);
              _loadAll();
            },
          )),
          const SizedBox(width: 8),
          Center(child: _ModeChip(
            label: 'बेचें',
            isSelected: _mode == TradeMode.sell,
            onTap: () {
              if (_mode == TradeMode.sell) return;
              setState(() => _mode = TradeMode.sell);
              _loadAll();
            },
          )),
        ],
      ),
    );
  }

  // ══ Count + active filter row ═══════════════════════════════
  Widget _buildCountRow(int count, bool hasFilter) {
    String filterLabel = '';
    if (hasFilter) {
      for (final v in _vendors) {
        if (v['id'] == _vendorFilterId) {
          filterLabel = (v['shop_name'] ?? v['full_name'] ?? 'Vendor') as String;
          break;
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          Text(
            '$count items',
            style: GoogleFonts.inter(
              fontSize: 13, color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          if (hasFilter)
            GestureDetector(
              onTap: () {
                setState(() => _vendorFilterId = null);
                _loadAll();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.person_outline_rounded, size: 12, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    filterLabel,
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.close_rounded, size: 12, color: AppColors.primary),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  // ══ Vendor filter bottom sheet ═════════════════════════════
  void _showVendorFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(children: [
                  Text(
                    'Select vendor',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 18, fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '· विक्रेता चुनें',
                    style: GoogleFonts.notoSansDevanagari(
                      fontSize: 12, color: AppColors.textHint,
                    ),
                  ),
                ]),
              ),
              Container(height: 1, color: AppColors.border),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: [
                    _vendorOptionRow(sheetCtx, 'All vendors', null),
                    if (_vendors.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'Koi vendor abhi register nahi hua hai',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textHint),
                        ),
                      )
                    else
                      for (final v in _vendors)
                        _vendorOptionRow(
                          sheetCtx,
                          (v['shop_name'] ?? v['full_name'] ?? 'Vendor') as String,
                          v['id'] as String,
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _vendorOptionRow(BuildContext sheetCtx, String label, String? vendorId) {
    final active = _vendorFilterId == vendorId;
    return InkWell(
      onTap: () {
        setState(() => _vendorFilterId = vendorId);
        Navigator.pop(sheetCtx);
        _loadAll();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: active ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ),
          if (active) Icon(Icons.check_rounded, color: AppColors.primary, size: 20),
        ]),
      ),
    );
  }

  // ══ Item card ═══════════════════════════════════════════════
  Widget _buildItemCard(_ItemAggregate agg) {
    final l = agg.bestListing;
    final freshness = _freshnessOf(l.updatedAt);
    final priceColor = _priceColorOf(freshness);
    final isStale = freshness == _Freshness.stale;
    final filtered = _vendorFilterId != null;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ItemDetailScreen(
            item: agg.item,
            mode: _mode,
            vendorFilterId: _vendorFilterId,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),                                             // ✅ matched Gram Awaaz radius
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 3),
          )],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        agg.item.nameHindi ?? agg.item.name,
                        style: GoogleFonts.notoSansDevanagari(
                          fontSize: 18, fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary, height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        agg.item.name,
                        style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${_fmtPrice(l.price)}',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 22, fontWeight: FontWeight.w700,
                        color: priceColor, height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'per ${l.unitName ?? ""}',
                      style: GoogleFonts.inter(
                        fontSize: 10, color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(height: 1, color: const Color(0xFFF3F4F6)),
            const SizedBox(height: 9),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!filtered)
                  Text(
                    '${agg.vendorCount} vendor${agg.vendorCount == 1 ? "" : "s"}',
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textHint),
                  )
                else
                  const SizedBox.shrink(),
                if (isStale)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.access_time, size: 11, color: AppColors.textHint),
                    const SizedBox(width: 3),
                    Text(
                      _timeAgo(l.updatedAt),
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textHint),
                    ),
                  ])
                else
                  Text(
                    _timeAgo(l.updatedAt),
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textHint),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ══ Empty state — matches Gram Awaaz pattern ═══════════════
  Widget _buildEmptyState() {
    final isBuy = _mode == TradeMode.buy;
    final isFiltered = _vendorFilterId != null;

    String hindiMsg;
    String englishHint;

    if (isFiltered) {
      String vendorName = 'Is vendor';
      for (final v in _vendors) {
        if (v['id'] == _vendorFilterId) {
          vendorName = (v['shop_name'] ?? v['full_name'] ?? 'Is vendor') as String;
          break;
        }
      }
      hindiMsg = '$vendorName ne abhi koi ${isBuy ? "rate" : "kharidari"} update nahi ki';
      englishHint = 'Doosra vendor try karein';
    } else if (isBuy) {
      hindiMsg = 'अभी कोई vendor ने rate update नहीं किया है';
      englishHint = 'Thodi der baad wapas dekhein';
    } else {
      hindiMsg = 'अभी कोई vendor फसल खरीद नहीं रहा है';
      englishHint = 'Phasal ke season mein wapas dekhein';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.storefront_outlined, size: 72, color: Colors.grey),
          const SizedBox(height: 14),
          Text(
            hindiMsg,
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSansDevanagari(
              color: AppColors.textSecondary, fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            englishHint,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.textHint, fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  String _fmtPrice(double p) =>
      p == p.truncate() ? p.toInt().toString() : p.toStringAsFixed(2);
}

// ══════════════════════════════════════════════════════════════
// MODE CHIP — Khareedein / Bechein
// Mirrors Gram Awaaz's _DeptChip exactly.
// ══════════════════════════════════════════════════════════════
class _ModeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _ModeChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 30,                                                       // ✅ fixed height
        padding: const EdgeInsets.symmetric(horizontal: 16),              // ✅ horizontal only
        alignment: Alignment.center,                                       // ✅ explicit center
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white24,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.notoSansDevanagari(
            color: isSelected ? AppColors.primary : Colors.white,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            height: 1.0,
          ).copyWith(
            leadingDistribution: TextLeadingDistribution.even,             // ✅ applied post-GoogleFonts
          ),
        ),
      ),
    );
  }
}

// ── Private helpers ─────────────────────────────────────────
enum _Freshness { fresh, neutral, stale }

class _ItemAggregate {
  final Item item;
  final VendorListing bestListing;
  final int vendorCount;
  const _ItemAggregate({
    required this.item,
    required this.bestListing,
    required this.vendorCount,
  });
}