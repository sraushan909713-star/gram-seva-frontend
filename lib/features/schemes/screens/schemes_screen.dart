// lib/features/schemes/screens/schemes_screen.dart
// ──────────────────────────────────────────────────────────────────
// Government Schemes — list and detail view for Durbe village.
//
// Villagers can browse and search all active government schemes.
// Tapping a scheme shows full detail: eligibility, how to apply, link.
// No login required — reading is public.
//
// Categories: health, farming, education, housing, finance, women, other
//
// API methods used:
//   ApiService.getSchemes()       → GET /schemes (list, filter, search)
//   ApiService.getSchemeDetail()  → GET /schemes/{id} (full detail)
// ──────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'my_scheme_screen.dart';
import 'my_scheme_screen.dart' show MySchemeScreen;



// ── Category enum — must match backend SchemeCategory exactly ─────
const List<Map<String, String>> _categories = [
  {'value': 'health',    'label': 'Health',     'emoji': '🏥'},
  {'value': 'farming',   'label': 'Farming',    'emoji': '🌾'},
  {'value': 'education', 'label': 'Education',  'emoji': '📚'},
  {'value': 'housing',   'label': 'Housing',    'emoji': '🏠'},
  {'value': 'finance',   'label': 'Finance',    'emoji': '💰'},
  {'value': 'women',     'label': 'Women',      'emoji': '👩'},
  {'value': 'other',     'label': 'Other',      'emoji': '📌'},
];

String _catLabel(String value) {
  return _categories.firstWhere(
    (c) => c['value'] == value,
    orElse: () => {'label': value},
  )['label']!;
}

String _catEmoji(String value) {
  return _categories.firstWhere(
    (c) => c['value'] == value,
    orElse: () => {'emoji': '📌'},
  )['emoji']!;
}

Color _catColor(String cat) {
  switch (cat) {
    case 'health':    return const Color(0xFF4CAF50);
    case 'farming':   return const Color(0xFF8BC34A);
    case 'education': return const Color(0xFF9C27B0);
    case 'housing':   return const Color(0xFFFF9800);
    case 'finance':   return const Color(0xFF2196F3);
    case 'women':     return const Color(0xFFE91E63);
    default:          return AppColors.textSecondary;
  }
}


// ══════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ══════════════════════════════════════════════════════════════════
class SchemesScreen extends StatefulWidget {
  const SchemesScreen({super.key});

  @override
  State<SchemesScreen> createState() => _SchemesScreenState();
}

class _SchemesScreenState extends State<SchemesScreen> {

