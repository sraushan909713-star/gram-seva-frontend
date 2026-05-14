// lib/features/guides/screens/guides_screen.dart
// ──────────────────────────────────────────────────────────────────
// Documentation Guides — step-by-step help for villagers to apply
// for government certificates and services.
//
// List screen:
//   - Category filter chips
//   - Guide cards with title, description, cost, time
//   - "Online" badge if guide has an online link
//
// Detail screen:
//   - Steps (numbered)
//   - Required documents
//   - Office info (name, address, timings, contact)
//   - Fees + estimated time
//   - Tips from Admin
//   - "Apply Online" button (only if online_link exists)
//
// API methods used:
//   ApiService.getGuides()      → GET /guides/
//   ApiService.getGuideDetail() → GET /guides/{id}
// ──────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Category config ─────────────────────────────────────────────
const List<Map<String, String>> _categories = [
  {'value': 'ration_card',        'label': 'Ration Card',        'emoji': '🛒'},
  {'value': 'birth_certificate',  'label': 'Birth Certificate',  'emoji': '👶'},
  {'value': 'caste_certificate',  'label': 'Caste Certificate',  'emoji': '📜'},
  {'value': 'income_certificate', 'label': 'Income Certificate', 'emoji': '💰'},
  {'value': 'aadhaar',            'label': 'Aadhaar',            'emoji': '🪪'},
  {'value': 'pension',            'label': 'Pension',            'emoji': '👴'},
  {'value': 'land_records',       'label': 'Land Records',       'emoji': '🏡'},
  {'value': 'health',             'label': 'Health',             'emoji': '🏥'},
  {'value': 'education',          'label': 'Education',          'emoji': '📚'},
  {'value': 'other',              'label': 'Other',              'emoji': '📌'},
];

String _catLabel(String value) => _categories
    .firstWhere((c) => c['value'] == value, orElse: () => {'label': value})['label']!;

String _catEmoji(String value) => _categories
    .firstWhere((c) => c['value'] == value, orElse: () => {'emoji': '📄'})['emoji']!;

Color _catColor(String cat) {
  switch (cat) {
    case 'ration_card':        return const Color(0xFF166534);
    case 'birth_certificate':  return const Color(0xFF1D4ED8);
    case 'caste_certificate':  return const Color(0xFF6B21A8);
    case 'income_certificate': return const Color(0xFF92400E);
    case 'aadhaar':            return const Color(0xFF9D174D);
    case 'pension':            return const Color(0xFF1E3A5F);
    case 'land_records':       return const Color(0xFF3B5E2B);
    case 'health':             return const Color(0xFFB91C1C);
    case 'education':          return const Color(0xFF1E40AF);
    default:                   return const Color(0xFF374151);
  }
}


// ══════════════════════════════════════════════════════════════════
// MAIN LIST SCREEN
// ══════════════════════════════════════════════════════════════════
class GuidesScreen extends StatefulWidget {
  const GuidesScreen({super.key});

  @override
  State<GuidesScreen> createState() => _GuidesScreenState();
}

class _GuidesScreenState extends State<GuidesScreen> {
  List<dynamic> _guides      = [];
  bool          _isLoading   = true;
  String?       _error;
  String?       _selectedCat;
  String?       _userRole;

