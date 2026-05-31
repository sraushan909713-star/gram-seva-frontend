// lib/features/mandi_prices/screens/my_listings_screen.dart
// ══════════════════════════════════════════════════════════════
// Vendor's own listings — management screen.
// Tap a card → opens EditListingScreen pre-filled.
// FAB → AddListingScreen.
// ══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_service.dart';
import '../models/vendor_listing.dart';
import 'add_listing_screen.dart';
import 'edit_listing_screen.dart';

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  bool _loading = true;
  List<VendorListing> _listings = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final json = await ApiService.getMyListings();
      if (!mounted) return;
      setState(() {
        _listings = json.map((j) => VendorListing.fromJson(j)).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _addNew() async {
    final ok = await Navigator.push<bool>(context,
      MaterialPageRoute(builder: (_) => const AddListingScreen()));
    if (ok == true) {
      _load();
      _snack('Listing add ho gayi', isSuccess: true);
    }
  }

  Future<void> _edit(VendorListing l) async {
    final ok = await Navigator.push<bool>(context,
      MaterialPageRoute(builder: (_) => EditListingScreen(listing: l)));
    if (ok == true) _load();
  }

  void _snack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter()),
      backgroundColor: isSuccess ? AppColors.primary : null,
    ));
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

  String _fmtPrice(double p) =>
    p == p.truncate() ? p.toInt().toString() : p.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('My Listings',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w600, fontSize: 20, color: Colors.white)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: _addNew,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Naya Listing',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Text('अपने उत्पादों को यहां अपडेट करें ताकि खरीदारों को सही जानकारी मिले',
              style: GoogleFonts.notoSansDevanagari(color: Colors.white70, fontSize: 13)),
          ),
          if (!_loading)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Text('${_listings.length} listings',
                style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
            ),
          Expanded(
            child: _loading
              ? Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _listings.isEmpty
                ? _buildEmpty()
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                      itemCount: _listings.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _buildCard(_listings[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(VendorListing l) {
    final isSell = l.mode == TradeMode.sell;
    final isOos = l.stockStatus == StockStatus.outOfStock;

    return GestureDetector(
      onTap: () => _edit(l),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('₹${_fmtPrice(l.price)}',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary, height: 1.0)),
                  const SizedBox(height: 3),
                  Text('per ${l.unitName ?? ""}',
                    style: GoogleFonts.inter(fontSize: 10, color: AppColors.textHint)),
                ]),
              ],
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: const Color(0xFFF3F4F6)),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              // Mode badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: isSell ? AppColors.ctaLight : AppColors.primaryLight,
                  border: Border.all(color: isSell ? AppColors.ctaBorder : AppColors.primaryBorder),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${l.mode.labelEn} · ${l.mode.labelHi}',
                  style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w600,
                    color: isSell ? AppColors.cta : AppColors.primary)),
              ),
              // Stock pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: isOos
                    ? const Color(0xFFFEE2E2)
                    : (l.stockStatus == StockStatus.limited ? AppColors.ctaLight : AppColors.primaryLight),
                  border: Border.all(color: isOos
                    ? const Color(0xFFFCA5A5)
                    : (l.stockStatus == StockStatus.limited ? AppColors.ctaBorder : AppColors.primaryBorder)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(l.stockStatus.labelFor(l.mode),
                  style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w600,
                    color: isOos ? const Color(0xFF991B1B)
                      : (l.stockStatus == StockStatus.limited ? AppColors.cta : AppColors.primary))),
              ),
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.access_time, size: 11, color: AppColors.textHint),
                const SizedBox(width: 3),
                Text(_timeAgo(l.updatedAt),
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textHint)),
              ]),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Tap to edit',
                  style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.primary,
                    fontWeight: FontWeight.w500)),
                const SizedBox(width: 3),
                Icon(Icons.edit_outlined, size: 12, color: AppColors.primary),
              ]),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.inventory_2_outlined, size: 72, color: Colors.grey),
        const SizedBox(height: 14),
        Text('Aapne abhi koi listing nahi banayi',
          style: GoogleFonts.inter(
            color: AppColors.textSecondary, fontSize: 16,
            fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Text('Niche se "Naya Listing" tap karein',
          style: GoogleFonts.inter(color: AppColors.textHint, fontSize: 13)),
      ],
    ));
  }
}