  // — State ──────────────────────────────────────────────────────
  List<dynamic> _schemes      = [];
  bool          _isLoading    = true;
  String?       _error;
  String?       _selectedCat; // null = all categories
  final         _searchCtrl   = TextEditingController();
  bool          _showSearch   = false;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _fetchSchemes();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _userRole = prefs.getString('user_role'));
  }

  // ── GET /schemes ──────────────────────────────────────────────
  Future<void> _fetchSchemes() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final schemes = await ApiService.getSchemes(
        category: _selectedCat,
        search: _searchCtrl.text.trim().isEmpty
            ? null : _searchCtrl.text.trim(),
      );
      setState(() { _schemes = schemes; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  void _openDetail(dynamic scheme) async {                                        // ✅ CHANGE — async now
    final wasDeleted = await Navigator.of(context).push<bool>(                    // ✅ CHANGE — await result
      MaterialPageRoute(builder: (_) => _SchemeDetailScreen(schemeId: scheme['id'])),
    );
    if (wasDeleted == true) _fetchSchemes();                                      // ✅ ADD — refresh on delete
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Schemes',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w600, fontSize: 20, color: Colors.white)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // ✅ Search toggle button
          IconButton(
            icon: Icon(_showSearch ? Icons.search_off : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchCtrl.clear();
                  _fetchSchemes();
                }
              });
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchSchemes),
        ],
      ),
      floatingActionButton: (_userRole == 'admin' || _userRole == 'super_admin')
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const _AddSchemeScreen()),
              ).then((_) => _fetchSchemes()),
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text('Add Scheme', style: GoogleFonts.inter(
                  color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // — Tagline banner ─────────────────────────────────────
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => MySchemeScreen())),
            child: Container(
              width: double.infinity,
              color: AppColors.primary,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'जानें और उठाएं लाभ सरकारी योजनाओं का',
                    style: GoogleFonts.notoSansDevanagari(
                      color: Colors.white70, fontSize: 13),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('🌐', style: TextStyle(fontSize: 10)),
                      const SizedBox(width: 3),
                      Text('myscheme.gov.in',
                        style: GoogleFonts.inter(
                          fontSize: 10, color: Colors.white)),
                    ]),
                  ),
                ],
              ),
            ),
          ),

          // — Search bar (shown when search icon tapped) ─────────
          if (_showSearch)
            Container(
              color: AppColors.primaryDark,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'योजना खोजें...',
                  hintStyle: GoogleFonts.notoSansDevanagari(
                    color: Colors.white54, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54),
                          onPressed: () {
                            _searchCtrl.clear();
                            _fetchSchemes();
                          })
                      : null,
                  filled: true,
                  fillColor: Colors.white12,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onSubmitted: (_) => _fetchSchemes(),
                onChanged: (v) {
                  setState(() {});
                  if (v.isEmpty) _fetchSchemes();
                },
              ),
            ),

          // — Category filter chips ──────────────────────────────
          _buildFilterRow(),

          // — Scheme count ───────────────────────────────────────
          if (!_isLoading && _error == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Text('${_schemes.length} योजनाएं',
                style: GoogleFonts.notoSansDevanagari(
                  fontSize: 13, color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
            ),

          // — Main content ───────────────────────────────────────
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                    ? _buildError()
                    : _schemes.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            onRefresh: _fetchSchemes,
                            color: AppColors.primary,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                              itemCount: _schemes.length,
                              itemBuilder: (_, i) => _SchemeCard(
                                scheme: _schemes[i],
                                onTap: () => _openDetail(_schemes[i]),
                              ),
                            ),
                          )
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return Container(
      color: AppColors.primaryDark,
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Center(child: _CatChip(
            label: 'All',
            isSelected: _selectedCat == null,
            onTap: () { setState(() => _selectedCat = null); _fetchSchemes(); },
          )),
          const SizedBox(width: 8),
          ..._categories.map((c) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(child: _CatChip(
              label: '${c['emoji']} ${c['label']}',
              isSelected: _selectedCat == c['value'],
              onTap: () {
                setState(() => _selectedCat = c['value']);
                _fetchSchemes();
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
        onPressed: _fetchSchemes,
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
      const Icon(Icons.list_alt_outlined, size: 72, color: Colors.grey),
      const SizedBox(height: 14),
      Text('कोई योजना नहीं मिली',
        style: GoogleFonts.notoSansDevanagari(
          color: AppColors.textSecondary, fontSize: 16,
          fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      Text('फ़िल्टर बदलकर देखें',
        style: GoogleFonts.notoSansDevanagari(
          color: AppColors.textHint, fontSize: 13)),
    ],
  ));

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
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
// SCHEME CARD — list item
// Uses SchemeListResponse: id, name, description, category, is_active
// ══════════════════════════════════════════════════════════════════
class _SchemeCard extends StatelessWidget {
  final dynamic scheme;
  final VoidCallback onTap;
  const _SchemeCard({required this.scheme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cat      = (scheme['category'] as String?) ?? 'other';
    final catColor = _catColor(cat);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: catColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: catColor.withOpacity(0.25)),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // — Category emoji circle ──────────────────────────────
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: catColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(_catEmoji(cat),
                style: const TextStyle(fontSize: 22)),
            ),
          ),

          const SizedBox(width: 12),

          // — Scheme info ────────────────────────────────────────
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Category badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: catColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20)),
                child: Text(
                  _catLabel(cat),
                  style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.bold, color: catColor)),
              ),

              const SizedBox(height: 6),

              // Scheme name
              Text(scheme['name'] ?? '',
                style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),

              const SizedBox(height: 4),

              // Description (2 lines max)
              Text(scheme['description'] ?? '',
                style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.textSecondary,
                  height: 1.4),
                maxLines: 2, overflow: TextOverflow.ellipsis),

              const SizedBox(height: 8),

              // "View details" hint
              Row(children: [
                Text('विवरण देखें',
                  style: GoogleFonts.notoSansDevanagari(
                    fontSize: 11, color: AppColors.primary,
                    fontWeight: FontWeight.w500)),
                const SizedBox(width: 2),
                Icon(Icons.arrow_forward_ios,
                  size: 10, color: AppColors.primary),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════════
// SCHEME DETAIL SCREEN
// Full screen (not bottom sheet) — lots of text content
// Fetches full detail: eligibility, how_to_apply, official_link
// ══════════════════════════════════════════════════════════════════
class _SchemeDetailScreen extends StatefulWidget {
  final String schemeId;
  const _SchemeDetailScreen({required this.schemeId});

  @override
  State<_SchemeDetailScreen> createState() => _SchemeDetailScreenState();
}

class _SchemeDetailScreenState extends State<_SchemeDetailScreen> {
  Map<String, dynamic>? _scheme;
  bool _isLoading = true;
  String? _error;
  List<dynamic> _members    = [];
  bool          _membersLoading = true;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
    _fetchMembers();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _userRole = prefs.getString('user_role'));
  }

  Future<void> _fetchDetail() async {
    try {
      final scheme = await ApiService.getSchemeDetail(widget.schemeId);
      setState(() { _scheme = scheme; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  // ✅ ADD: fetch members who are availing this scheme
  Future<void> _fetchMembers() async {
    try {
      final members = await ApiService.getSchemeMembers(widget.schemeId);
      if (mounted) setState(() { _members = members; _membersLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _membersLoading = false);
    }
  }

  Future<void> _showAddMemberDialog() async {
    final nameCtrl     = TextEditingController();
    final relNameCtrl  = TextEditingController();
    String gender      = 'male';

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Text('Add Beneficiary',
              style: GoogleFonts.playfairDisplay(
                  fontWeight: FontWeight.w700)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nameCtrl,
              style: GoogleFonts.inter(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Full name',
                hintStyle: GoogleFonts.inter(color: AppColors.textHint),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: relNameCtrl,
              style: GoogleFonts.inter(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Father / Husband name',
                hintStyle: GoogleFonts.inter(color: AppColors.textHint),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Text('Gender:', style: GoogleFonts.inter(fontSize: 13)),
              const SizedBox(width: 12),
              ChoiceChip(
                label: Text('Male', style: GoogleFonts.inter(fontSize: 12)),
                selected: gender == 'male',
                selectedColor: AppColors.primaryLight,
                onSelected: (_) => setS(() => gender = 'male'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text('Female', style: GoogleFonts.inter(fontSize: 12)),
                selected: gender == 'female',
                selectedColor: const Color(0xFFFCE4EC),
                onSelected: (_) => setS(() => gender = 'female'),
              ),
            ]),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: GoogleFonts.inter(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(context);
                try {
                  await ApiService.addSchemeMember(widget.schemeId, {
                    'name':          nameCtrl.text.trim(),
                    'relative_name': relNameCtrl.text.trim().isEmpty
                        ? null : relNameCtrl.text.trim(),
                    'gender':        gender,
                  });
                  _fetchMembers();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Member added!',
                          style: GoogleFonts.inter()),
                      backgroundColor: AppColors.primary,
                    ));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(e.toString(),
                          style: GoogleFonts.inter()),
                      backgroundColor: Colors.red,
                    ));
                  }
                }
              },
              child: Text('Add',
                  style: GoogleFonts.inter(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Open URL with normalization + fallback ─────────────────────────────────  // ✅ ADD
  // Handles three common failure modes seen in the wild:
  //   1. URL stored without scheme (e.g. "myscheme.gov.in/...") → prepend https://
  //   2. Android 11+ queries restriction → skip canLaunchUrl, try launchUrl directly
  //   3. Any unexpected exception → show readable snackbar instead of silent fail
  Future<void> _openExternalUrl(String? raw) async {
    if (raw == null || raw.trim().isEmpty) return;
    var clean = raw.trim();
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      clean = 'https://$clean';
    }
    final uri = Uri.tryParse(clean);
    if (uri == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('लिंक अमान्य है (Invalid link)',
              style: GoogleFonts.notoSansDevanagari()),
          backgroundColor: AppColors.error,
        ));
      }
      return;
    }
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('लिंक नहीं खुल सका: $clean',
              style: GoogleFonts.notoSansDevanagari()),
          backgroundColor: AppColors.error,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('लिंक खोलने में त्रुटि: $e',
              style: GoogleFonts.notoSansDevanagari()),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  // ─── Delete Scheme ──────────────────────────────────────────────────────────  // ✅ ADD
  // Any admin or super_admin can delete (matches GOLDEN RULE).
  // Backend soft-deletes (is_active=False).
  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Scheme?',
            style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.w700, color: Colors.red)),
        content: Text(
          'This will hide "${_scheme?['name'] ?? 'this scheme'}" from villagers. '
          'The data is preserved on the server but no one will see it.',
          style: GoogleFonts.inter(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ApiService.deleteScheme(widget.schemeId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Scheme deleted.', style: GoogleFonts.inter()),
          backgroundColor: Colors.orange,
        ));
        Navigator.pop(context, true);  // tell parent to refresh
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
    final cat = (_scheme?['category'] as String?) ?? 'other';
    final catColor = _catColor(cat);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Schemes',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w600, fontSize: 20, color: Colors.white)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [                                                                  // ✅ ADD
          if (_userRole == 'admin' || _userRole == 'super_admin')                   // ✅ ADD
            IconButton(                                                             // ✅ ADD
              icon: const Icon(Icons.delete_outline_rounded),                       // ✅ ADD
              tooltip: 'Delete scheme',                                             // ✅ ADD
              onPressed: _confirmDelete,                                            // ✅ ADD
            ),                                                                      // ✅ ADD
        ],                                                                          // ✅ ADD
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: AppColors.error)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                    // — Header card ──────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: catColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: catColor.withOpacity(0.2))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text(_catEmoji(cat), style: const TextStyle(fontSize: 28)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_scheme?['name'] ?? '',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 16, fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary))),
                        ]),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: catColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20)),
                          child: Text(_catLabel(cat),
                            style: GoogleFonts.inter(
                              fontSize: 11, fontWeight: FontWeight.bold,
                              color: catColor)),
                        ),
                      ]),
                    ),

                    const SizedBox(height: 16),

                    // — Description ──────────────────────────────
                    _buildSection(
                      icon: Icons.info_outline,
                      title: 'योजना के बारे में',
                      content: _scheme?['description'] ?? '',
                      color: AppColors.primary,
                    ),

                    // — Eligibility ──────────────────────────────
                    _buildSection(
                      icon: Icons.verified_user_outlined,
                      title: 'पात्रता (Eligibility)',
                      content: _scheme?['eligibility'] ?? '',
                      color: const Color(0xFF2196F3),
                    ),

                    // — How to apply ─────────────────────────────
                    _buildSection(
                      icon: Icons.assignment_outlined,
                      title: 'आवेदन कैसे करें (How to Apply)',
                      content: _scheme?['how_to_apply'] ?? '',
                      color: const Color(0xFF9C27B0),
                    ),

                    // — Documents required ──────────────────────             // ✅ ADD
                    _buildSection(                                             // ✅ ADD
                      icon: Icons.folder_outlined,                             // ✅ ADD
                      title: 'आवश्यक दस्तावेज़ (Documents Required)',           // ✅ ADD
                      content: _scheme?['documents_required'] ?? '',            // ✅ ADD
                      color: const Color(0xFF00897B),                          // ✅ ADD
                    ),                                                         // ✅ ADD

                    // — Additional info (if present) ─────────────
                    if (_scheme?['additional_info'] != null &&
                        (_scheme!['additional_info'] as String).isNotEmpty)
                      _buildSection(
                        icon: Icons.lightbulb_outline,
                        title: 'अतिरिक्त जानकारी',
                        content: _scheme!['additional_info'],
                        color: const Color(0xFFFF9800),
                      ),

                    // — Official link button (if present) ─────────
                    if (_scheme?['official_link'] != null &&
                        (_scheme!['official_link'] as String).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>                      
                            _openExternalUrl(_scheme?['official_link'] as String?),
                          icon: const Icon(Icons.link, color: Colors.white),
                          label: Text('सरकारी वेबसाइट खोलें',
                            style: GoogleFonts.notoSansDevanagari(
                              color: Colors.white, fontWeight: FontWeight.w500)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                        ),
                      ),
                    ],

                    // — YouTube guide button (if present) ─────────         // ✅ ADD
                    if (_scheme?['youtube_link'] != null &&                  // ✅ ADD
                        (_scheme!['youtube_link'] as String).isNotEmpty) ...[ // ✅ ADD
                      const SizedBox(height: 8),                             // ✅ ADD
                      SizedBox(                                              // ✅ ADD
                        width: double.infinity,                              // ✅ ADD
                        child: ElevatedButton.icon(                          // ✅ ADD
                          onPressed: () =>                                   // ✅ ADD
                            _openExternalUrl(_scheme?['youtube_link'] as String?), // ✅ ADD
                          icon: const Icon(Icons.play_circle_outline,        // ✅ ADD
                            color: Colors.white),                            // ✅ ADD
                          label: Text('YouTube गाइड देखें',                  // ✅ ADD
                            style: GoogleFonts.notoSansDevanagari(           // ✅ ADD
                              color: Colors.white, fontWeight: FontWeight.w500)), // ✅ ADD
                          style: ElevatedButton.styleFrom(                   // ✅ ADD
                            backgroundColor: const Color(0xFFCC0000),        // ✅ ADD — YouTube red
                            padding: const EdgeInsets.symmetric(vertical: 14), // ✅ ADD
                            shape: RoundedRectangleBorder(                   // ✅ ADD
                              borderRadius: BorderRadius.circular(10))),     // ✅ ADD
                        ),                                                   // ✅ ADD
                      ),                                                     // ✅ ADD
                    ],                                                       // ✅ ADD

                    // — Availing Members section ─────────────────
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Icon(Icons.people_alt_outlined,
                            size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text('इस योजना से लाभान्वित लोग',
                            style: GoogleFonts.notoSansDevanagari(
                              fontSize: 13, fontWeight: FontWeight.bold,
                              color: AppColors.primary)),
                          const Spacer(),
                          Text('${_members.length}',
                            style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.bold,
                              color: AppColors.primary)),
                          if (_userRole == 'admin' || _userRole == 'super_admin') ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _showAddMemberDialog,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min,
                                    children: [
                                  const Icon(Icons.add, size: 12,
                                      color: Colors.white),
                                  const SizedBox(width: 3),
                                  Text('Add',
                                      style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white)),
                                ]),
                              ),
                            ),
                          ],
                        ]),
                        const SizedBox(height: 12),

                        // ✅ Members list
                        if (_membersLoading)
                          Center(child: CircularProgressIndicator(
                            color: AppColors.primary, strokeWidth: 2))
                        else if (_members.isEmpty)
                          Center(child: Text('अभी कोई नहीं जुड़ा',
                            style: GoogleFonts.notoSansDevanagari(
                              color: AppColors.textHint, fontSize: 13)))
                        else
                          ..._members.map((m) => _MemberTile(member: m)),
                      ]),
                    ),
                    const SizedBox(height: 24),
                  ]),
                ),
    );
  }

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
        color: color.withOpacity(0.07),        // ✅ CHANGE — was AppColors.cardBg
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25))),  // ✅ CHANGE — was AppColors.border
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