  @override
  void initState() {
    super.initState();
    _fetchGuides();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _userRole = prefs.getString('user_role'));
  }

  Future<void> _fetchGuides() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final guides = await ApiService.getGuides(category: _selectedCat);
      if (mounted) setState(() { _guides = guides; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Documentation Guides',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w600, fontSize: 20, color: Colors.white)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchGuides),
        ],
      ),
      floatingActionButton: (_userRole == 'admin' || _userRole == 'super_admin')
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const _AddGuideScreen()),
              ).then((_) => _fetchGuides()),
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text('Add Guide', style: GoogleFonts.inter(
                  color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
      body: Column(
        children: [

          // ─── Tagline ────────────────────────────────────────
          Container(
            width: double.infinity,
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Text(
              'सरकारी काम — आसान तरीके से',
              style: GoogleFonts.notoSansDevanagari(
                color: Colors.white70, fontSize: 13),
            ),
          ),

          // ─── Category filter chips ───────────────────────────
          Container(
            height: 50,
            color: AppColors.primaryDark,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Center(child: _CatChip(
                  label: 'All',
                  isSelected: _selectedCat == null,
                  onTap: () { setState(() => _selectedCat = null); _fetchGuides(); },
                )),
                const SizedBox(width: 8),
                ..._categories.map((c) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Center(child: _CatChip(
                    label: '${c['emoji']} ${c['label']}',
                    isSelected: _selectedCat == c['value'],
                    onTap: () {
                      setState(() => _selectedCat = c['value']);
                      _fetchGuides();
                    },
                  )),
                )),
              ],
            ),
          ),

          // ─── Count ──────────────────────────────────────────
          if (!_isLoading && _error == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: [
                  Text('${_guides.length} guide${_guides.length == 1 ? '' : 's'}',
                    style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500)),
                ],
              ),
            ),

          // ─── List ────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                    ? _buildError()
                    : _guides.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            onRefresh: _fetchGuides,
                            color: AppColors.primary,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                              itemCount: _guides.length,
                              itemBuilder: (_, i) => _GuideCard(
                                guide: _guides[i],
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) =>
                                    _GuideDetailScreen(guideId: _guides[i]['id'])),
                                ),
                              ),
                            ),
                          ),
          ),
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
        onPressed: _fetchGuides,
        icon: const Icon(Icons.refresh),
        label: Text('Try again', style: GoogleFonts.inter()),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      ),
    ]),
  ));

  Widget _buildEmpty() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.menu_book_outlined, size: 72, color: Colors.grey),
      const SizedBox(height: 14),
      Text('No guides found',
        style: GoogleFonts.inter(
          color: AppColors.textSecondary, fontSize: 16,
          fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      Text('Try a different category',
        style: GoogleFonts.inter(color: AppColors.textHint, fontSize: 13)),
    ],
  ));
}


// ══════════════════════════════════════════════════════════════════
// CATEGORY CHIP
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
// GUIDE CARD — list item
// ══════════════════════════════════════════════════════════════════
class _GuideCard extends StatelessWidget {
  final dynamic guide;
  final VoidCallback onTap;
  const _GuideCard({required this.guide, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cat       = (guide['category'] as String?) ?? 'other';
    final catColor  = _catColor(cat);
    final hasOnline = guide['online_link'] != null &&
                      (guide['online_link'] as String).isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ─── Top row: category badge + online badge ────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: catColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20)),
                child: Text(
                  '${_catEmoji(cat)} ${_catLabel(cat)}',
                  style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w600,
                    color: catColor)),
              ),
              if (hasOnline)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(20)),
                  child: Text('🌐 Online available',
                    style: GoogleFonts.inter(
                      fontSize: 10, fontWeight: FontWeight.w600,
                      color: const Color(0xFF166534))),
                ),
            ],
          ),

          const SizedBox(height: 10),

          // ─── Title ────────────────────────────────────────
          Text(guide['title'] ?? '',
            style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)),

          if (guide['title_hindi'] != null) ...[
            const SizedBox(height: 2),
            Text(guide['title_hindi'],
              style: GoogleFonts.notoSansDevanagari(
                fontSize: 12, color: AppColors.textSecondary)),
          ],

          const SizedBox(height: 6),

          // ─── Description ──────────────────────────────────
          Text(guide['description'] ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12, color: AppColors.textSecondary, height: 1.4)),

          const SizedBox(height: 10),

          // ─── Bottom row: cost + time + arrow ─────────────
          Row(children: [
            if (guide['approximate_cost'] != null) ...[
              Icon(Icons.currency_rupee, size: 12, color: AppColors.textHint),
              const SizedBox(width: 2),
              Text(guide['approximate_cost'],
                style: GoogleFonts.inter(
                  fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(width: 12),
            ],
            if (guide['estimated_time'] != null) ...[
              Icon(Icons.schedule, size: 12, color: AppColors.textHint),
              const SizedBox(width: 2),
              Text(guide['estimated_time'],
                style: GoogleFonts.inter(
                  fontSize: 11, color: AppColors.textSecondary)),
            ],
            const Spacer(),
            Text('View guide',
              style: GoogleFonts.inter(
                fontSize: 11, color: AppColors.primary,
                fontWeight: FontWeight.w500)),
            const SizedBox(width: 2),
            Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.primary),
          ]),
        ]),
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════════
// GUIDE DETAIL SCREEN
// ══════════════════════════════════════════════════════════════════
class _GuideDetailScreen extends StatefulWidget {
  final String guideId;
  const _GuideDetailScreen({required this.guideId});

