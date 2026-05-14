// lib/features/gram_awaaz/screens/gram_awaaz_screen.dart
// ──────────────────────────────────────────────────────────────────
// Gram Awaaz — Civic complaint board for Durbe village.
//
// Any villager can READ complaints — no login needed.
// Logged-in villagers can POST a complaint and UPVOTE others.
// Complaints are sorted by upvote count — most urgent rises to top.
//
// Photos: picked from camera/gallery → uploaded to Cloudinary → URL sent to backend
// 1 photo mandatory, up to 3 optional (4 total)
//
// API methods used:
//   ApiService.getGramAwaazPosts()       → GET  /gram-awaaz
//   ApiService.createGramAwaazPost()     → POST /gram-awaaz
//   ApiService.upvoteGramAwaazPost()     → POST /gram-awaaz/{id}/upvote
// ──────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_service.dart';
import '../../../core/network/cloudinary_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Department enum — must match backend exactly ──────────────────
const List<Map<String, String>> _departments = [
  {'value': 'panchayat',   'label': 'Gram Panchayat', 'emoji': '🏛️'},
  {'value': 'bdo',         'label': 'BDO Office',     'emoji': '🏢'},
  {'value': 'pwd',         'label': 'PWD (Roads)',    'emoji': '🛣️'},
  {'value': 'health',      'label': 'Health Centre',  'emoji': '🏥'},
  {'value': 'police',      'label': 'Police Station', 'emoji': '👮'},
  {'value': 'education',   'label': 'Education Dept', 'emoji': '📚'},
  {'value': 'electricity', 'label': 'Bijli Dept',     'emoji': '⚡'},
  {'value': 'water',       'label': 'Jal Jeevan',     'emoji': '💧'},
  {'value': 'other',       'label': 'Other',          'emoji': '📌'},
];

String _deptLabel(String value) {
  final dept = _departments.firstWhere(
    (d) => d['value'] == value,
    orElse: () => {'emoji': '📌', 'label': value},
  );
  return '${dept['emoji']} ${dept['label']}';
}

Color _deptColor(String dept) {
  switch (dept) {
    case 'health':      return const Color(0xFF4CAF50);
    case 'police':      return const Color(0xFF2196F3);
    case 'pwd':         return const Color(0xFFFF9800);
    case 'education':   return const Color(0xFF9C27B0);
    case 'electricity': return const Color(0xFFFFC107);
    case 'water':       return const Color(0xFF00BCD4);
    case 'bdo':         return const Color(0xFF607D8B);
    case 'panchayat':   return const Color(0xFF795548);
    default:            return AppColors.textSecondary;
  }
}


// ══════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ══════════════════════════════════════════════════════════════════
class GramAwaazScreen extends StatefulWidget {
  const GramAwaazScreen({super.key});

  @override
  State<GramAwaazScreen> createState() => _GramAwaazScreenState();
}

class _GramAwaazScreenState extends State<GramAwaazScreen> {
  List<dynamic> _posts     = [];
  bool          _isLoading = true;
  String?       _error;
  String?       _selectedDept;
  String? _userRole;
  String? _userBadge;
  String _sortBy         = 'upvotes'; // 'upvotes' | 'latest'
  int    _displayCount   = 15;
  final  ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _fetchPosts();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (_displayCount < _posts.length) {
          setState(() => _displayCount += 10);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<dynamic> get _displayedPosts {
    final sorted = List.from(_posts);
    if (_sortBy == 'latest') {
      sorted.sort((a, b) {
        final dateA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(0);
        final dateB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(0);
        return dateB.compareTo(dateA);
      });
    } else {
      sorted.sort((a, b) =>
          (b['upvote_count'] ?? 0).compareTo(a['upvote_count'] ?? 0));
    }
    return sorted.take(_displayCount).toList();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() {
      _userRole  = prefs.getString('user_role');
      _userBadge = prefs.getString('badge');
    });
  }