// ══════════════════════════════════════════════════════════════════
// MEMBER TILE — shows one person availing a scheme
// ══════════════════════════════════════════════════════════════════
class _MemberTile extends StatelessWidget {
  final dynamic member;
  
  const _MemberTile({required this.member});

  @override
  Widget build(BuildContext context) {
    final gender   = member['gender'] ?? 'male';
    final isFemale = gender == 'female';
    final sinceDate = member['since_date'] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        // ✅ Profile photo or gender icon
        CircleAvatar(
          radius: 20,
          backgroundColor: isFemale
              ? const Color(0xFFFCE4EC)
              : const Color(0xFFE3F2FD),
          backgroundImage: member['photo_url'] != null
              ? NetworkImage(member['photo_url']) : null,
          child: member['photo_url'] == null
              ? Text(isFemale ? '👩' : '👨',
                  style: const TextStyle(fontSize: 18))
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(member['name'] ?? '',
              style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
            Text(
              '${isFemale ? 'पति' : 'पिता'}: ${member['relative_name'] ?? ''}',
              style: GoogleFonts.notoSansDevanagari(
                fontSize: 11, color: AppColors.textSecondary)),
          ]),
        ),
        // ✅ Since date
        Text(sinceDate,
          style: GoogleFonts.inter(
            fontSize: 11, color: AppColors.textHint)),
      ]),
    );
  }
}

