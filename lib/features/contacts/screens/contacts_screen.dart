// lib/features/contacts/screens/contacts_screen.dart
// ─────────────────────────────────────────────────────────────
// Contacts screen — shows all local contacts grouped by category.
// Category 1: Emergency (Police, Ambulance, Fire)
// Category 2: Officials (Mukhiya, BDO, Sarpanch)
// Category 3: Health (Doctor, ASHA, PHC)
// Category 4: Education (School, Anganwadi)
// Category 5: Service Providers (Plumber, Electrician, etc.)
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_service.dart';
import 'contact_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {

  List<dynamic> _contacts = [];
  bool _loading = true;
  String _selectedFilter = 'all';
  String? _userRole;

  final List<Map<String, String>> _filters = [
    {'key': 'all',              'label': 'All'},
    {'key': 'emergency',        'label': 'Emergency'},
    {'key': 'official',         'label': 'Officials'},
    {'key': 'health',           'label': 'Health'},
    {'key': 'service_provider', 'label': 'Services'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadContacts();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _userRole = prefs.getString('user_role'));
  }

  Future<void> _loadContacts() async {
    try {
      final data = await ApiService.getContacts(
        category: _selectedFilter == 'all' ? null : _selectedFilter,
      );
      if (mounted) setState(() {
        _contacts = data;
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
    _loadContacts();
  }

  // — Group contacts by category ────────────────────────────
  Map<String, List<dynamic>> get _grouped {
    final Map<String, List<dynamic>> groups = {};
    for (final c in _contacts) {
      final cat = c['category'] ?? 'other';
      groups.putIfAbsent(cat, () => []).add(c);
    }
    return groups;
  }

  // — Category display names ─────────────────────────────────
  String _catLabel(String cat) {
    switch (cat) {
      case 'emergency':        return 'Emergency';
      case 'official':         return 'Officials';
      case 'health':           return 'Health';
      case 'education':        return 'Education';
      case 'service_provider': return 'Service Providers';
      default:                 return cat;
    }
  }

  // — Avatar color per category ─────────────────────────────
  Color _catColor(String cat) {
    switch (cat) {
      case 'emergency':        return const Color(0xFFFEE2E2);
      case 'official':         return AppColors.primaryLight;
      case 'health':           return const Color(0xFFEFF6FF);
      case 'education':        return const Color(0xFFF5F3FF);
      case 'service_provider': return AppColors.ctaLight;
      default:                 return AppColors.background;
    }
  }

  String _catEmoji(String cat) {
    switch (cat) {
      case 'emergency':        return '🚨';
      case 'official':         return '🏛️';
      case 'health':           return '🏥';
      case 'education':        return '📚';
      case 'service_provider': return '🔧';
      default:                 return '📞';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Contacts',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white, // ✅ gives back arrow automatically
        elevation: 0,
      ),
      floatingActionButton: (_userRole == 'admin' || _userRole == 'super_admin')
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const _AddContactScreen()),
              ).then((_) => _loadContacts()),
              icon: const Icon(Icons.person_add_rounded, color: Colors.white),
              label: Text('Add Contact',
                  style: GoogleFonts.inter(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            // ✅ tagline banner — consistent with all other screens
            Container(
              width: double.infinity,
              color: AppColors.primary,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'आपकी सेवा और सहायता के लिए',
                style: GoogleFonts.notoSansDevanagari(
                  color: Colors.white70, fontSize: 13),
              ),
            ),

            // — Filter chips ──────────────────────────────
            const SizedBox(height: 8),
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final f = _filters[i];
                  final isActive = _selectedFilter == f['key'];
                  return GestureDetector(
                    onTap: () => _applyFilter(f['key']!),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primary
                            : AppColors.cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        f['label']!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isActive
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // — Contact list ──────────────────────────────
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary))
                  : _contacts.isEmpty
                      ? Center(
                          child: Text(
                            'No contacts found.',
                            style: GoogleFonts.inter(
                                color: AppColors.textHint),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(14),
                          children: _grouped.entries.map((entry) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Category header
                                Padding(
                                  padding: const EdgeInsets.only(
                                      top: 8, bottom: 8),
                                  child: Text(
                                    _catLabel(entry.key).toUpperCase(),
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textHint,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                                // Contact cards
                                ...entry.value.map((contact) =>
                                    _contactCard(contact, entry.key)),
                                const SizedBox(height: 4),
                              ],
                            );
                          }).toList(),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactCard(dynamic contact, String category) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ContactDetailScreen(contact: contact),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _catColor(category),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _catEmoji(category),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Name + designation
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact['name'] ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    contact['designation'] ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Call button
            if (contact['phone'] != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: category == 'emergency'
                      ? const Color(0xFFDC2626)
                      : AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  category == 'emergency'
                      ? 'Call ${contact['phone']}'
                      : 'Call',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddContactScreen extends StatefulWidget {
  const _AddContactScreen({super.key});
  @override
  State<_AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<_AddContactScreen> {
  final _nameCtrl  = TextEditingController();
  final _roleCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String _category   = 'official';
  bool   _saving     = false;

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Name is required.', style: GoogleFonts.inter()),
        backgroundColor: Colors.red));
      return;
    }
    if (_roleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Role / Designation is required.', style: GoogleFonts.inter()),
        backgroundColor: Colors.red));
      return;
    }
    final phone = _phoneCtrl.text.trim();
    if (phone.isNotEmpty && phone.length != 10 && phone.length != 3) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Phone must be 3 digits (emergency) or 10 digits.', style: GoogleFonts.inter()),
        backgroundColor: Colors.red));
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiService.createContact({
        'name':        _nameCtrl.text.trim(),
        'designation': _roleCtrl.text.trim(),
        'phone':       _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'address':     _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        'category':    _category,
        'village_id':  1,
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Contact added!', style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFF166534),
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
          onPressed: () => Navigator.pop(context)),
        title: Text('Add Contact', style: GoogleFonts.playfairDisplay(
            fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _lbl('Full Name *'), _field(_nameCtrl, 'e.g. Ramesh Kumar Yadav'),
          _lbl('Role / Designation *'), _field(_roleCtrl, 'e.g. Mukhiya, Doctor, Plumber'),
          _lbl('Phone (optional)'),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              style: GoogleFonts.inter(fontSize: 13),
              decoration: InputDecoration(
                hintText: '10-digit number',
                counterText: '',
                hintStyle: GoogleFonts.inter(color: AppColors.textHint, fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary)),
                filled: true, fillColor: Colors.white,
              ),
            ),
          ),
          _lbl('Address (optional)'), _field(_addressCtrl, 'e.g. Durbe village'),
          _lbl('Category'),
          _drop(value: _category,
            items: ['emergency', 'official', 'health', 'education', 'service_provider'],
            labels: {
              'emergency':        '🚨 Emergency',
              'official':         '🏛️ Officials',
              'health':           '🏥 Health',
              'education':        '📚 Education',
              'service_provider': '🔧 Services',
            },
            onChanged: (v) => setState(() => _category = v!)),
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
                  : Text('Save Contact', style: GoogleFonts.inter(
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
      {TextInputType keyboardType = TextInputType.text}) =>
      Padding(padding: const EdgeInsets.only(bottom: 14),
        child: TextField(controller: c, keyboardType: keyboardType,
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
