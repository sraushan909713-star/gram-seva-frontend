// ─────────────────────────────────────────────────────────────────────────────
// FILE — lib/features/profile/screens/admin_panel_screen.dart  ✅ NEW
//
// Admin-only screen. Accessible from Profile screen.
// Sections:
//   1. Pending Verifications — photo + name only (no phone for privacy)
//      Approve / Revoke buttons
//   2. Community Members — all active users, name + role + badge only
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_service.dart';

// ─── Admin Panel Screen ───────────────────────────────────────────────────────
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {

  // ─── State ──────────────────────────────────────────────────────────────────
  List<dynamic> _pending  = [];
  List<dynamic> _members  = [];
  bool _loadingPending    = true;
  bool _loadingMembers    = true;
  String? _pendingError;
  String? _membersError;
  
  // ─── Window management state (super_admin only) ──────────────────────────────
  Map<String, dynamic>? _window;
  bool    _loadingWindow = true;
  String? _windowError;
  String? _userRole;
  String? _userId;                                                              // ✅ ADD

  // ─── Create window form controllers ──────────────────────────────────────────
  final _windowLabelCtrl = TextEditingController();
  DateTime? _windowOpensAt;
  DateTime? _windowClosesAt;

  // ─── Banner state (super_admin only) ─────────────────────────────────────────
  List<dynamic> _banners       = [];
  bool          _loadingBanners = true;

  // ─── Banner form controllers ──────────────────────────────────────────────────
  final _bannerTitleCtrl    = TextEditingController();
  final _bannerSubtitleCtrl = TextEditingController();
  final _bannerIconCtrl     = TextEditingController();
  final _bannerTagCtrl      = TextEditingController();
  final _bannerUrlCtrl      = TextEditingController();
  String  _bannerColorTheme  = 'green';
  String  _bannerRedirectType= 'none';
  String  _bannerRedirectTarget = 'gram_awaaz';
  DateTime? _bannerValidUntil;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadPending();
    _loadMembers();
    _loadWindow();
    _loadBanners();
  }

  // ─── Load Pending Verifications ──────────────────────────────────────────────
  Future<void> _loadPending() async {
    setState(() { _loadingPending = true; _pendingError = null; });
    try {
      final data = await ApiService.getPendingVerifications();
      if (mounted) setState(() { _pending = data; _loadingPending = false; });
    } catch (e) {
      if (mounted) setState(() { _pendingError = e.toString(); _loadingPending = false; });
    }
  }

  // ─── Load Community Members ──────────────────────────────────────────────────
  Future<void> _loadMembers() async {
    setState(() { _loadingMembers = true; _membersError = null; });
    try {
      final data = await ApiService.getCommunityMembers();
      if (mounted) setState(() { _members = data; _loadingMembers = false; });
    } catch (e) {
      if (mounted) setState(() { _membersError = e.toString(); _loadingMembers = false; });
    }
  }

  // ─── Load current user info from prefs ───────────────────────────────────────
  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() {
      _userRole = prefs.getString('user_role');
      _userId   = prefs.getString('user_id');                                    // ✅ ADD
    });
  }

  // ─── Load current rating window ──────────────────────────────────────────────
  Future<void> _loadWindow() async {
    setState(() { _loadingWindow = true; _windowError = null; });
    try {
      final data = await ApiService.getNetaWindowStatus();
      // ✅ If hidden, treat as no active window
      if (mounted) setState(() {
        _window = (data['is_hidden'] == true) ? null : data;
        _loadingWindow = false;
      });
    } catch (e) {
      if (mounted) setState(() { _window = null; _loadingWindow = false; });
    }
  }

  // ─── Create new rating window ────────────────────────────────────────────────
  Future<void> _createWindow() async {
    if (_windowLabelCtrl.text.trim().isEmpty ||
        _windowOpensAt == null || _windowClosesAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please fill label, open date and close date.',
            style: GoogleFonts.inter()),
        backgroundColor: Colors.red,
      ));
      return;
    }
    if (_windowClosesAt!.isBefore(_windowOpensAt!)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Close date must be after open date.',
            style: GoogleFonts.inter()),
        backgroundColor: Colors.red,
      ));
      return;
    }
    try {
      await ApiService.createRatingWindow(
        label:     _windowLabelCtrl.text.trim(),
        opensAt:   _windowOpensAt!,
        closesAt:  _windowClosesAt!,
      );
      _windowLabelCtrl.clear();
      setState(() { _windowOpensAt = null; _windowClosesAt = null; });
      await _loadWindow();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Rating window created!', style: GoogleFonts.inter()),
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

  // ─── Hide current window ─────────────────────────────────────────────────────
  Future<void> _hideWindow() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Close Rating Window',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700)),
        content: Text(
          'This will immediately stop all voting. Are you sure?',
          style: GoogleFonts.inter(fontSize: 13),
        ),
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
            child: Text('Close Window',
                style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.hideRatingWindow();
      await _loadWindow();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Rating window closed.', style: GoogleFonts.inter()),
          backgroundColor: Colors.orange,
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

  // ─── Unhide current window ───────────────────────────────────────────────────
  Future<void> _unhideWindow(String windowId) async {
    try {
      await ApiService.unhideRatingWindow(windowId);
      await _loadWindow();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Rating window reopened!', style: GoogleFonts.inter()),
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

  // ─── Approve User ────────────────────────────────────────────────────────────
  Future<void> _approveUser(String userId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Approve Residency',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700)),
        content: Text(
          'Confirm that $name is a verified resident of Durbe village?',
          style: GoogleFonts.inter(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Approve', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ApiService.approveUser(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$name approved as Durbe Niwasi!', style: GoogleFonts.inter()),
          backgroundColor: AppColors.primary,
        ));
        _loadPending();
        _loadMembers();
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

  // ─── Revoke User ─────────────────────────────────────────────────────────────
  Future<void> _revokeUser(String userId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Revoke Badge',
            style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.w700, color: Colors.red)),
        content: Text(
          'Remove the Durbe Niwasi badge from $name?',
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
            child: Text('Revoke', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ApiService.revokeUser(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$name\'s badge has been revoked.', style: GoogleFonts.inter()),
          backgroundColor: Colors.orange,
        ));
        _loadPending();
        _loadMembers();
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

  // ─── Change user role — super_admin only ─────────────────────────────────────
  Future<void> _changeRole(String userId, String name, String currentRole) async {
    final roles = ['user', 'admin', 'vendor'];
    final labels = {'user': 'User', 'admin': 'Admin', 'vendor': 'Vendor'};

    final selected = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Change Role — $name',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: roles.map((r) => RadioListTile<String>(
            value: r,
            groupValue: currentRole,
            title: Text(labels[r]!, style: GoogleFonts.inter(fontSize: 13)),
            activeColor: AppColors.primary,
            onChanged: (v) => Navigator.pop(context, v),
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
        ],
      ),
    );

    if (selected == null || selected == currentRole) return;

    try {
      await ApiService.changeUserRole(userId, selected);
      await _loadMembers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$name is now ${labels[selected]}.',
              style: GoogleFonts.inter()),
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

  // ─── Load banners ─────────────────────────────────────────────────────────────
  Future<void> _loadBanners() async {
    setState(() => _loadingBanners = true);
    try {
      final data = await ApiService.getBanners();
      if (mounted) setState(() { _banners = data; _loadingBanners = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingBanners = false);
    }
  }

  // ─── Create banner ────────────────────────────────────────────────────────────
  Future<void> _createBanner() async {
    if (_bannerTitleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Title is required.', style: GoogleFonts.inter()),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final colorMap = {
      'green':  {'start': '#166534', 'end': '#1e8a4a'},
      'blue':   {'start': '#1e40af', 'end': '#2563eb'},
      'purple': {'start': '#6d28d9', 'end': '#7c3aed'},
      'orange': {'start': '#c2440a', 'end': '#ea580c'},
      'pink':   {'start': '#be185d', 'end': '#db2777'},
      'dark':   {'start': '#1f2937', 'end': '#374151'},
    };

    final colors = colorMap[_bannerColorTheme]!;

    try {
      await ApiService.createBanner({
        'title':          _bannerTitleCtrl.text.trim(),
        'subtitle':       _bannerSubtitleCtrl.text.trim().isEmpty
            ? null : _bannerSubtitleCtrl.text.trim(),
        'icon':           _bannerIconCtrl.text.trim().isEmpty
            ? null : _bannerIconCtrl.text.trim(),
        'tag':            _bannerTagCtrl.text.trim().isEmpty
            ? null : _bannerTagCtrl.text.trim(),
        'bg_color_start': colors['start'],
        'bg_color_end':   colors['end'],
        'redirect_type':  _bannerRedirectType == 'none' ? null : _bannerRedirectType,
        'redirect_target': _bannerRedirectType == 'none'
            ? null
            : _bannerRedirectType == 'internal'
                ? _bannerRedirectTarget
                : _bannerUrlCtrl.text.trim(),
        'valid_until':    _bannerValidUntil?.toIso8601String(),
        'display_order':  0,
        'village_id':     '1',
      });
      _bannerTitleCtrl.clear();
      _bannerSubtitleCtrl.clear();
      _bannerIconCtrl.clear();
      _bannerTagCtrl.clear();
      _bannerUrlCtrl.clear();
      setState(() {
        _bannerColorTheme   = 'green';
        _bannerRedirectType = 'none';
        _bannerValidUntil   = null;
      });
      await _loadBanners();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Banner added!', style: GoogleFonts.inter()),
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

  // ─── Delete banner ────────────────────────────────────────────────────────────
  Future<void> _deleteBanner(String bannerId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Banner',
            style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.w700, color: Colors.red)),
        content: Text('Remove "$title" banner?',
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
      await ApiService.deleteBanner(bannerId);
      await _loadBanners();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Banner deleted.', style: GoogleFonts.inter()),
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

  // ─── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0FDF4),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: AppColors.primary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Admin Panel',
            style: GoogleFonts.playfairDisplay(
                fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: () { _loadPending(); _loadMembers(); _loadWindow(); _loadBanners(); },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Pending Verifications ───────────────────────────────────────
            _sectionHeader(
              icon: '⏳',
              title: 'Pending Verifications',
              count: _pending.length,
              countColor: Colors.red,
            ),
            const SizedBox(height: 10),
            _buildPendingSection(),

            const SizedBox(height: 20),

            // ── Community Members ───────────────────────────────────────────
            _sectionHeader(
              icon: '👥',
              title: 'Community Members',
              count: _members.length,
              countColor: AppColors.primary,
            ),
            const SizedBox(height: 10),
            _buildMembersSection(),

            if (_userRole == 'super_admin') ...[
              const SizedBox(height: 20),
              _sectionHeader(
                icon: '🗓️',
                title: 'Rating Window',
                count: _window != null ? 1 : 0,
                countColor: const Color(0xFF7C3AED),
              ),
              const SizedBox(height: 10),
              _buildWindowSection(),
            ],
            // ── Banners — super_admin only ──────────────────────────────────
            if (_userRole == 'super_admin') ...[
              const SizedBox(height: 20),
              _sectionHeader(
                icon: '🖼️',
                title: 'Home Banners',
                count: _banners.length,
                countColor: const Color(0xFFBE185D),
              ),
              const SizedBox(height: 10),
              _buildBannerSection(),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ─── Banner Section ───────────────────────────────────────────────────────────
  Widget _buildBannerSection() {
    final colorOptions = [
      {'value': 'green',  'label': '🟢 Green (Brand)'},
      {'value': 'blue',   'label': '🔵 Blue (Info)'},
      {'value': 'purple', 'label': '🟣 Purple (Event)'},
      {'value': 'orange', 'label': '🟠 Orange (Alert)'},
      {'value': 'pink',   'label': '🌸 Pink (Festival)'},
      {'value': 'dark',   'label': '⚫ Dark (Announcement)'},
    ];

    final internalScreens = [
      {'value': 'gram_awaaz',      'label': 'Gram Awaaz'},
      {'value': 'job_alerts',      'label': 'Job Alerts'},
      {'value': 'schemes',         'label': 'Schemes'},
      {'value': 'vikas_prastav',   'label': 'Vikas Prastav'},
      {'value': 'neta_report_card','label': 'Neta Report Card'},
      {'value': 'guides',          'label': 'Guides'},
      {'value': 'contacts',        'label': 'Contacts'},
      {'value': 'mandi_prices',    'label': 'Crop Prices'},
      {'value': 'rain_alerts',     'label': 'Rain Alerts'},
    ];

    return Column(children: [

      // ── Existing banners list ─────────────────────────────────────────────
      if (_loadingBanners)
        const Center(child: CircularProgressIndicator(color: AppColors.primary))
      else if (_banners.isEmpty)
        _emptyCard('No banners yet', 'Add one using the form below.')
      else
        Column(
          children: _banners.map((b) {
            final title = b['title'] ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                Text(b['icon'] ?? '🖼️',
                    style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: const Color(0xFF111827))),
                    if (b['subtitle'] != null)
                      Text(b['subtitle'],
                          style: GoogleFonts.inter(
                              fontSize: 11, color: const Color(0xFF6B7280))),
                  ],
                )),
                GestureDetector(
                  onTap: () => _deleteBanner(b['id'], title),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Text('Delete',
                        style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: Colors.red)),
                  ),
                ),
              ]),
            );
          }).toList(),
        ),

      const SizedBox(height: 14),

      // ── Add banner form ───────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Add Banner',
              style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: const Color(0xFF374151))),
          const SizedBox(height: 12),

          // Title
          _bannerField(_bannerTitleCtrl, 'Title * e.g. Holi Milan Samaroh'),
          // Subtitle
          _bannerField(_bannerSubtitleCtrl, 'Subtitle (optional)'),
          // Icon
          _bannerField(_bannerIconCtrl, 'Icon emoji e.g. 🎉 💼 🌾'),
          // Tag
          _bannerField(_bannerTagCtrl, 'Tag e.g. Event, Job Alert, Notice'),

          // Color theme
          const SizedBox(height: 4),
          Text('Colour Theme',
              style: GoogleFonts.inter(fontSize: 11,
                  color: const Color(0xFF6B7280))),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _bannerColorTheme,
                isExpanded: true,
                style: GoogleFonts.inter(
                    fontSize: 12, color: const Color(0xFF374151)),
                items: colorOptions.map((c) => DropdownMenuItem(
                  value: c['value'],
                  child: Text(c['label']!),
                )).toList(),
                onChanged: (v) => setState(() => _bannerColorTheme = v!),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Redirect type
          Text('Tap Action',
              style: GoogleFonts.inter(fontSize: 11,
                  color: const Color(0xFF6B7280))),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _bannerRedirectType,
                isExpanded: true,
                style: GoogleFonts.inter(
                    fontSize: 12, color: const Color(0xFF374151)),
                items: const [
                  DropdownMenuItem(value: 'none',     child: Text('No action')),
                  DropdownMenuItem(value: 'internal', child: Text('Go to a screen')),
                  DropdownMenuItem(value: 'external', child: Text('Open a website')),
                ],
                onChanged: (v) => setState(() => _bannerRedirectType = v!),
              ),
            ),
          ),

          // Internal screen picker
          if (_bannerRedirectType == 'internal') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _bannerRedirectTarget,
                  isExpanded: true,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: const Color(0xFF374151)),
                  items: internalScreens.map((s) => DropdownMenuItem(
                    value: s['value'],
                    child: Text(s['label']!),
                  )).toList(),
                  onChanged: (v) =>
                      setState(() => _bannerRedirectTarget = v!),
                ),
              ),
            ),
          ],

          // External URL
          if (_bannerRedirectType == 'external') ...[
            const SizedBox(height: 8),
            _bannerField(_bannerUrlCtrl, 'https://...'),
          ],

          const SizedBox(height: 10),

          // Expiry date
          GestureDetector(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 7)),
                firstDate: DateTime.now(),
                lastDate: DateTime(2030),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: const ColorScheme.light(
                        primary: AppColors.primary),
                  ),
                  child: child!,
                ),
              );
              if (d != null) setState(() => _bannerValidUntil = d);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  _bannerValidUntil != null
                      ? 'Expires: ${_bannerValidUntil!.day}/${_bannerValidUntil!.month}/${_bannerValidUntil!.year}'
                      : 'Expiry date (optional — never expires if blank)',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: _bannerValidUntil != null
                          ? const Color(0xFF374151)
                          : const Color(0xFF9CA3AF)),
                ),
              ]),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _createBanner,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
              child: Text('Add Banner',
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
          ),
        ]),
      ),
    ]);
  }

  // ─── Banner field helper ──────────────────────────────────────────────────────
  Widget _bannerField(TextEditingController ctrl, String hint) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      controller: ctrl,
      style: GoogleFonts.inter(fontSize: 12),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
            fontSize: 12, color: const Color(0xFF9CA3AF)),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.primary)),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
      ),
    ),
  );

  // ─── Section Header ──────────────────────────────────────────────────────────
  Widget _sectionHeader({
    required String icon,
    required String title,
    required int count,
    required Color countColor,
  }) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Text(title,
            style: GoogleFonts.playfairDisplay(
                fontSize: 16, fontWeight: FontWeight.w700,
                color: const Color(0xFF111827))),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: countColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: countColor.withOpacity(0.3)),
          ),
          child: Text('$count',
              style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w700, color: countColor)),
        ),
      ],
    );
  }

  // ─── Pending Section ─────────────────────────────────────────────────────────
  Widget _buildPendingSection() {
    if (_loadingPending) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_pendingError != null) {
      return _errorCard(_pendingError!, _loadPending);
    }
    if (_pending.isEmpty) {
      return _emptyCard('No pending verifications 🎉', 'All caught up!');
    }
    return Column(
      children: _pending.map((u) => _buildPendingTile(u)).toList(),
    );
  }

  // ─── Pending Tile ─────────────────────────────────────────────────────────────
  Widget _buildPendingTile(Map<String, dynamic> user) {
    final name     = user['full_name'] ?? 'Unknown';
    final photoUrl = user['profile_photo_url'] as String?;
    final userId   = user['id'].toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Photo — tap to open fullscreen (privacy: no phone shown)          // ✅ CHANGE
          GestureDetector(                                                      // ✅ ADD
            onTap: (photoUrl != null && photoUrl.isNotEmpty)                    // ✅ ADD
                ? () => _openPhotoViewer(photoUrl, 'pending_dp_$userId')        // ✅ ADD
                : null,                                                         // ✅ ADD
            child: Stack(                                                       // ✅ ADD
              clipBehavior: Clip.none,                                          // ✅ ADD
              children: [                                                       // ✅ ADD
                Hero(                                                           // ✅ ADD
                  tag: 'pending_dp_$userId',                                    // ✅ ADD
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFFBBF7D0),
                    backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                        ? NetworkImage(photoUrl)
                        : null,
                    child: (photoUrl == null || photoUrl.isEmpty)
                        ? Text(name[0].toUpperCase(),
                            style: GoogleFonts.playfairDisplay(
                                fontSize: 20, fontWeight: FontWeight.w700,
                                color: AppColors.primary))
                        : null,
                  ),
                ),                                                              // ✅ ADD
                // Zoom-in badge — visual cue that DP is tappable               // ✅ ADD
                if (photoUrl != null && photoUrl.isNotEmpty)                    // ✅ ADD
                  Positioned(                                                   // ✅ ADD
                    right: -2,                                                  // ✅ ADD
                    bottom: -2,                                                 // ✅ ADD
                    child: Container(                                           // ✅ ADD
                      padding: const EdgeInsets.all(3),                         // ✅ ADD
                      decoration: BoxDecoration(                                // ✅ ADD
                        color: AppColors.primary,                               // ✅ ADD
                        shape: BoxShape.circle,                                 // ✅ ADD
                        border: Border.all(color: Colors.white, width: 1.5),   // ✅ ADD
                      ),                                                        // ✅ ADD
                      child: const Icon(                                        // ✅ ADD
                        Icons.zoom_in_rounded,                                  // ✅ ADD
                        size: 11,                                               // ✅ ADD
                        color: Colors.white,                                    // ✅ ADD
                      ),                                                        // ✅ ADD
                    ),                                                          // ✅ ADD
                  ),                                                            // ✅ ADD
              ],                                                                // ✅ ADD
            ),                                                                  // ✅ ADD
          ),                                                                    // ✅ ADD
          const SizedBox(width: 12),

          // Name only — no phone (privacy decision)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: const Color(0xFF111827))),
                Text('Awaiting verification',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: const Color(0xFF6B7280))),
              ],
            ),
          ),

          // Approve button
          GestureDetector(
            onTap: () => _approveUser(userId, name),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Text('Approve',
                  style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
            ),
          ),
          const SizedBox(width: 6),

          // Revoke button
          GestureDetector(
            onTap: () => _revokeUser(userId, name),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Text('Revoke',
                  style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: Colors.red)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Members Section ──────────────────────────────────────────────────────────
  Widget _buildMembersSection() {
    if (_loadingMembers) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_membersError != null) {
      return _errorCard(_membersError!, _loadMembers);
    }
    if (_members.isEmpty) {
      return _emptyCard('No members yet', 'Users will appear here after registration.');
    }
    return Column(
      children: _members.map((u) => _buildMemberTile(u)).toList(),
    );
  }

  // ─── Member Tile ──────────────────────────────────────────────────────────────
  Widget _buildMemberTile(Map<String, dynamic> user) {
    final name     = user['full_name'] ?? 'Unknown';
    final role     = user['role']  ?? 'user';
    final badge    = user['badge'] ?? 'none';
    final userId   = user['id']?.toString() ?? '';
    final photoUrl = user['profile_photo_url'] as String?;
    final isAdmin  = _userRole == 'admin' || _userRole == 'super_admin';        // ✅ ADD

    return InkWell(                                                              // ✅ CHANGE — was GestureDetector
      onTap: isAdmin ? () => _openMemberDetail(user) : null,                     // ✅ CHANGE — now opens detail
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFBBF7D0),
              backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                  ? NetworkImage(photoUrl)
                  : null,
              child: (photoUrl == null || photoUrl.isEmpty)
                  ? Text(name[0].toUpperCase(),
                      style: GoogleFonts.playfairDisplay(
                          fontSize: 16, fontWeight: FontWeight.w700,
                          color: AppColors.primary))
                  : null,
            ),
            const SizedBox(width: 12),

            // Name + role only — no phone (privacy)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: const Color(0xFF111827))),
                  Text(_roleLabel(role),
                      style: GoogleFonts.inter(
                          fontSize: 11, color: const Color(0xFF6B7280))),
                ],
              ),
            ),

            // Badge chip
            if (badge == 'durbe_niwasi')
              _miniChip('🏠 Verified', const Color(0xFFDCFCE7), AppColors.primary)
            else if (badge == 'pending')
              _miniChip('⏳ Pending', const Color(0xFFFFFBEB), const Color(0xFFD97706))
            else
              _miniChip('No badge', const Color(0xFFF3F4F6), const Color(0xFF9CA3AF)),

            // Tap hint for admins (any admin role can open detail)
            if (isAdmin) ...[                                                    // ✅ CHANGE — was super_admin only
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  size: 16, color: Color(0xFFD1D5DB)),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Open Member Detail ──────────────────────────────────────────────────────  // ✅ ADD (new helper)
  Future<void> _openMemberDetail(Map<String, dynamic> user) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _MemberDetailScreen(
          user:            user,
          currentUserRole: _userRole ?? 'user',
          currentUserId:   _userId   ?? '',
        ),
      ),
    );
    if (changed == true) {
      _loadMembers();
      _loadPending();
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────────
  Widget _emptyCard(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: const Color(0xFF374151))),
          const SizedBox(height: 4),
          Text(subtitle,
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF9CA3AF))),
        ],
      ),
    );
  }

  Widget _errorCard(String error, VoidCallback retry) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        border: Border.all(color: const Color(0xFFFCA5A5)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(error,
              style: GoogleFonts.inter(fontSize: 11, color: Colors.red))),
          TextButton(
            onPressed: retry,
            child: Text('Retry', style: GoogleFonts.inter(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _miniChip(String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 9, fontWeight: FontWeight.w600, color: text)),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'super_admin': return 'Super Admin';
      case 'admin':       return 'Admin';
      case 'vendor':      return 'Vendor';
      default:            return 'User';
    }
  }
  
  // ─── Window Section ───────────────────────────────────────────────────────────
  Widget _buildWindowSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Current window status ───────────────────────────────────────────
        if (_loadingWindow)
          const Center(child: CircularProgressIndicator(color: AppColors.primary))
        else if (_window != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (_window!['is_open'] == true)
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFFEF3C7),
              border: Border.all(
                color: (_window!['is_open'] == true)
                    ? const Color(0xFF86EFAC)
                    : const Color(0xFFFCD34D),
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      (_window!['is_open'] == true) ? '🗳️ Window Open' : '🔒 Window Closed',
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: (_window!['is_open'] == true)
                              ? AppColors.primary
                              : const Color(0xFF92400E)),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(_window!['label'] ?? '',
                          style: GoogleFonts.inter(
                              fontSize: 10, fontWeight: FontWeight.w600,
                              color: const Color(0xFF374151))),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Opens: ${_formatDate(_window!['opens_at'])}  ·  Closes: ${_formatDate(_window!['closes_at'])}',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: const Color(0xFF374151)),
                ),
                const SizedBox(height: 10),
                // Hide / Unhide button
                SizedBox(
                  width: double.infinity,
                  child: (_window!['is_open'] == true)
                      ? OutlinedButton.icon(
                          onPressed: _hideWindow,
                          icon: const Icon(Icons.lock_outline_rounded, size: 16),
                          label: Text('Force Close Window',
                              style: GoogleFonts.inter(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: () =>
                              _unhideWindow(_window!['id'].toString()),
                          icon: const Icon(Icons.lock_open_rounded, size: 16),
                          label: Text('Reopen Window',
                              style: GoogleFonts.inter(
                                  fontSize: 12, fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ] else
          _emptyCard('No active window', 'Create a new rating window below.'),

        const SizedBox(height: 14),

        // ── Create new window form ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Create New Window',
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: const Color(0xFF374151))),
              const SizedBox(height: 12),

              // Label field
              TextField(
                controller: _windowLabelCtrl,
                style: GoogleFonts.inter(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Label — e.g. Jan 2026',
                  hintStyle: GoogleFonts.inter(
                      fontSize: 12, color: const Color(0xFF9CA3AF)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Color(0xFFE5E7EB))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Color(0xFFE5E7EB))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: AppColors.primary)),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                ),
              ),

              const SizedBox(height: 10),

              // Date pickers row
              Row(
                children: [
                  Expanded(
                    child: _dateTile(
                      label: _windowOpensAt != null
                          ? _formatDate(
                              _windowOpensAt!.toIso8601String())
                          : 'Opens on',
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2030),
                          builder: (ctx, child) => Theme(
                            data: Theme.of(ctx).copyWith(
                              colorScheme: const ColorScheme.light(
                                  primary: AppColors.primary),
                            ),
                            child: child!,
                          ),
                        );
                        if (d != null) setState(() => _windowOpensAt = d);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _dateTile(
                      label: _windowClosesAt != null
                          ? _formatDate(
                              _windowClosesAt!.toIso8601String())
                          : 'Closes on',
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2030),
                          builder: (ctx, child) => Theme(
                            data: Theme.of(ctx).copyWith(
                              colorScheme: const ColorScheme.light(
                                  primary: AppColors.primary),
                            ),
                            child: child!,
                          ),
                        );
                        if (d != null) setState(() => _windowClosesAt = d);
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _createWindow,
                  icon: const Icon(Icons.add_rounded,
                      size: 16, color: Colors.white),
                  label: Text('Create Window',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Fullscreen Photo Viewer trigger ─────────────────────────────────────── // ✅ ADD
  void _openPhotoViewer(String url, String heroTag) {                            // ✅ ADD
    Navigator.of(context).push(PageRouteBuilder(                                 // ✅ ADD
      opaque: false,                                                             // ✅ ADD
      barrierColor: Colors.black.withOpacity(0.92),                              // ✅ ADD
      transitionDuration: const Duration(milliseconds: 250),                     // ✅ ADD
      pageBuilder: (_, __, ___) =>                                               // ✅ ADD
          _PhotoViewerScreen(url: url, heroTag: heroTag),                        // ✅ ADD
    ));                                                                          // ✅ ADD
  }                                                                              // ✅ ADD

  // ─── Date tile helper ─────────────────────────────────────────────────────────
  Widget _dateTile({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                size: 13, color: AppColors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: label.contains('on')
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF374151))),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Format date helper ───────────────────────────────────────────────────────
  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month]} ${dt.year}';
    } catch (_) { return iso; }
  }
}