class _AddSchemeScreen extends StatefulWidget {
  const _AddSchemeScreen({super.key});
  @override
  State<_AddSchemeScreen> createState() => _AddSchemeScreenState();
}

class _AddSchemeScreenState extends State<_AddSchemeScreen> {
  final _titleCtrl       = TextEditingController();
  final _descCtrl        = TextEditingController();
  final _eligCtrl        = TextEditingController();
  final _howCtrl         = TextEditingController();
  final _benefitsCtrl    = TextEditingController();
  final _docsCtrl        = TextEditingController();
  final _youtubeLinkCtrl = TextEditingController();
  final _applyLinkCtrl   = TextEditingController();
  String _category = 'other';
  bool   _saving   = false;

  Future<void> _save() async {
    // ─── Validate mandatory fields (must match backend SchemeCreate) ───   // ✅ CHANGE
    final missing = <String>[];                                             // ✅ ADD
    if (_titleCtrl.text.trim().isEmpty) missing.add('Title');               // ✅ ADD
    if (_descCtrl.text.trim().isEmpty)  missing.add('Description');         // ✅ ADD
    if (_eligCtrl.text.trim().isEmpty)  missing.add('Eligibility');         // ✅ ADD
    if (_howCtrl.text.trim().isEmpty)   missing.add('How to Apply');        // ✅ ADD
    if (_docsCtrl.text.trim().isEmpty) missing.add('Documents Required');   // ✅ ADD
    if (missing.isNotEmpty) {                                               // ✅ ADD
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(                  // ✅ ADD
        content: Text('Please fill: ${missing.join(', ')}',                 // ✅ ADD
            style: GoogleFonts.inter()),                                    // ✅ ADD
        backgroundColor: Colors.red));                                      // ✅ ADD
      return;                                                               // ✅ ADD
    }                                                                       // ✅ ADD

