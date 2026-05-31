// lib/features/mandi_prices/screens/item_detail_screen.dart
// ══════════════════════════════════════════════════════════════
// Item detail — vendor list for one item.
// Sorted: in-stock first → limited → out-of-stock.
// Within each tier, buy mode = cheapest first, sell mode = highest first.
// Tap-to-call per vendor row.
// ══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_service.dart';
import '../models/vendor_listing.dart';
import '../models/item.dart';

class ItemDetailScreen extends StatefulWidget {
  final Item item;
  final TradeMode mode;
  final String? vendorFilterId;

  const ItemDetailScreen({
    super.key,
    required this.item,
    required this.mode,
    this.vendorFilterId,
  });

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  bool _loading = true;
  List<VendorListing> _listings = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final apiMode = widget.mode == TradeMode.buy ? 'sell' : 'buy';
      final raw = await ApiService.getVendorListings(                   // ✅ single call now
        itemId: widget.item.id,
        mode: apiMode,
        vendorId: widget.vendorFilterId,
      );
      if (!mounted) return;

      final listings = raw.map((j) => VendorListing.fromJson(j)).toList();
      _sortListings(listings);

      setState(() {
        _listings = listings;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _sortListings(List<VendorListing> list) {
    int stockRank(StockStatus s) {
      switch (s) {
        case StockStatus.inStock:    return 0;
        case StockStatus.limited:    return 1;
        case StockStatus.outOfStock: return 2;
      }
    }

    list.sort((a, b) {
      final r = stockRank(a.stockStatus).compareTo(stockRank(b.stockStatus));
      if (r != 0) return r;
      // Within same stock tier, buy mode wants lowest, sell mode wants highest
      return widget.mode == TradeMode.buy
          ? a.price.compareTo(b.price)
          : b.price.compareTo(a.price);
    });
  }

  // ══ Helpers ════════════════════════════════════════════════
  _Freshness _freshnessOf(DateTime? dt) {
    if (dt == null) return _Freshness.stale;
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inHours < 24) return _Freshness.fresh;
    if (diff.inDays  < 7)  return _Freshness.neutral;
    return _Freshness.stale;
  }

  Color _priceColorOf(_Freshness f, bool oos) {
    if (oos) return AppColors.textHint;
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

  Future<void> _callVendor(VendorListing l) async {
    final phone = l.vendorPhone;                                        // ✅ direct from listing
    if (phone == null || phone.isEmpty) {
      _toast('Vendor ka phone number nahi mila');
      return;
    }
    try {
      final uri = Uri(scheme: 'tel', path: phone);
      await launchUrl(uri);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: phone));
      _toast('Number copied: $phone');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter()),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  String _fmtPrice(double p) =>
      p == p.truncate() ? p.toInt().toString() : p.toStringAsFixed(2);

  // ══ Build ══════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;
    final isSell = mode == TradeMode.sell;

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item.name,
              style: GoogleFonts.playfairDisplay(
                fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white,
              ),
            ),
            if (widget.item.nameHindi != null)
              Text(
                widget.item.nameHindi!,
                style: GoogleFonts.notoSansDevanagari(
                  fontSize: 12, color: Colors.white70,
                ),
              ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [

            // ══ Context bar ══════════════════════════════════
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: AppColors.cardBg,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSell ? AppColors.ctaLight : AppColors.primaryLight,
                      border: Border.all(
                        color: isSell ? AppColors.ctaBorder : AppColors.primaryBorder,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${mode.labelEn} · ${mode.labelHi}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSell ? AppColors.cta : AppColors.primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_listings.length} vendor${_listings.length == 1 ? "" : "s"}',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textHint),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: AppColors.border),

            // ══ Vendor list ══════════════════════════════════
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _listings.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(14),
                            itemCount: _listings.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) => _buildVendorCard(_listings[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ══ Vendor card ════════════════════════════════════════════
  Widget _buildVendorCard(VendorListing l) {
    final isOos = l.stockStatus == StockStatus.outOfStock;
    final freshness = _freshnessOf(l.updatedAt);
    final priceColor = _priceColorOf(freshness, isOos);
    final isStale = freshness == _Freshness.stale;

    return Opacity(
      opacity: isOos ? 0.78 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isOos ? const Color(0xFFF9FAFB) : AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // — Name + price ───────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    l.vendorName,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${_fmtPrice(l.price)}',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: priceColor,
                        decoration: isOos ? TextDecoration.lineThrough : null,
                        decorationThickness: 1.5,
                        height: 1.0,
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

            // — Notes (optional) ───────────────────────────
            if (l.notes != null && l.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                l.notes!,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],

            // — Bottom row: stock + time + call ────────────
            const SizedBox(height: 10),
            Container(height: 1, color: const Color(0xFFF3F4F6)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _stockPill(l.stockStatus, l.mode),
                      const SizedBox(height: 5),
                      isStale
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.access_time, size: 11, color: AppColors.textHint),
                                const SizedBox(width: 3),
                                Text(
                                  _timeAgo(l.updatedAt),
                                  style: GoogleFonts.inter(
                                    fontSize: 11, color: AppColors.textHint,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              _timeAgo(l.updatedAt),
                              style: GoogleFonts.inter(
                                fontSize: 11, color: AppColors.textHint,
                              ),
                            ),
                    ],
                  ),
                ),
                _callButton(l, isOos),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stockPill(StockStatus s, TradeMode mode) {
    Color bg, text, border;
    switch (s) {
      case StockStatus.inStock:
        bg = AppColors.primaryLight; text = AppColors.primary; border = AppColors.primaryBorder;
        break;
      case StockStatus.limited:
        bg = AppColors.ctaLight; text = AppColors.cta; border = AppColors.ctaBorder;
        break;
      case StockStatus.outOfStock:
        bg = const Color(0xFFFEE2E2); text = const Color(0xFF991B1B); border = const Color(0xFFFCA5A5);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Text(
        s.labelFor(mode),
        style: GoogleFonts.inter(
          fontSize: 10, fontWeight: FontWeight.w600, color: text,
        ),
      ),
    );
  }

  Widget _callButton(VendorListing l, bool isOos) {
    return GestureDetector(
      onTap: () => _callVendor(l),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isOos ? const Color(0xFFE5E7EB) : AppColors.primary,
          borderRadius: BorderRadius.circular(22),
          boxShadow: isOos ? null : [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.25),
              blurRadius: 6, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.phone_rounded, size: 14,
              color: isOos ? AppColors.textHint : Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              'Call',
              style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: isOos ? AppColors.textHint : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🛒', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 16),
            Text(
              'इस item ke liye abhi koi vendor active nahi hai',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansDevanagari(
                fontSize: 14, color: AppColors.textSecondary, height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Freshness { fresh, neutral, stale }