  Future<void> _fetchPosts() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final posts = await ApiService.getGramAwaazPosts(department: _selectedDept);
      setState(() { _posts = posts; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _upvotePost(String postId) async {
    try {
      final result = await ApiService.upvoteGramAwaazPost(postId);
      if (result['statusCode'] == 200) {
        setState(() {
          final i = _posts.indexWhere((p) => p['id'] == postId);
          if (i != -1) {
            _posts[i] = Map.from(_posts[i])
              ..['upvote_count'] = result['upvote_count'];
          }
        });
        _snack('आपका समर्थन देने के लिए धन्यवाद! 🙏🏻', isSuccess: true);
      } else if (result['statusCode'] == 400) {
        _snack('आप पहले ही इस पर समर्थन कर चुके हैं।');
      } else if (result['statusCode'] == 401) {
        _snack('समर्थन करने के लिए पहले लॉगिन करें।');
      }
    } catch (_) {
      _snack('Network error. Check connection.');
    }
  }

  void _snack(String msg, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.notoSansDevanagari()),
      backgroundColor: isSuccess ? AppColors.primary : null,
      duration: const Duration(seconds: 2),
    ));
  }

  void _openCreatePost() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreatePostSheet(onPostCreated: _fetchPosts),
    );
  }

// ✅ CHANGE: fetch full detail before opening sheet
  // List response doesn't have description/demand — need full endpoint
  void _openDetail(dynamic post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PostDetailSheet(
        postId:   post['id'],
        postSnap: post,          // ✅ pass list data for instant display
        onUpvote: () => _upvotePost(post['id']),
        userRole:  _userRole,
        userBadge: _userBadge,
        onDeleted: _fetchPosts,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Gram Awaaz',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w600, fontSize: 20, color: Colors.white)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchPosts),
        ],
      ),
      floatingActionButton: (_userBadge == 'durbe_niwasi' ||
              _userRole == 'admin' || _userRole == 'super_admin')
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              onPressed: _openCreatePost,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text('नई शिकायत',
                  style: GoogleFonts.notoSansDevanagari(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Text(
              'गांव की आवाज़ — समस्या उठाएं, सरकार तक पहुंचाएं',
              style: GoogleFonts.notoSansDevanagari(
                color: Colors.white70, fontSize: 13),
            ),
          ),
          _buildFilterRow(),
          if (!_isLoading && _error == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(children: [
                Text('${_posts.length} शिकायतें',
                  style: GoogleFonts.notoSansDevanagari(
                    fontSize: 13, color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500)),
                const Spacer(),
                // ✅ Sort toggle
                GestureDetector(
                  onTap: () => setState(() {
                    _sortBy = _sortBy == 'upvotes' ? 'latest' : 'upvotes';
                    _displayCount = 15;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        _sortBy == 'upvotes'
                            ? Icons.thumb_up_outlined
                            : Icons.access_time_rounded,
                        size: 12, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        _sortBy == 'upvotes' ? 'Most Supported' : 'Latest',
                        style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                    ]),
                  ),
                ),
              ]),
            ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                    ? _buildError()
                    : _posts.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            onRefresh: _fetchPosts,
                            color: AppColors.primary,
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                              itemCount: _displayedPosts.length + 1,
                              itemBuilder: (_, i) {
                                if (i == _displayedPosts.length) {
                                  // ✅ Footer: load more indicator or end message
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: _displayCount < _posts.length
                                          ? const SizedBox(
                                              width: 20, height: 20,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2))
                                          : Text('सभी शिकायतें देख ली गई हैं',
                                              style: GoogleFonts.notoSansDevanagari(
                                                  fontSize: 12,
                                                  color: AppColors.textHint)),
                                    ),
                                  );
                                }
                                return _PostCard(
                                  post: _displayedPosts[i],
                                  onTap: () => _openDetail(_displayedPosts[i]),
                                  onUpvote: () => _upvotePost(_displayedPosts[i]['id']),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
  Widget _buildFilterRow() {
    return Container(
      height: 50,
      color: AppColors.primaryDark,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Center(child: _DeptChip(
            label: 'All',
            isSelected: _selectedDept == null,
            onTap: () { setState(() => _selectedDept = null); _fetchPosts(); },
          )),
          const SizedBox(width: 8),
          ..._departments.map((d) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(child: _DeptChip(
              label: '${d['emoji']} ${d['label']}',
              isSelected: _selectedDept == d['value'],
              onTap: () {
                setState(() => _selectedDept = d['value']);
                _fetchPosts();
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
        onPressed: _fetchPosts,
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
      const Icon(Icons.campaign_outlined, size: 72, color: Colors.grey),
      const SizedBox(height: 14),
      Text('कोई शिकायत नहीं मिली',
        style: GoogleFonts.notoSansDevanagari(
          color: AppColors.textSecondary, fontSize: 16,
          fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      Text('पहले आवाज़ उठाएं!',
        style: GoogleFonts.notoSansDevanagari(
          color: AppColors.textHint, fontSize: 13)),
    ],
  ));
}


// ══════════════════════════════════════════════════════════════════
// DEPARTMENT FILTER CHIP
// ══════════════════════════════════════════════════════════════════
class _DeptChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _DeptChip({required this.label, required this.isSelected, required this.onTap});

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
// POST CARD
// ══════════════════════════════════════════════════════════════════
class _PostCard extends StatelessWidget {
  final dynamic post;
  final VoidCallback onTap;
  final VoidCallback onUpvote;
  const _PostCard({required this.post, required this.onTap, required this.onUpvote});

  @override
  Widget build(BuildContext context) {
    final dept      = (post['department'] as String?) ?? 'other';
    final deptColor = _deptColor(dept);
    final upvotes   = post['upvote_count'] ?? 0;
    // ✅ Use photo_url_1 as the primary card image
    final photoUrl  = post['photo_url_1'] ?? '';

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
          // — Primary photo ──────────────────────────────────────
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: photoUrl.isNotEmpty
                ? Image.network(photoUrl,
                    height: 170, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _photoPlaceholder())
                : _photoPlaceholder(),
          ),
          Padding(
            padding: const EdgeInsets.all(13),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: deptColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20)),
                  child: Text(_deptLabel(dept),
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.bold, color: deptColor)),
                ),
                const Spacer(),
                Icon(Icons.location_on_outlined, size: 13, color: AppColors.textHint),
                const SizedBox(width: 2),
                Flexible(child: Text(post['location'] ?? '',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textHint),
                  overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 8),
              Text(post['title'] ?? '',
                style: GoogleFonts.notoSansDevanagari(
                  fontSize: 15, fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary, height: 1.3),
                maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.people_alt_outlined, size: 14, color: AppColors.textHint),
                const SizedBox(width: 4),
                Text('${post['affected_count']} लोग प्रभावित',
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

  Widget _photoPlaceholder() => Container(
    height: 170, color: const Color(0xFFEEEEEE),
    child: const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.image_not_supported, size: 36, color: Colors.grey),
        SizedBox(height: 4),
        Text('No photo', style: TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    ),
  );
}


// ══════════════════════════════════════════════════════════════════
// POST DETAIL BOTTOM SHEET
// ✅ CHANGE: now StatefulWidget — fetches full detail on open
// Shows description + demand from GET /gram-awaaz/{id}
// ══════════════════════════════════════════════════════════════════
class _PostDetailSheet extends StatefulWidget {
  final String   postId;
  final dynamic  postSnap;
  final VoidCallback onUpvote;
  final String?  userRole;
  final String? userBadge;
  final VoidCallback? onDeleted;
  const _PostDetailSheet({
    required this.postId,
    required this.postSnap,
    required this.onUpvote,
    this.userBadge,
    this.userRole,
    this.onDeleted,
  });

  @override
  State<_PostDetailSheet> createState() => _PostDetailSheetState();
}

class _PostDetailSheetState extends State<_PostDetailSheet> {
  Map<String, dynamic>? _fullPost;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    try {
      final data = await ApiService.getGramAwaazDetail(widget.postId);
      if (mounted) setState(() { _fullPost = data; _loading = false; });
    } catch (_) {
      // ✅ Fall back to list data if detail fetch fails
      if (mounted) setState(() { _fullPost = Map.from(widget.postSnap); _loading = false; });
    }
  }

  Future<void> _deletePost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Post',
            style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.w700, color: Colors.red)),
        content: Text('Are you sure you want to delete this complaint?',
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
      await ApiService.deleteGramAwaazPost(widget.postId);
      if (mounted) {
        Navigator.pop(context);
        widget.onDeleted?.call();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Post deleted.', style: GoogleFonts.inter()),
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
    // ✅ Use full data if loaded, else show list data while loading
    final post     = _fullPost ?? widget.postSnap;
    final dept     = (post['department'] as String?) ?? 'other';
    final deptColor = _deptColor(dept);
    final upvotes  = post['upvote_count'] ?? 0;

    final photos = [
      post['photo_url_1'],
      post['photo_url_2'],
      post['photo_url_3'],
      post['photo_url_4'],
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
              // ✅ Delete button — admin/super_admin only
              if (widget.userRole == 'admin' || widget.userRole == 'super_admin')
                GestureDetector(
                  onTap: _deletePost,
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
          // ✅ Show basic info while loading full detail
          ? SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (photos.isNotEmpty) _PhotoGallery(photos: photos),
                const SizedBox(height: 14),
                Text(post['title'] ?? '',
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

                if (photos.isNotEmpty) _PhotoGallery(photos: photos),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: deptColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20)),
                  child: Text(_deptLabel(dept),
                    style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.bold, color: deptColor)),
                ),
                const SizedBox(height: 10),

                Text(post['title'] ?? '',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18, fontWeight: FontWeight.w600,
                    height: 1.3, color: AppColors.textPrimary)),
                const SizedBox(height: 10),

                Row(children: [
                  Icon(Icons.location_on_outlined, size: 15, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Text(post['location'] ?? '',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(width: 16),
                  Icon(Icons.people_alt_outlined, size: 15, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Text('${post['affected_count']} प्रभावित',
                    style: GoogleFonts.notoSansDevanagari(
                      fontSize: 13, color: AppColors.textSecondary)),
                ]),

                const SizedBox(height: 12),
                // ✅ Poster identity + date
                _buildPosterRow(post),
                const SizedBox(height: 14),
                Divider(color: AppColors.border),

                // ✅ Description — now shows because we fetched full detail
                if (post['description'] != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0), // ✅ light green background
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFFCC80))), // ✅ matching border
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.info_outline, size: 14, color: Color(0xFFE65100)),
                        const SizedBox(width: 6),
                        Text('समस्या का विवरण', style: GoogleFonts.notoSansDevanagari(
                          fontSize: 13, fontWeight: FontWeight.bold,
                          color: const Color(0xFFE65100))),
                      ]),
                      const SizedBox(height: 8),
                      Text(post['description'], style: GoogleFonts.notoSansDevanagari(
                        fontSize: 14, color: AppColors.textPrimary, height: 1.65)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                ],

                // ✅ Demand — now shows because we fetched full detail 
                if (post['demand'] != null && post['demand'].toString().isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBBDEFB))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(Icons.gavel, size: 14, color: Color(0xFF1565C0)),
                        const SizedBox(width: 6),
                        Text('हमारी मांग', style: GoogleFonts.notoSansDevanagari(
                          fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF1565C0))),
                      ]),
                      const SizedBox(height: 6),
                      Text(post['demand'], style: GoogleFonts.notoSansDevanagari(
                        fontSize: 14, color: AppColors.textPrimary, height: 1.5)),
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
    final name     = post['poster_name'] ?? 'Durbe Niwasi';
    final photo    = post['poster_photo'] as String?;
    final dateStr  = post['created_at'] as String?;

    return Row(children: [
      // Avatar
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
        color: AppColors.cardBg,
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
class _PhotoGallery extends StatefulWidget {
  final List<String> photos;
  const _PhotoGallery({required this.photos});

  @override
  State<_PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<_PhotoGallery> {
  int _currentIndex = 0;
  final PageController _controller = PageController();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ✅ Swipeable photo pages
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
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFFEEEEEE),
                child: const Icon(Icons.image_not_supported,
                  size: 48, color: Colors.grey)),
            ),
          ),
        ),
      ),

      // ✅ Dot indicators — only show if more than 1 photo
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
// CREATE POST BOTTOM SHEET
// ══════════════════════════════════════════════════════════════════
class _CreatePostSheet extends StatefulWidget {
  final VoidCallback onPostCreated;
  const _CreatePostSheet({required this.onPostCreated});

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final _titleCtrl    = TextEditingController();
  final _descCtrl     = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _affectedCtrl = TextEditingController();
  final _demandCtrl   = TextEditingController();

