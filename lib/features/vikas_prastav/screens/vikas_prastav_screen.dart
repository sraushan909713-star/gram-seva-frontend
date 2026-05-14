// lib/features/vikas_prastav/screens/vikas_prastav_screen.dart
// ──────────────────────────────────────────────────────────────────
// Vikas Prastav — Development Proposals for Durbe village.
//
// Villagers propose development projects they want built.
// Upvotes = community mandate. More support = stronger case.
//
// Photos: picked from camera/gallery → uploaded to Cloudinary → URL sent to backend
// 1 photo mandatory, up to 3 optional (4 total)
//
// API methods used:
//   ApiService.getVikasPrastavPosts()    → GET  /vikas-prastav
//   ApiService.createVikasPrastavPost()  → POST /vikas-prastav
//   ApiService.upvoteVikasPrastav()      → POST /vikas-prastav/{id}/upvote
// ──────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_service.dart';
import '../../../core/network/cloudinary_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Category enum — must match backend ProposalCategory exactly ───
const List<Map<String, String>> _categories = [
  {'value': 'road',        'label': 'Roads & Paths',   'emoji': '🛣️'},
  {'value': 'water',       'label': 'Water Supply',    'emoji': '💧'},
  {'value': 'education',   'label': 'Education',       'emoji': '📚'},
  {'value': 'health',      'label': 'Health',          'emoji': '🏥'},
  {'value': 'electricity', 'label': 'Electricity',     'emoji': '⚡'},
  {'value': 'agriculture', 'label': 'Agriculture',     'emoji': '🌾'},
  {'value': 'other',       'label': 'Other',           'emoji': '📌'},
];

// ✅ Helper: label from value
String _catLabel(String value) {
  return _categories.firstWhere(
    (c) => c['value'] == value,
    orElse: () => {'label': value},
  )['label']!;
}

// ✅ Helper: emoji from value
String _catEmoji(String value) {
  return _categories.firstWhere(
    (c) => c['value'] == value,
    orElse: () => {'emoji': '📌'},
  )['emoji']!;
}

// ✅ Helper: color per category
Color _catColor(String cat) {
  switch (cat) {
    case 'road':        return const Color(0xFFFF9800);
    case 'water':       return const Color(0xFF00BCD4);
    case 'education':   return const Color(0xFF9C27B0);
    case 'health':      return const Color(0xFF4CAF50);
    case 'electricity': return const Color(0xFFFFC107);
    case 'agriculture': return const Color(0xFF8BC34A);
    default:            return AppColors.textSecondary;
  }
}


// ══════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ══════════════════════════════════════════════════════════════════
class VikasPrastavScreen extends StatefulWidget {
  const VikasPrastavScreen({super.key});

  @override
  State<VikasPrastavScreen> createState() => _VikasPrastavScreenState();
}

class _VikasPrastavScreenState extends State<VikasPrastavScreen> {

  // — State ──────────────────────────────────────────────────────
  List<dynamic> _proposals  = [];
  bool          _isLoading  = true;
  String?       _error;
  String?       _selectedCat;
  String? _userRole;
  String? _userBadge;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _fetchProposals();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() {
      _userRole  = prefs.getString('user_role');
      _userBadge = prefs.getString('badge');
    });
  }

  // ── GET /vikas-prastav ────────────────────────────────────────
  Future<void> _fetchProposals() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final proposals = await ApiService.getVikasPrastavPosts(
        category: _selectedCat,
      );
      setState(() { _proposals = proposals; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  // ── POST /vikas-prastav/{id}/upvote ──────────────────────────
  Future<void> _upvoteProposal(String proposalId) async {
    try {
      final result = await ApiService.upvoteVikasPrastav(proposalId);
      if (result['statusCode'] == 200) {
        // ✅ Update count locally — no full refetch needed
        setState(() {
          final i = _proposals.indexWhere((p) => p['id'] == proposalId);
          if (i != -1) {
            _proposals[i] = Map.from(_proposals[i])
              ..['upvote_count'] = result['upvote_count'];
          }
        });
        _snack('समर्थन दर्ज हुआ! 🙌', isSuccess: true);
      } else if (result['statusCode'] == 400) {
        _snack('आप पहले ही इस पर समर्थन कर चुके हैं।');
      } else if (result['statusCode'] == 401) {
        _snack('समर्थन देने के लिए पहले लॉगिन करें।');
      }
    } catch (_) {
      _snack('Network error. Check connection.');
    }
  }

  // — Helpers ───────────────────────────────────────────────────
  void _snack(String msg, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.notoSansDevanagari()),
      backgroundColor: isSuccess ? AppColors.primary : null,
      duration: const Duration(seconds: 2),
    ));
  }

  void _openCreateProposal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateProposalSheet(onProposalCreated: _fetchProposals),
    );
  }