  @override
  State<_GuideDetailScreen> createState() => _GuideDetailScreenState();
}

class _GuideDetailScreenState extends State<_GuideDetailScreen> {
  Map<String, dynamic>? _guide;
  bool   _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    try {
      final guide = await ApiService.getGuideDetail(widget.guideId);
      if (mounted) setState(() { _guide = guide; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _launchOnlineLink() async {
    final link = _guide?['online_link'];
    if (link == null || link.toString().isEmpty) return;
    try {
      final uri = Uri.parse(link);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not open the link.'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_guide?['title'] ?? 'Guide Details',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(child: Text(_error!,
                  style: GoogleFonts.inter(color: AppColors.error)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ─── Header ──────────────────────────
                      _buildHeader(),
                      const SizedBox(height: 12),

                      // ─── Quick info row ───────────────────
                      _buildQuickInfo(),
                      const SizedBox(height: 12),

                      // ─── Required Documents ───────────────
                      if (_guide?['documents_needed'] != null &&
                          (_guide!['documents_needed'] as String).isNotEmpty)
                        _buildDocuments(),

                      // ─── Steps ────────────────────────────
                      _buildSteps(),

                      // ─── Office info ──────────────────────
                      if (_guide?['office_name'] != null)
                        _buildOfficeInfo(),

                      // ─── Tips from Admin ──────────────────
                      if (_guide?['tips'] != null &&
                          (_guide!['tips'] as String).isNotEmpty)
                        _buildTips(),

                      // ─── Apply Online button ──────────────
                      if (_guide?['online_link'] != null &&
                          (_guide!['online_link'] as String).isNotEmpty) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _launchOnlineLink,
                            icon: const Icon(Icons.open_in_new,
                                color: Colors.white, size: 18),
                            label: Text('Apply Online',
                              style: GoogleFonts.inter(
                                color: Colors.white, fontSize: 15,
                                fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.cta,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  // ─── Header card ─────────────────────────────────────────────
  Widget _buildHeader() {
    final cat      = (_guide?['category'] as String?) ?? 'other';
    final catColor = _catColor(cat);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: catColor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: catColor.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(_catEmoji(cat), style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_guide?['title'] ?? '',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
              if (_guide?['title_hindi'] != null)
                Text(_guide!['title_hindi'],
                  style: GoogleFonts.notoSansDevanagari(
                    fontSize: 13, color: catColor)),
            ],
          )),
        ]),
        const SizedBox(height: 10),
        Text(_guide?['description'] ?? '',
          style: GoogleFonts.inter(
            fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
      ]),
    );
  }

  // ─── Quick info pills: cost + time ───────────────────────────
  Widget _buildQuickInfo() {
    final cost = _guide?['approximate_cost'];
    final time = _guide?['estimated_time'];
    if (cost == null && time == null) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: [
      if (cost != null)
        _infoPill('💰 $cost', const Color(0xFF92400E), const Color(0xFFFEF3C7)),
      if (time != null)
        _infoPill('⏱️ $time', const Color(0xFF1D4ED8), const Color(0xFFEFF6FF)),
    ]);
  }

  Widget _infoPill(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: GoogleFonts.inter(
        fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
    );
  }

  // ─── Required documents ───────────────────────────────────────
  Widget _buildDocuments() {
    final raw = (_guide!['documents_needed'] as String);
    // Split by newline or comma
    final docs = raw.contains('\n')
        ? raw.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
        : raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    return _sectionCard(
      icon: Icons.folder_outlined,
      title: 'Documents Required',
      color: const Color(0xFF6B21A8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: docs.map((doc) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('• ', style: GoogleFonts.inter(
              color: const Color(0xFF6B21A8), fontWeight: FontWeight.w700)),
            Expanded(child: Text(doc, style: GoogleFonts.inter(
              fontSize: 13, color: AppColors.textPrimary))),
          ]),
        )).toList(),
      ),
    );
  }

  // ─── Steps ───────────────────────────────────────────────────
  Widget _buildSteps() {
    final raw = (_guide?['steps'] as String?) ?? '';
    final lines = raw.split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return _sectionCard(
      icon: Icons.format_list_numbered,
      title: 'Steps to Follow',
      color: AppColors.primary,
      child: Column(
        children: lines.asMap().entries.map((entry) {
          // Remove existing numbering if present (e.g. "1. ...")
          String text = entry.value.replaceFirst(RegExp(r'^\d+[\.\)]\s*'), '');
          int num = entry.key + 1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text('$num',
                  style: GoogleFonts.inter(
                    color: Colors.white, fontSize: 11,
                    fontWeight: FontWeight.w700))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.textPrimary, height: 1.5))),
            ]),
          );
        }).toList(),
      ),
    );
  }

  // ─── Office info ──────────────────────────────────────────────
  Widget _buildOfficeInfo() {
    return _sectionCard(
      icon: Icons.location_city_outlined,
      title: 'Where to Go',
      color: const Color(0xFF1E3A5F),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_guide?['office_name'] != null)
          _officeRow(Icons.business_outlined, _guide!['office_name']),
        if (_guide?['office_address'] != null)
          _officeRow(Icons.location_on_outlined, _guide!['office_address']),
        if (_guide?['timings'] != null)
          _officeRow(Icons.schedule_outlined, _guide!['timings']),
        if (_guide?['contact_person'] != null)
          _officeRow(Icons.person_outlined, _guide!['contact_person']),
      ]),
    );
  }

  Widget _officeRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 15, color: const Color(0xFF1E3A5F)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: GoogleFonts.inter(
          fontSize: 13, color: AppColors.textPrimary))),
      ]),
    );
  }

  // ─── Tips ─────────────────────────────────────────────────────
  Widget _buildTips() {
    return _sectionCard(
      icon: Icons.lightbulb_outline,
      title: 'Admin Tips',
      color: const Color(0xFF92400E),
      child: Text(_guide!['tips'],
        style: GoogleFonts.inter(
          fontSize: 13, color: AppColors.textPrimary, height: 1.6)),
    );
  }

  // ─── Section card wrapper ─────────────────────────────────────
  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Color color,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(title, style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ]),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }
}