  String?      _selectedDept;
  bool         _isSubmitting = false;
  bool         _isUploading  = false;

  // ✅ Up to 4 photos — File for display, URL after Cloudinary upload
  final List<File?>   _photoFiles = [null, null, null, null];
  final List<String?> _photoUrls  = [null, null, null, null];

  final _picker = ImagePicker();

  // ✅ Let user pick from camera or gallery
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
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          ListTile(
            leading: Icon(Icons.camera_alt, color: AppColors.primary),
            title: Text('Camera से लें',
              style: GoogleFonts.notoSansDevanagari()),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: Icon(Icons.photo_library, color: AppColors.primary),
            title: Text('Gallery से चुनें',
              style: GoogleFonts.notoSansDevanagari()),
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

    // ✅ Upload to Cloudinary immediately after picking
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

  Future<void> _submit() async {
    // ✅ First photo is mandatory
    if (_photoUrls[0] == null) {
      _showError('कम से कम एक फ़ोटो ज़रूरी है — साक्ष्य दिखाएं।');
      return;
    }
    if (_titleCtrl.text.trim().isEmpty    ||
        _descCtrl.text.trim().isEmpty     ||
        _locationCtrl.text.trim().isEmpty ||
        _affectedCtrl.text.trim().isEmpty ||
        _demandCtrl.text.trim().isEmpty   ||
        _selectedDept == null) {
      _showError('सभी जानकारी भरें।');
      return;
    }
    final affectedCount = int.tryParse(_affectedCtrl.text.trim());
    if (affectedCount == null || affectedCount < 1) {
      _showError('प्रभावित लोगों की सही संख्या डालें।');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final result = await ApiService.createGramAwaazPost(
        title:         _titleCtrl.text.trim(),
        description:   _descCtrl.text.trim(),
        location:      _locationCtrl.text.trim(),
        affectedCount: affectedCount,
        department:    _selectedDept!,
        demand:        _demandCtrl.text.trim(),
        photoUrl1:     _photoUrls[0]!,          // ✅ mandatory
        photoUrl2:     _photoUrls[1],           // ✅ optional
        photoUrl3:     _photoUrls[2],           // ✅ optional
        photoUrl4:     _photoUrls[3],           // ✅ optional
      );
      setState(() => _isSubmitting = false);

      if (result['statusCode'] == 201) {
        if (mounted) {
          Navigator.pop(context);
          widget.onPostCreated();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('आपका समर्थन देने के लिए धन्यवाद! 🙏🏻',
              style: GoogleFonts.notoSansDevanagari()),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 3),
          ));
        }
      } else if (result['statusCode'] == 401) {
        _showError('शिकायत दर्ज करने के लिए पहले लॉगिन करें।');
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
        const SizedBox(height: 12),
        Center(child: Container(width: 42, height: 4,
          decoration: BoxDecoration(
            color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Icon(Icons.campaign, color: AppColors.cta, size: 22),
            const SizedBox(width: 10),
            Text('आवाज़ उठाएं', style: GoogleFonts.playfairDisplay(
              fontSize: 18, fontWeight: FontWeight.w600,
              color: AppColors.primary)),
          ]),
        ),
        Divider(height: 1, color: AppColors.border),

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
              Text('पहली फ़ोटो अनिवार्य है — साक्ष्य दिखाएं',
                style: GoogleFonts.notoSansDevanagari(
                  fontSize: 12, color: AppColors.textHint)),
              const SizedBox(height: 10),

              // ✅ 4 photo slots in a 2x2 grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.3,
                children: List.generate(4, (i) => _PhotoSlot(
                  index:     i,
                  file:      _photoFiles[i],
                  isUploading: _isUploading && _photoFiles[i] == null,
                  isMandatory: i == 0,
                  onTap:     () => _pickPhoto(i),
                  onRemove:  () => setState(() {
                    _photoFiles[i] = null;
                    _photoUrls[i]  = null;
                  }),
                )),
              ),