// ─── Member Detail Screen ─────────────────────────────────────────────────────  // ✅ NEW
// Opened when admin taps a community member tile.
// Shows DP, verification photo, role, badge, and action buttons (revoke /
// change role) — buttons only appear when the caller has permission and
// the target isn't a super_admin or the caller themselves.
class _MemberDetailScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final String currentUserRole;
  final String currentUserId;
  const _MemberDetailScreen({
    required this.user,
    required this.currentUserRole,
    required this.currentUserId,
  });

  @override
  State<_MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<_MemberDetailScreen> {
  bool _busy = false;
  bool _changed = false;                  // set true after any successful action
  late Map<String, dynamic> _user;        // mutable copy so we can refresh after revoke

  @override
  void initState() {
    super.initState();
    _user = Map<String, dynamic>.from(widget.user);
  }

  bool get _isSelf              => _user['id']?.toString() == widget.currentUserId;
  bool get _isSuperAdminTarget  => (_user['role'] ?? '') == 'super_admin';
  bool get _isSuperAdminCaller  => widget.currentUserRole == 'super_admin';

  bool get _canChangeRole       =>
      _isSuperAdminCaller && !_isSuperAdminTarget && !_isSelf;

  bool get _canRevokeBadge {
    final badge = _user['badge'] ?? 'none';
    return (badge == 'durbe_niwasi' || badge == 'pending')
        && !_isSuperAdminTarget
        && !_isSelf;
  }

  // ─── Open photo in fullscreen viewer (reuses _PhotoViewerScreen) ───
  void _openPhoto(String url, String tag) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black.withOpacity(0.92),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => _PhotoViewerScreen(url: url, heroTag: tag),
    ));
  }

  // ─── Revoke badge action ───
  Future<void> _revokeBadge() async {
    final name = _user['full_name'] ?? 'this user';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Revoke Badge',
            style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.w700, color: Colors.red)),
        content: Text('Remove the Durbe Niwasi badge from $name?',
            style: GoogleFonts.inter(fontSize: 13)),
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
            child: Text('Revoke', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      await ApiService.revokeUser(_user['id'].toString());
      setState(() {
        _user['badge']                  = 'none';
        _user['verification_photo_url'] = null;
        _changed = true;
        _busy    = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$name\'s badge has been revoked.',
              style: GoogleFonts.inter()),
          backgroundColor: Colors.orange,
        ));
      }
    } catch (e) {
      setState(() => _busy = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString(), style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // ─── Change role action ───
  Future<void> _changeRole() async {
    final roles  = ['user', 'admin', 'vendor'];
    final labels = {'user': 'User', 'admin': 'Admin', 'vendor': 'Vendor'};
    final currentRole = _user['role'] ?? 'user';

    final selected = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Change Role',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: roles.map((r) => RadioListTile<String>(
            value: r,
            groupValue: currentRole,
            title: Text(labels[r]!, style: GoogleFonts.inter(fontSize: 13)),
            activeColor: AppColors.primary,
            onChanged: (v) => Navigator.pop(context, v),
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
        ],
      ),
    );
    if (selected == null || selected == currentRole) return;

    setState(() => _busy = true);
    try {
      await ApiService.changeUserRole(_user['id'].toString(), selected);
      setState(() {
        _user['role'] = selected;
        _changed = true;
        _busy = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Role changed to ${labels[selected]}.',
              style: GoogleFonts.inter()),
          backgroundColor: AppColors.primary,
        ));
      }
    } catch (e) {
      setState(() => _busy = false);
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
    final name         = _user['full_name'] ?? 'Unknown';
    final role         = _user['role']  ?? 'user';
    final badge        = _user['badge'] ?? 'none';
    final dpUrl        = _user['profile_photo_url'] as String?;
    final verifUrl     = _user['verification_photo_url'] as String?;
    final hasDp        = dpUrl != null && dpUrl.isNotEmpty;
    final hasVerifPic  = verifUrl != null && verifUrl.isNotEmpty;
    final memberId     = _user['id']?.toString() ?? '';

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _changed);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAF7),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFAFAF7),
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: AppColors.primary),
            onPressed: () => Navigator.pop(context, _changed),
          ),
          title: Text('Member Detail',
              style: GoogleFonts.playfairDisplay(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              // ─── Current DP ───
              Center(
                child: GestureDetector(
                  onTap: hasDp ? () => _openPhoto(dpUrl, 'detail_dp_$memberId') : null,
                  child: Hero(
                    tag: 'detail_dp_$memberId',
                    child: CircleAvatar(
                      radius: 56,
                      backgroundColor: const Color(0xFFBBF7D0),
                      backgroundImage: hasDp ? NetworkImage(dpUrl) : null,
                      child: !hasDp
                          ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: GoogleFonts.playfairDisplay(
                                  fontSize: 38, fontWeight: FontWeight.w700,
                                  color: AppColors.primary))
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text('Current profile photo',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: const Color(0xFF9CA3AF))),
              const SizedBox(height: 20),

              // ─── Name + role + badge ───
              Center(
                child: Text(name,
                    style: GoogleFonts.playfairDisplay(
                        fontSize: 22, fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827))),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(_roleLabel(role),
                    style: GoogleFonts.inter(
                        fontSize: 13, color: const Color(0xFF6B7280))),
              ),
              const SizedBox(height: 8),
              Center(child: _badgeChip(badge)),
              const SizedBox(height: 24),

              // ─── Verification photo (only if it exists) ───
              if (hasVerifPic) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.verified_user_rounded,
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text('Verification photo (locked)',
                              style: GoogleFonts.inter(
                                  fontSize: 12, fontWeight: FontWeight.w600,
                                  color: AppColors.primary)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('The photo admin approved at verification time. Tap to view full size.',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: const Color(0xFF6B7280))),
                      const SizedBox(height: 12),
                      Center(
                        child: GestureDetector(
                          onTap: () => _openPhoto(verifUrl, 'detail_verif_$memberId'),
                          child: Hero(
                            tag: 'detail_verif_$memberId',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                verifUrl,
                                width: 140, height: 140, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 140, height: 140,
                                  color: const Color(0xFFF3F4F6),
                                  child: const Icon(Icons.broken_image_rounded,
                                      color: Color(0xFF9CA3AF)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ─── Action buttons (only if caller has permissions) ───
              if (_isSelf) ...[
                _infoBox('This is your own account. Use the Profile screen to manage your own settings.'),
              ] else if (_isSuperAdminTarget) ...[
                _infoBox('This is a Super Admin account. Their role and badge cannot be changed from here.'),
              ] else ...[
                if (_canChangeRole) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : _changeRole,
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: Text('Change Role',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_canRevokeBadge) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : _revokeBadge,
                      icon: const Icon(Icons.remove_moderator_rounded, size: 18),
                      label: Text('Revoke Badge',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
                if (!_canChangeRole && !_canRevokeBadge)
                  _infoBox('No actions available for this user at your permission level.'),
              ],
              if (_busy) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── Tiny helpers ───────────────────────────────────────────────────────────
  Widget _infoBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text,
          style: GoogleFonts.inter(
              fontSize: 12, color: const Color(0xFF6B7280))),
    );
  }

  Widget _badgeChip(String badge) {
    if (badge == 'durbe_niwasi') {
      return _chip('🏠 Durbe Niwasi', const Color(0xFFDCFCE7), AppColors.primary);
    }
    if (badge == 'pending') {
      return _chip('⏳ Pending', const Color(0xFFFFFBEB), const Color(0xFFD97706));
    }
    return _chip('No badge', const Color(0xFFF3F4F6), const Color(0xFF6B7280));
  }

  Widget _chip(String label, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'super_admin': return 'Super Admin';
      case 'admin':       return 'Admin';
      case 'vendor':      return 'Vendor';
      default:            return 'User';
    }
  }
}

// ─── Fullscreen Photo Viewer (for DP verification) ──────────────────────────  // ✅ ADD
class _PhotoViewerScreen extends StatelessWidget {                              // ✅ ADD
  final String url;                                                             // ✅ ADD
  final String heroTag;                                                         // ✅ ADD
  const _PhotoViewerScreen({required this.url, required this.heroTag});         // ✅ ADD

  @override                                                                     // ✅ ADD
  Widget build(BuildContext context) {                                          // ✅ ADD
    return Scaffold(                                                            // ✅ ADD
      backgroundColor: Colors.transparent,                                      // ✅ ADD
      body: GestureDetector(                                                    // ✅ ADD
        onTap: () => Navigator.of(context).pop(),                               // ✅ ADD
        child: Stack(                                                           // ✅ ADD
          children: [                                                           // ✅ ADD
            // ── Zoomable image ──                                             // ✅ ADD
            Center(                                                             // ✅ ADD
              child: Hero(                                                      // ✅ ADD
                tag: heroTag,                                                   // ✅ ADD
                child: InteractiveViewer(                                       // ✅ ADD
                  panEnabled: true,                                             // ✅ ADD
                  minScale: 0.8,                                                // ✅ ADD
                  maxScale: 5,                                                  // ✅ ADD
                  child: Image.network(                                         // ✅ ADD
                    url,                                                        // ✅ ADD
                    fit: BoxFit.contain,                                        // ✅ ADD
                    loadingBuilder: (ctx, child, progress) {                    // ✅ ADD
                      if (progress == null) return child;                       // ✅ ADD
                      return const Center(                                      // ✅ ADD
                        child: CircularProgressIndicator(                       // ✅ ADD
                            color: Colors.white),                               // ✅ ADD
                      );                                                        // ✅ ADD
                    },                                                          // ✅ ADD
                    errorBuilder: (_, __, ___) => const Center(                 // ✅ ADD
                      child: Icon(Icons.broken_image_rounded,                   // ✅ ADD
                          color: Colors.white54, size: 64),                     // ✅ ADD
                    ),                                                          // ✅ ADD
                  ),                                                            // ✅ ADD
                ),                                                              // ✅ ADD
              ),                                                                // ✅ ADD
            ),                                                                  // ✅ ADD
            // ── Close button ──                                               // ✅ ADD
            Positioned(                                                         // ✅ ADD
              top: 50,                                                          // ✅ ADD
              right: 16,                                                        // ✅ ADD
              child: GestureDetector(                                           // ✅ ADD
                onTap: () => Navigator.of(context).pop(),                       // ✅ ADD
                child: Container(                                               // ✅ ADD
                  padding: const EdgeInsets.all(8),                             // ✅ ADD
                  decoration: BoxDecoration(                                    // ✅ ADD
                    color: Colors.black54,                                      // ✅ ADD
                    shape: BoxShape.circle,                                     // ✅ ADD
                    border: Border.all(color: Colors.white24),                  // ✅ ADD
                  ),                                                            // ✅ ADD
                  child: const Icon(Icons.close_rounded,                        // ✅ ADD
                      color: Colors.white, size: 22),                           // ✅ ADD
                ),                                                              // ✅ ADD
              ),                                                                // ✅ ADD
            ),                                                                  // ✅ ADD
            // ── Hint at bottom ──                                             // ✅ ADD
            Positioned(                                                         // ✅ ADD
              bottom: 40,                                                       // ✅ ADD
              left: 0,                                                          // ✅ ADD
              right: 0,                                                         // ✅ ADD
              child: Center(                                                    // ✅ ADD
                child: Container(                                               // ✅ ADD
                  padding: const EdgeInsets.symmetric(                          // ✅ ADD
                      horizontal: 14, vertical: 6),                             // ✅ ADD
                  decoration: BoxDecoration(                                    // ✅ ADD
                    color: Colors.black54,                                      // ✅ ADD
                    borderRadius: BorderRadius.circular(20),                    // ✅ ADD
                  ),                                                            // ✅ ADD
                  child: Text('Pinch to zoom • Tap to close',                   // ✅ ADD
                      style: GoogleFonts.inter(                                 // ✅ ADD
                          fontSize: 11,                                         // ✅ ADD
                          color: Colors.white70,                                // ✅ ADD
                          fontWeight: FontWeight.w500)),                        // ✅ ADD
                ),                                                              // ✅ ADD
              ),                                                                // ✅ ADD
            ),                                                                  // ✅ ADD
          ],                                                                    // ✅ ADD
        ),                                                                      // ✅ ADD
      ),                                                                        // ✅ ADD
    );                                                                          // ✅ ADD
  }                                                                             // ✅ ADD
}                                                                               // ✅ ADD