class _AddGuideScreen extends StatefulWidget {
  const _AddGuideScreen({super.key});
  @override
  State<_AddGuideScreen> createState() => _AddGuideScreenState();
}

class _AddGuideScreenState extends State<_AddGuideScreen> {
  final _titleCtrl    = TextEditingController();
  final _descCtrl     = TextEditingController();
  final _stepsCtrl    = TextEditingController();
  final _docsCtrl     = TextEditingController();
  final _officeCtrl   = TextEditingController();
  final _addressCtrl  = TextEditingController();
  final _feesCtrl     = TextEditingController();
  final _daysCtrl     = TextEditingController();
  final _linkCtrl     = TextEditingController();
  final _tipsCtrl     = TextEditingController();
  String _category = 'other';
  bool   _saving   = false;

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Title is required.', style: GoogleFonts.inter()),
        backgroundColor: Colors.red));
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiService.createGuide({
        'title':              _titleCtrl.text.trim(),
        'description':        _descCtrl.text.trim().isEmpty
            ? 'No description provided.' : _descCtrl.text.trim(),
        'category':           _category,
        'steps':              _stepsCtrl.text.trim().isEmpty
            ? 'No steps provided.' : _stepsCtrl.text.trim(),
        'documents_needed':   _docsCtrl.text.trim().isEmpty
            ? null : _docsCtrl.text.trim(),
        'office_name':        _officeCtrl.text.trim().isEmpty
            ? null : _officeCtrl.text.trim(),
        'office_address':     _addressCtrl.text.trim().isEmpty
            ? null : _addressCtrl.text.trim(),
        'approximate_cost':   _feesCtrl.text.trim().isEmpty
            ? null : _feesCtrl.text.trim(),
        'estimated_time':     _daysCtrl.text.trim().isEmpty
            ? null : '${_daysCtrl.text.trim()} days',
        'online_link':        _linkCtrl.text.trim().isEmpty
            ? null : _linkCtrl.text.trim(),
        'tips':               _tipsCtrl.text.trim().isEmpty
            ? null : _tipsCtrl.text.trim(),
        'village_id':         '1',
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Guide added!', style: GoogleFonts.inter()),
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
        title: Text('Add Guide', style: GoogleFonts.playfairDisplay(
            fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _lbl('Title *'), _field(_titleCtrl, 'e.g. How to get Birth Certificate'),
          _lbl('Description'), _field(_descCtrl, 'Brief overview', maxLines: 2),
          _lbl('Category'),
          _drop(value: _category,
            items: ['ration_card','birth_certificate','caste_certificate','income_certificate',
                    'aadhaar','pension','land_records','health','education','other'],
            labels: {'ration_card':'🛒 Ration Card','birth_certificate':'👶 Birth Certificate',
              'caste_certificate':'📜 Caste Certificate','income_certificate':'💰 Income Certificate',
              'aadhaar':'🪪 Aadhaar','pension':'👴 Pension','land_records':'🏡 Land Records',
              'health':'🏥 Health','education':'📚 Education','other':'📌 Other'},
            onChanged: (v) => setState(() => _category = v!)),
          _lbl('Steps (one per line)'), _field(_stepsCtrl, 'Step 1: Go to...\nStep 2: Fill form...', maxLines: 5),
          _lbl('Documents Required'), _field(_docsCtrl, 'Aadhaar, Photo...', maxLines: 2),
          _lbl('Office Name'), _field(_officeCtrl, 'e.g. Block Development Office'),
          _lbl('Office Address'), _field(_addressCtrl, 'e.g. Gaya, Bihar'),
          _lbl('Fees (₹)'), _field(_feesCtrl, 'e.g. Free / ₹50'),
          _lbl('Estimated Days'), _field(_daysCtrl, 'e.g. 7', keyboardType: TextInputType.number),
          _lbl('Online Link (optional)'), _field(_linkCtrl, 'https://...'),
          _lbl('Tips from Admin'), _field(_tipsCtrl, 'Any helpful advice', maxLines: 2),
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
                  : Text('Save Guide', style: GoogleFonts.inter(
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

  Widget _field(TextEditingController c, String hint,
      {int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        keyboardType: maxLines > 1 ? TextInputType.multiline : keyboardType,
        textInputAction: maxLines > 1
            ? TextInputAction.newline
            : TextInputAction.next,
        style: GoogleFonts.inter(fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: AppColors.textHint, fontSize: 13),
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
              borderSide: const BorderSide(color: AppColors.primary)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

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