// ✅ CHANGE: fetch full detail before opening sheet
  void _openDetail(dynamic proposal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProposalDetailSheet(
        proposalId:   proposal['id'],
        userBadge: _userBadge,
        proposalSnap: proposal,       // ✅ list data for instant display
        onUpvote: () => _upvoteProposal(proposal['id']),
        userRole:     _userRole,
        onDeleted:    _fetchProposals,
      ),
    );
  }

  // — Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Vikas Prastav',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w600, fontSize: 20, color: Colors.white)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchProposals),
        ],
      ),
      floatingActionButton: (_userBadge == 'durbe_niwasi' ||
              _userRole == 'admin' || _userRole == 'super_admin')
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              onPressed: _openCreateProposal,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text('नया प्रस्ताव',
                  style: GoogleFonts.notoSansDevanagari(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // — Tagline banner ─────────────────────────────────────
          Container(
            width: double.infinity,
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Text(
              'गांव की ज़रूरत — विकास के लिए प्रस्ताव दें',
              style: GoogleFonts.notoSansDevanagari(
                color: Colors.white70, fontSize: 13),
            ),
          ),

          // — Category filter chips ──────────────────────────────
          _buildFilterRow(),

          // — Proposal count ─────────────────────────────────────
          if (!_isLoading && _error == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(children: [
                Text('${_proposals.length} प्रस्ताव',
                  style: GoogleFonts.notoSansDevanagari(
                    fontSize: 13, color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500)),
                const SizedBox(width: 6),
                Text('• सबसे ज़्यादा समर्थन पहले',
                  style: GoogleFonts.notoSansDevanagari(
                    fontSize: 12, color: AppColors.textHint)),
              ]),
            ),

          // — Main content ───────────────────────────────────────
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                    ? _buildError()
                    : _proposals.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            onRefresh: _fetchProposals,
                            color: AppColors.primary,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                              itemCount: _proposals.length,
                              itemBuilder: (_, i) => _ProposalCard(
                                proposal: _proposals[i],
                                onTap: () => _openDetail(_proposals[i]),
                                onUpvote: () => _upvoteProposal(_proposals[i]['id']),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  // ── Category filter row ───────────────────────────────────────
  Widget _buildFilterRow() {
    return Container(
      height: 50,
      color: AppColors.primaryDark,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Center(child: _CatChip(
            label: 'All',
            isSelected: _selectedCat == null,
            onTap: () { setState(() => _selectedCat = null); _fetchProposals(); },
          )),
          const SizedBox(width: 8),
          ..._categories.map((c) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(child: _CatChip(
              label: '${c['emoji']} ${c['label']}',
              isSelected: _selectedCat == c['value'],
              onTap: () {
                setState(() => _selectedCat = c['value']);
                _fetchProposals();
              },
            )),
          )),
        ],
      ),
    );
  }

  Widget _buildError() => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
      const SizedBox(height: 12),
      Text(_error!, style: GoogleFonts.inter(color: AppColors.error)),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        onPressed: _fetchProposals,
        icon: const Icon(Icons.refresh),
        label: Text('फिर कोशिश करें', style: GoogleFonts.notoSansDevanagari()),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      ),
    ]),
  ));

  Widget _buildEmpty() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.construction_outlined, size: 72, color: Colors.grey),
      const SizedBox(height: 14),
      Text('कोई प्रस्ताव नहीं मिला',
        style: GoogleFonts.notoSansDevanagari(
          color: AppColors.textSecondary, fontSize: 16,
          fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      Text('पहला प्रस्ताव आप दें!',
        style: GoogleFonts.notoSansDevanagari(
          color: AppColors.textHint, fontSize: 13)),
    ],
  ));
}