              const SizedBox(height: 16),

              // — Info banner ────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.ctaLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.ctaBorder)),
                child: Row(children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.cta),
                  const SizedBox(width: 8),
                  Flexible(child: Text(
                    'A photo-based evidence complaint is more effective',
                    style: GoogleFonts.notoSansDevanagari(
                      fontSize: 12, color: AppColors.cta))),
                ]),
              ),

              _buildField('शीर्षक (Title) *',       _titleCtrl,    'एक लाइन में समस्या बताएं'),
              _buildField('विस्तार (Description) *', _descCtrl,     'समस्या विस्तार से बताएं — क्या हुआ, कब से है', maxLines: 3),
              _buildField('स्थान (Location) *',      _locationCtrl, 'जैसे: दुर्बे गांव, देवी मंदिर के पास'),
              _buildField('प्रभावित लोग *',          _affectedCtrl, 'अनुमानित संख्या', keyboardType: TextInputType.number),
              _buildField('मांग (Demand) *',          _demandCtrl,   'आप सरकार से क्या चाहते हैं?', maxLines: 2),

              // — Department dropdown ────────────────────────────
              Text('जिम्मेदार विभाग *',
                style: GoogleFonts.notoSansDevanagari(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedDept,
                hint: Text('विभाग चुनें',
                  style: GoogleFonts.notoSansDevanagari(
                    fontSize: 13, color: AppColors.textHint)),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.border)),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12)),
                items: _departments.map((d) => DropdownMenuItem(
                  value: d['value'],
                  child: Text('${d['emoji']} ${d['label']}'))).toList(),
                onChanged: (v) => setState(() => _selectedDept = v),
              ),

              const SizedBox(height: 24),

              // — Submit button ──────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
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
                          Text(_isUploading ? 'फ़ोटो अपलोड हो रही है...' : 'दर्ज हो रहा है...',
                            style: GoogleFonts.notoSansDevanagari(color: Colors.white)),
                        ])
                      : Text('शिकायत दर्ज करें',
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
      {int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.notoSansDevanagari(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl, maxLines: maxLines, keyboardType: keyboardType,
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
    _titleCtrl.dispose();    _descCtrl.dispose();
    _locationCtrl.dispose(); _affectedCtrl.dispose();
    _demandCtrl.dispose();
    super.dispose();
  }

}

// ══════════════════════════════════════════════════════════════════
// PHOTO SLOT — individual photo picker tile
// ══════════════════════════════════════════════════════════════════
class _PhotoSlot extends StatelessWidget {
  final int      index;
  final File?    file;
  final bool     isUploading;
  final bool     isMandatory;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _PhotoSlot({
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
                  CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                  const SizedBox(height: 6),
                  Text('अपलोड हो रहा है...',
                    style: GoogleFonts.notoSansDevanagari(
                      fontSize: 10, color: AppColors.textHint)),
                ]))
            : file != null
                ? Stack(fit: StackFit.expand, children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(file!, fit: BoxFit.cover)),
                    Positioned(top: 4, right: 4,
                      child: GestureDetector(
                        onTap: onRemove,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54, shape: BoxShape.circle),
                          padding: const EdgeInsets.all(3),
                          child: const Icon(Icons.close,
                            size: 14, color: Colors.white),
                        ),
                      )),
                  ])
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined,
                        size: 28,
                        color: isMandatory ? AppColors.cta : AppColors.textHint),
                      const SizedBox(height: 4),
                      Text(
                        index == 0 ? 'फ़ोटो लें *' : 'फ़ोटो लें',
                        style: GoogleFonts.notoSansDevanagari(
                          fontSize: 11,
                          color: isMandatory ? AppColors.cta : AppColors.textHint,
                          fontWeight: isMandatory
                              ? FontWeight.w600 : FontWeight.normal)),
                    ]),
      ),
    );
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