    setState(() => _saving = true);
    try {
      await ApiService.createScheme({
        'name':            _titleCtrl.text.trim(),
        'description':     _descCtrl.text.trim(),                           // ✅ CHANGE — mandatory, no fallback
        'category':        _category,
        'eligibility':     _eligCtrl.text.trim(),                           // ✅ CHANGE — mandatory, no fallback
        'how_to_apply':    _howCtrl.text.trim(),                            // ✅ CHANGE — mandatory, no fallback
        'documents_required': _docsCtrl.text.trim(),                        // ✅ ADD — mandatory
        'official_link':   _applyLinkCtrl.text.trim().isEmpty
            ? null : _applyLinkCtrl.text.trim(),
        'youtube_link':    _youtubeLinkCtrl.text.trim().isEmpty             // ✅ ADD — this is what was missing!
            ? null : _youtubeLinkCtrl.text.trim(),                          // ✅ ADD
        'additional_info': _benefitsCtrl.text.trim().isEmpty
            ? null : _benefitsCtrl.text.trim(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Scheme added!', style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFF166534)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString(), style: GoogleFonts.inter()),
          backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
            onPressed: () => Navigator.pop(context)),
        title: Text('Add Scheme', style: GoogleFonts.playfairDisplay(
            fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _lbl('Title *'), _field(_titleCtrl, 'e.g. Vriddha Pension Yojna'),
          _lbl('Description *'), _field(_descCtrl, 'What is this scheme about?', maxLines: 3),  // ✅ CHANGE
          _lbl('Category'),
          _drop(value: _category,
            items: ['health','farming','education','housing','finance','women','other'],
            labels: {'health':'🏥 Health','farming':'🌾 Farming','education':'📚 Education',
              'housing':'🏠 Housing','finance':'💰 Finance','women':'👩 Women','other':'📌 Other'},
            onChanged: (v) => setState(() => _category = v!)),
          _lbl('Eligibility *'), _field(_eligCtrl, 'Who can apply?', maxLines: 2),     // ✅ CHANGE
          _lbl('How to Apply *'), _field(_howCtrl, 'Steps to apply', maxLines: 3),     // ✅ CHANGE
          _lbl('Benefits'), _field(_benefitsCtrl, 'What will they get?', maxLines: 2),
          _lbl('Documents Required *'), _field(_docsCtrl, 'Aadhaar, Ration Card... (or type "No documents required")', maxLines: 2),  // ✅ CHANGE
          _lbl('YouTube Guide Link (optional)'), _field(_youtubeLinkCtrl, 'https://youtube.com/...'),
          _lbl('Apply Online Link (optional)'), _field(_applyLinkCtrl, 'https://...'),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Save Scheme', style: GoogleFonts.inter(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            )),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  Widget _lbl(String t) => Padding(padding: const EdgeInsets.only(bottom: 6, top: 4),
    child: Text(t, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600,
        color: AppColors.textPrimary)));

  Widget _field(TextEditingController c, String hint, {int maxLines = 1}) =>
      Padding(padding: const EdgeInsets.only(bottom: 14),
        child: TextField(controller: c, maxLines: maxLines,
          style: GoogleFonts.inter(fontSize: 13),
          decoration: InputDecoration(hintText: hint,
            hintStyle: GoogleFonts.inter(color: AppColors.textHint, fontSize: 13),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary)),
            filled: true, fillColor: Colors.white)));

  Widget _drop({required String value, required List<String> items,
      required Map<String,String> labels, required void Function(String?) onChanged}) =>
      Padding(padding: const EdgeInsets.only(bottom: 14),
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12)),
          child: DropdownButtonHideUnderline(child: DropdownButton<String>(
            value: value, isExpanded: true,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
            items: items.map((v) => DropdownMenuItem(value: v,
                child: Text(labels[v] ?? v))).toList(),
            onChanged: onChanged))));
}