// ══════════════════════════════════════════════════════════════════
// CATEGORY FILTER CHIP
// ══════════════════════════════════════════════════════════════════
class _CatChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _CatChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white24,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: GoogleFonts.inter(
          color: isSelected ? AppColors.primary : Colors.white,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        )),
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════════
// PROPOSAL CARD — list item
// ══════════════════════════════════════════════════════════════════
class _ProposalCard extends StatelessWidget {
  final dynamic proposal;
  final VoidCallback onTap;
  final VoidCallback onUpvote;
  const _ProposalCard({
    required this.proposal,
    required this.onTap,
    required this.onUpvote,
  });

  @override
  Widget build(BuildContext context) {
    final cat      = (proposal['category'] as String?) ?? 'other';
    final catColor = _catColor(cat);
    final upvotes  = proposal['upvote_count'] ?? 0;
    // ✅ Use photo_url_1 as primary card image
    final photoUrl = proposal['photo_url_1'] ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // — Photo ──────────────────────────────────────────────
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: photoUrl.isNotEmpty
                ? Image.network(photoUrl,
                    height: 170, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(cat))
                : _placeholder(cat),
          ),

          Padding(
            padding: const EdgeInsets.all(13),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // — Category badge + location ──────────────────────
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: catColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    '${_catEmoji(cat)} ${_catLabel(cat)}',
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.bold, color: catColor)),
                ),
                const Spacer(),
                Icon(Icons.location_on_outlined, size: 13, color: AppColors.textHint),
                const SizedBox(width: 2),
                Flexible(child: Text(proposal['location'] ?? '',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textHint),
                  overflow: TextOverflow.ellipsis)),
              ]),

              const SizedBox(height: 8),

              // — Title ──────────────────────────────────────────
              Text(proposal['title'] ?? '',
                style: GoogleFonts.notoSansDevanagari(
                  fontSize: 15, fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary, height: 1.3),
                maxLines: 2, overflow: TextOverflow.ellipsis),

              const SizedBox(height: 10),

              // — Upvote button ──────────────────────────────────
              Row(children: [
                Icon(Icons.people_alt_outlined, size: 14, color: AppColors.textHint),
                const SizedBox(width: 4),
                Text('समुदाय का प्रस्ताव',
                  style: GoogleFonts.notoSansDevanagari(
                    fontSize: 12, color: AppColors.textHint)),
                const Spacer(),
                GestureDetector(
                  onTap: onUpvote,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primaryBorder)),
                    child: Row(children: [
                      Icon(Icons.thumb_up_alt_outlined,
                        size: 14, color: AppColors.primary),
                      const SizedBox(width: 5),
                      Text('$upvotes', style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.bold,
                        color: AppColors.primary)),
                    ]),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _placeholder(String cat) => Container(
    height: 170, color: const Color(0xFFEEEEEE),
    child: Center(child: Text(_catEmoji(cat),
      style: const TextStyle(fontSize: 48))),
  );
}


// ══════════════════════════════════════════════════════════════════
// PROPOSAL DETAIL BOTTOM SHEET
// Shows all 4 photos in a horizontal swipeable gallery
// ══════════════════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════════
// PROPOSAL DETAIL BOTTOM SHEET
// ✅ CHANGE: now StatefulWidget — fetches full detail on open
// Shows description + estimated_cost + funding_source
// ══════════════════════════════════════════════════════════════════
class _ProposalDetailSheet extends StatefulWidget {
  final String   proposalId;
  final dynamic  proposalSnap;
  final VoidCallback onUpvote;
  final String?  userRole;
  final String? userBadge;
  final VoidCallback? onDeleted;
  const _ProposalDetailSheet({
    required this.proposalId,
    required this.proposalSnap,
    required this.onUpvote,
    this.userRole,
    this.userBadge,
    this.onDeleted,
  });
    @override
    State<_ProposalDetailSheet> createState() => _ProposalDetailSheetState();
}

class _ProposalDetailSheetState extends State<_ProposalDetailSheet> {
  Map<String, dynamic>? _fullProposal;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    try {
      final data = await ApiService.getVikasPrastavDetail(widget.proposalId);
      if (mounted) setState(() { _fullProposal = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() {
        _fullProposal = Map.from(widget.proposalSnap);
        _loading = false;
      });
    }
  }

  Future<void> _deleteProposal() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Proposal',
            style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.w700, color: Colors.red)),
        content: Text('Are you sure you want to delete this proposal?',
            style: GoogleFonts.inter(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.deleteVikasPrastavPost(widget.proposalId);
      if (mounted) {
        Navigator.pop(context);
        widget.onDeleted?.call();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Proposal deleted.', style: GoogleFonts.inter()),
          backgroundColor: AppColors.primary,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString(), style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final proposal  = _fullProposal ?? widget.proposalSnap;
    final cat       = (proposal['category'] as String?) ?? 'other';
    final catColor  = _catColor(cat);
    final upvotes   = proposal['upvote_count'] ?? 0;

    final photos = [
      proposal['photo_url_1'],
      proposal['photo_url_2'],
      proposal['photo_url_3'],
      proposal['photo_url_4'],
    ].whereType<String>().where((url) => url.isNotEmpty).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.87,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Spacer(),
              Container(width: 42, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              const Spacer(),
              if (widget.userRole == 'admin' || widget.userRole == 'super_admin')
                GestureDetector(
                  onTap: _deleteProposal,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.delete_outline_rounded,
                          size: 13, color: Colors.red),
                      const SizedBox(width: 4),
                      Text('Delete',
                          style: GoogleFonts.inter(
                              fontSize: 11, fontWeight: FontWeight.w600,
                              color: Colors.red)),
                    ]),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        Expanded(child: _loading
          ? SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (photos.isNotEmpty) _VPPhotoGallery(photos: photos),
                const SizedBox(height: 14),
                Text(proposal['title'] ?? '',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18, fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
                const SizedBox(height: 24),
                Center(child: CircularProgressIndicator(color: AppColors.primary)),
              ]),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                if (photos.isNotEmpty) _VPPhotoGallery(photos: photos),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: catColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20)),
                  child: Text('${_catEmoji(cat)} ${_catLabel(cat)}',
                    style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.bold, color: catColor)),
                ),
                const SizedBox(height: 10),

                Text(proposal['title'] ?? '',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18, fontWeight: FontWeight.w600,
                    height: 1.3, color: AppColors.textPrimary)),
                const SizedBox(height: 10),

                Row(children: [
                  Icon(Icons.location_on_outlined, size: 15, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Text(proposal['location'] ?? '',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                ]),

                const SizedBox(height: 12),
                // ✅ Poster identity + date
                _buildPosterRow(proposal),
                const SizedBox(height: 14),
                Divider(color: AppColors.border),
                const SizedBox(height: 10),

                // ✅ Description — now shows because we fetched full detail
                if (proposal['description'] != null &&
                    proposal['description'].toString().isNotEmpty) ...[
                  _buildSection(
                    icon: Icons.construction_outlined,
                    title: 'प्रस्ताव का विवरण',
                    content: proposal['description'],
                    color: AppColors.primary,
                  ),
                ],

                // ✅ Estimated cost
                if (proposal['estimated_cost'] != null &&
                    proposal['estimated_cost'].toString().isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF90CAF9))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.currency_rupee, size: 14, color: Color(0xFF1565C0)),
                        const SizedBox(width: 6),
                        Text('अनुमानित लागत', style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.bold,
                          color: const Color(0xFF1565C0))),
                      ]),
                      const SizedBox(height: 6),
                      Text(proposal['estimated_cost'], style: GoogleFonts.inter(
                        fontSize: 14, color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500)),
                    ]),
                  ),
                  const SizedBox(height: 10),
                ],

                // ✅ Funding source
                if (proposal['funding_source'] != null &&
                    proposal['funding_source'].toString().isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primaryBorder)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(Icons.account_balance_outlined,
                          size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text('संभावित फंडिंग', style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.bold,
                          color: AppColors.primary)),
                      ]),
                      const SizedBox(height: 6),
                      Text(proposal['funding_source'], style: GoogleFonts.inter(
                        fontSize: 14, color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500)),
                    ]),
                  ),
                  const SizedBox(height: 14),
                ],

                Row(children: [
                  Icon(Icons.thumb_up_alt, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text('$upvotes लोगों का समर्थन',
                    style: GoogleFonts.notoSansDevanagari(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
                ]),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (widget.userRole == 'admin' ||
                            widget.userRole == 'super_admin' ||
                            widget.userBadge == 'durbe_niwasi')
                        ? widget.onUpvote
                        : () => ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'केवल Durbe Niwasi ही समर्थन कर सकते हैं।',
                                  style: GoogleFonts.notoSansDevanagari()),
                              )),
                    icon: const Icon(Icons.thumb_up_alt, color: Colors.white),
                    label: Text('मैं भी समर्थन करता हूं',
                      style: GoogleFonts.notoSansDevanagari(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                  ),
                ),
              ]),
            ),
        ),
      ]),
    );
  }

  Widget _buildPosterRow(Map<String, dynamic> post) {
    final name  = post['poster_name'] ?? 'Durbe Niwasi';
    final photo = post['poster_photo'] as String?;
    final dateStr = post['created_at'] as String?;

    return Row(children: [
      CircleAvatar(
        radius: 16,
        backgroundColor: AppColors.primaryLight,
        backgroundImage: (photo != null && photo.isNotEmpty)
            ? NetworkImage(photo) : null,
        child: (photo == null || photo.isEmpty)
            ? Text(name[0].toUpperCase(),
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: AppColors.primary))
            : null,
      ),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name,
            style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        if (dateStr != null)
          Text(_formatDate(dateStr),
              style: GoogleFonts.inter(
                  fontSize: 11, color: AppColors.textHint)),
      ]),
    ]);
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso + 'Z').toLocal();
      const m = ['','Jan','Feb','Mar','Apr','May','Jun',
                  'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${m[dt.month]} ${dt.year}';
    } catch (_) { return ''; }
  }

  // ══════════════════════════════════════════════════════════════════
  // SECTION CARD — styled info box (same style as Schemes page)
  // ══════════════════════════════════════════════════════════════════
  Widget _buildSection({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(title, style: GoogleFonts.notoSansDevanagari(
            fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ]),
        const SizedBox(height: 8),
        Text(content, style: GoogleFonts.notoSansDevanagari(
          fontSize: 14, color: AppColors.textPrimary, height: 1.65)),
      ]),
    );
  }
}
class _VPPhotoGallery extends StatefulWidget {
  final List<String> photos;
  const _VPPhotoGallery({required this.photos});

  @override
  State<_VPPhotoGallery> createState() => _VPPhotoGalleryState();
}

class _VPPhotoGalleryState extends State<_VPPhotoGallery> {
  int _currentIndex = 0;
  final PageController _controller = PageController();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (_, i) => Image.network(
              widget.photos[i],
              fit: BoxFit.cover, width: double.infinity,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFFEEEEEE),
                child: const Icon(Icons.image_not_supported,
                  size: 48, color: Colors.grey)),
            ),
          ),
        ),
      ),
      if (widget.photos.length > 1) ...[
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.photos.length, (i) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: _currentIndex == i ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: _currentIndex == i ? AppColors.primary : AppColors.border,
              borderRadius: BorderRadius.circular(3)),
          )),
        ),
      ],
    ]);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}


// ══════════════════════════════════════════════════════════════════
// CREATE PROPOSAL BOTTOM SHEET
// ══════════════════════════════════════════════════════════════════
class _CreateProposalSheet extends StatefulWidget {
  final VoidCallback onProposalCreated;
  const _CreateProposalSheet({required this.onProposalCreated});

  @override
  State<_CreateProposalSheet> createState() => _CreateProposalSheetState();
}

class _CreateProposalSheetState extends State<_CreateProposalSheet> {

  // — Controllers ────────────────────────────────────────────────
  final _titleCtrl         = TextEditingController();
  final _descCtrl          = TextEditingController();
  final _locationCtrl      = TextEditingController();
  final _estimatedCostCtrl = TextEditingController();
  final _fundingSourceCtrl = TextEditingController();

  String?      _selectedCat;
  bool         _isSubmitting = false;
  bool         _isUploading  = false;

  // ✅ 4 photo slots — 1 mandatory, 3 optional
  final List<File?>   _photoFiles = [null, null, null, null];
  final List<String?> _photoUrls  = [null, null, null, null];
  final _picker = ImagePicker();

  // ── Pick photo from camera or gallery then upload to Cloudinary ─
  Future<void> _pickPhoto(int index) async {
    final choice = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          ListTile(
            leading: Icon(Icons.camera_alt, color: AppColors.primary),
            title: Text('Camera से लें', style: GoogleFonts.notoSansDevanagari()),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: Icon(Icons.photo_library, color: AppColors.primary),
            title: Text('Gallery से चुनें', style: GoogleFonts.notoSansDevanagari()),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );

    if (choice == null) return;

    final picked = await _picker.pickImage(
      source: choice,
      imageQuality: 75, // ✅ Compress for faster upload on slow connections
      maxWidth: 1200,
    );
    if (picked == null) return;

    setState(() => _isUploading = true);
    try {
      final url = await CloudinaryService.uploadImage(File(picked.path));
      setState(() {
        _photoFiles[index] = File(picked.path);
        _photoUrls[index]  = url;
        _isUploading       = false;
      });
      _snackInfo('फ़ोटो अपलोड हो गई ✅');
    } catch (e) {
      setState(() => _isUploading = false);
      _showError('फ़ोटो अपलोड नहीं हो सकी। फिर कोशिश करें।');
    }
  }

  // ── Submit ────────────────────────────────────────────────────
  Future<void> _submit() async {
    // ✅ First photo is mandatory
    if (_photoUrls[0] == null) {
      _showError('कम से कम एक फ़ोटो ज़रूरी है — जगह दिखाएं।');
      return;
    }
    if (_titleCtrl.text.trim().isEmpty    ||
        _descCtrl.text.trim().isEmpty     ||
        _locationCtrl.text.trim().isEmpty ||
        _selectedCat == null) {
      _showError('शीर्षक, विवरण, स्थान और श्रेणी ज़रूरी है।');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final result = await ApiService.createVikasPrastavPost(
        title:         _titleCtrl.text.trim(),
        description:   _descCtrl.text.trim(),
        location:      _locationCtrl.text.trim(),
        category:      _selectedCat!,
        photoUrl1:     _photoUrls[0]!,         // ✅ mandatory — Cloudinary URL
        photoUrl2:     _photoUrls[1],          // ✅ optional
        photoUrl3:     _photoUrls[2],          // ✅ optional
        photoUrl4:     _photoUrls[3],          // ✅ optional
        estimatedCost: _estimatedCostCtrl.text.trim().isEmpty
            ? null : _estimatedCostCtrl.text.trim(),
        fundingSource: _fundingSourceCtrl.text.trim().isEmpty
            ? null : _fundingSourceCtrl.text.trim(),
      );

      setState(() => _isSubmitting = false);

      if (result['statusCode'] == 201) {
        if (mounted) {
          Navigator.pop(context);
          widget.onProposalCreated();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('प्रस्ताव दर्ज हुआ! 🏗️',
              style: GoogleFonts.notoSansDevanagari()),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 3),
          ));
        }
      } else if (result['statusCode'] == 401) {
        _showError('प्रस्ताव देने के लिए पहले लॉगिन करें।');
      } else {
        _showError(result['detail'] ?? 'कुछ गड़बड़ हुई।');
      }
    } catch (_) {
      setState(() => _isSubmitting = false);
      _showError('Network error. Check connection.');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.notoSansDevanagari()),
      backgroundColor: AppColors.error,
      duration: const Duration(seconds: 3),
    ));
  }

  void _snackInfo(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 1),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.93,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [

        // — Handle + header ────────────────────────────────────
        const SizedBox(height: 12),
        Center(child: Container(width: 42, height: 4,
          decoration: BoxDecoration(
            color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Icon(Icons.add_chart, color: AppColors.cta, size: 22),
            const SizedBox(width: 10),
            Text('प्रस्ताव दें', style: GoogleFonts.playfairDisplay(
              fontSize: 18, fontWeight: FontWeight.w600,
              color: AppColors.primary)),
          ]),
        ),
        Divider(height: 1, color: AppColors.border),

        // — Form ───────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // — Photo picker section ───────────────────────────
              Text('फ़ोटो (Photos)',
                style: GoogleFonts.notoSansDevanagari(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text('पहली फ़ोटो अनिवार्य है — जगह दिखाएं',
                style: GoogleFonts.notoSansDevanagari(
                  fontSize: 12, color: AppColors.textHint)),
              const SizedBox(height: 10),

              // ✅ 4 photo slots in 2x2 grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.3,
                children: List.generate(4, (i) => _VPPhotoSlot(
                  index:       i,
                  file:        _photoFiles[i],
                  isUploading: _isUploading && _photoFiles[i] == null,
                  isMandatory: i == 0,
                  onTap:       () => _pickPhoto(i),
                  onRemove:    () => setState(() {
                    _photoFiles[i] = null;
                    _photoUrls[i]  = null;
                  }),
                )),
              ),

              const SizedBox(height: 16),

              _buildField('शीर्षक (Title) *',       _titleCtrl,    'प्रस्ताव का संक्षिप्त नाम'),
              _buildField('विवरण (Description) *',   _descCtrl,     'विस्तार से बताएं क्या बनना चाहिए', maxLines: 3),
              _buildField('स्थान (Location) *',      _locationCtrl, 'जैसे: दुर्बे गांव, मेन रोड'),
              _buildField('अनुमानित लागत',           _estimatedCostCtrl, 'जैसे: ₹2-3 लाख (वैकल्पिक)'),
              _buildField('संभावित फंडिंग',          _fundingSourceCtrl, 'जैसे: MGNREGA, 14th Finance (वैकल्पिक)'),

              // — Category dropdown ──────────────────────────────
              Text('श्रेणी (Category) *',
                style: GoogleFonts.notoSansDevanagari(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedCat,
                hint: Text('श्रेणी चुनें',
                  style: GoogleFonts.notoSansDevanagari(
                    fontSize: 13, color: AppColors.textHint)),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.border)),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12)),
                items: _categories.map((c) => DropdownMenuItem(
                  value: c['value'],
                  child: Text('${c['emoji']} ${c['label']}'))).toList(),
                onChanged: (v) => setState(() => _selectedCat = v),
              ),

              const SizedBox(height: 24),

              // — Submit button ──────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  // ✅ Disable during upload and submission
                  onPressed: (_isSubmitting || _isUploading) ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
                  child: (_isSubmitting || _isUploading)
                      ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const SizedBox(height: 20, width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)),
                          const SizedBox(width: 10),
                          Text(_isUploading
                              ? 'फ़ोटो अपलोड हो रही है...'
                              : 'दर्ज हो रहा है...',
                            style: GoogleFonts.notoSansDevanagari(
                              color: Colors.white)),
                        ])
                      : Text('प्रस्ताव जमा करें',
                          style: GoogleFonts.notoSansDevanagari(
                            color: Colors.white, fontSize: 16,
                            fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, String hint,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.notoSansDevanagari(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl, maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.notoSansDevanagari(
              color: AppColors.textHint, fontSize: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.border)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 12)),
        ),
      ]),
    );
  }

  @override
  void dispose() {
    // ✅ Always dispose controllers to prevent memory leaks
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _estimatedCostCtrl.dispose();
    _fundingSourceCtrl.dispose();
    super.dispose();
  }
}


// ══════════════════════════════════════════════════════════════════
// PHOTO SLOT — individual photo picker tile for Vikas Prastav
// ══════════════════════════════════════════════════════════════════
class _VPPhotoSlot extends StatelessWidget {
  final int      index;
  final File?    file;
  final bool     isUploading;
  final bool     isMandatory;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _VPPhotoSlot({
    required this.index,
    required this.file,
    required this.isUploading,
    required this.isMandatory,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: file == null ? onTap : null,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isMandatory && file == null
                ? AppColors.cta.withOpacity(0.5)
                : AppColors.border,
            width: isMandatory && file == null ? 1.5 : 1,
          ),
        ),
        child: isUploading
            ? Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2),
                  const SizedBox(height: 6),
                  Text('अपलोड हो रहा है...',
                    style: GoogleFonts.notoSansDevanagari(
                      fontSize: 10, color: AppColors.textHint)),
                ]))
            : file != null
                // ✅ Show picked photo with remove button
                ? Stack(fit: StackFit.expand, children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(file!, fit: BoxFit.cover)),
                    Positioned(top: 4, right: 4,
                      child: GestureDetector(
                        onTap: onRemove,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle),
                          padding: const EdgeInsets.all(3),
                          child: const Icon(Icons.close,
                            size: 14, color: Colors.white),
                        ),
                      )),
                  ])
                // ✅ Empty slot — tap to pick
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined,
                        size: 28,
                        color: isMandatory
                            ? AppColors.cta : AppColors.textHint),
                      const SizedBox(height: 4),
                      Text(
                        index == 0 ? 'फ़ोटो लें *' : 'फ़ोटो लें',
                        style: GoogleFonts.notoSansDevanagari(
                          fontSize: 11,
                          color: isMandatory
                              ? AppColors.cta : AppColors.textHint,
                          fontWeight: isMandatory
                              ? FontWeight.w600 : FontWeight.normal)),
                    ]),
      ),
    );
  }
}
