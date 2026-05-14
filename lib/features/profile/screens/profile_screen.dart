// ─────────────────────────────────────────────────────────────────────────────
// FILE 1 — lib/features/profile/screens/profile_screen.dart  ✅ REPLACE
//
// Design  : Option B — Clean Minimal (light green background throughout)
// Fixes   : (1) Phone hidden from others — /me endpoint only serves own user
//           (2) Coloured icon boxes in Account Info + permission grid
//           (3) Delete account button added (small, below logout)
//           (4) Profile photo (DP) upload via Cloudinary — tap avatar to upload
//           (5) Face-visible hint shown before upload
//           (6) Contributions deferred to V2
//           (7) Logout = large prominent button · Delete = small red text below
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_service.dart';
import '../../../core/network/cloudinary_service.dart';
import '../../auth/screens/login_screen.dart';
import '../../profile/screens/admin_panel_screen.dart';

// ─── Profile Screen ───────────────────────────────────────────────────────────
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // ─── State ─────────────────────────────────────────────────────────────────
  Map<String, dynamic>? _profile;
  bool _isLoading        = true;
  bool _isUploadingPhoto = false;
  bool _isDeleting       = false;
  String? _error;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ─── Load Profile ───────────────────────────────────────────────────────────
  Future<void> _loadProfile() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await ApiService.getProfile();
      // ✅ Always sync badge to SharedPreferences so witness/rating features stay current
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('badge', data['badge'] ?? 'none');
      await prefs.setString('user_role', data['role'] ?? '');
      await prefs.setString('user_id', data['id']?.toString() ?? '');
      await prefs.setBool('is_verified', data['is_verified'] ?? false);
      if (mounted) setState(() { _profile = data; _isLoading = false; });
      final role = data['role'] ?? '';
      if (role == 'admin' || role == 'super_admin') _loadPendingCount();
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _loadPendingCount() async {
    try {
      final list = await ApiService.getPendingVerifications();
      if (mounted) setState(() => _pendingCount = list.length);
    } catch (_) {}
  }

  // ─── Profile Photo Upload ───────────────────────────────────────────────────
  // Context-aware warning, then gallery, then Cloudinary upload.
  // Handles badge auto-revoke when a verified user changes their DP.
  Future<void> _handlePhotoUpload() async {
    final currentBadge = _profile?['badge'] ?? 'none';                                  // ✅ ADD
    final isVerified   = currentBadge == 'durbe_niwasi';                                // ✅ ADD

    // ─── Step 1 — warning dialog (extra danger warning if verified) ───
    final proceed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isVerified ? 'Change Profile Photo?' : 'Upload Profile Photo',                // ✅ CHANGE
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ ADD — red badge-revoke warning shown only to verified users
            if (isVerified) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('⚠️', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your Durbe Niwasi badge will be removed. You will need to claim residency again and admin will re-approve you.',
                        style: GoogleFonts.inter(
                          fontSize: 12, color: const Color(0xFF991B1B),
                          fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            // Face-visible reminder (always shown)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📸', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Upload a clear photo where your face is fully visible. '
                      'Admin will use this photo to confirm you are a Durbe resident.',
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isVerified ? Colors.red : AppColors.primary,             // ✅ CHANGE
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              isVerified ? 'Continue & remove badge' : 'Choose Photo',                  // ✅ CHANGE
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (proceed != true) return;

    // ─── Step 2 — pick from gallery ───
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);

    try {
      // ─── Step 3 — upload to Cloudinary ───
      final file = File(picked.path);
      final url  = await CloudinaryService.uploadImage(file);

      // ─── Step 4 — save URL to backend (now returns badge_revoked flag) ───
      final result       = await ApiService.updateProfilePhoto(url);                    // ✅ CHANGE
      final badgeRevoked = result['badge_revoked'] == true;                             // ✅ ADD

      // ─── Step 5 — refresh profile ───
      await _loadProfile();

      if (mounted) {
        if (badgeRevoked) {
          // ✅ ADD — different message when badge was auto-revoked
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Photo updated. Your Durbe Niwasi badge has been removed.',
                style: GoogleFonts.inter(),
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Profile photo updated!', style: GoogleFonts.inter()),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e', style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  // ─── Claim Residency ────────────────────────────────────────────────────────
  Future<void> _handleClaimResidency() async {
    final badge = _profile?['badge'] ?? 'none';
    if (badge == 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Your request is pending. Admin will review soon.',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Must have a profile photo before claiming
    final photoUrl = _profile?['profile_photo_url'];
    if (photoUrl == null || (photoUrl as String).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please upload a profile photo first so admin can identify you.',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Claim Durbe Residency',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700)),
        content: Text(
          'Your profile photo will be shown to the admin for verification. '
          'Once approved, you can file complaints and rate officials.',
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
            child: Text('Submit Claim', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService.claimResidency(profilePhotoUrl: photoUrl);
      await _loadProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Claim submitted! Admin will review and approve soon.',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString(), style: GoogleFonts.inter()),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // ─── Logout ─────────────────────────────────────────────────────────────────
  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Logout', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to logout?', style: GoogleFonts.inter(fontSize: 13)),
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
            child: Text('Logout', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  // ─── Delete Account ─────────────────────────────────────────────────────────
  // Three-step flow:
  //   1. Confirm intent
  //   2. Enter password → backend verifies + sends OTP
  //   3. Enter OTP      → backend verifies password+OTP again + soft-deletes
  Future<void> _handleDeleteAccount() async {
    // ─── Step 1 — confirm intent ───
    final step1 = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Account',
            style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.w700, color: Colors.red)),
        content: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFCA5A5)),
          ),
          child: Text(
            '⚠️ This will permanently delete your account. Your existing posts and votes will remain but will show as "Deleted user". This cannot be undone.',
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF991B1B)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Continue',
                style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (step1 != true) return;

    // ─── Step 2 — enter password, send OTP ───
    final passwordController = TextEditingController();
    String? sentOtp;  // dev mode: backend echoes OTP back for testing

    final password = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        bool sending = false;
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Confirm Your Password',
                style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Enter your account password. We will send an OTP to your phone.',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280))),
                const SizedBox(height: 10),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: GoogleFonts.inter(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: sending ? null : () => Navigator.pop(dialogCtx, null),
                child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: sending
                    ? null
                    : () async {
                        final pw = passwordController.text.trim();
                        if (pw.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Enter your password',
                                style: GoogleFonts.inter())),
                          );
                          return;
                        }
                        setLocal(() => sending = true);
                        try {
                          final res = await ApiService.requestAccountDeletion(pw);
                          sentOtp = res['otp']?.toString();
                          if (dialogCtx.mounted) Navigator.pop(dialogCtx, pw);
                        } catch (e) {
                          setLocal(() => sending = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(e.toString(), style: GoogleFonts.inter()),
                                backgroundColor: Colors.red),
                          );
                        }
                      },
                child: sending
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Send OTP', style: GoogleFonts.inter(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
    if (password == null) return;

    // ─── Step 3 — enter OTP, finalize delete ───
    final otpController = TextEditingController();
    if (sentOtp != null) otpController.text = sentOtp!;  // dev convenience

    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Enter OTP',
                style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('We sent an OTP to your phone. Enter it to finalize deletion.',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280))),
                const SizedBox(height: 10),
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'OTP',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: _isDeleting ? null : () => Navigator.pop(dialogCtx, false),
                child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isDeleting
                    ? null
                    : () async {
                        final otp = otpController.text.trim();
                        if (otp.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Enter the OTP',
                                style: GoogleFonts.inter())),
                          );
                          return;
                        }
                        setState(() => _isDeleting = true);
                        try {
                          await ApiService.deleteAccount(password: password, otpCode: otp);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.clear();
                          if (dialogCtx.mounted) Navigator.pop(dialogCtx, true);
                        } catch (e) {
                          setState(() => _isDeleting = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(e.toString(), style: GoogleFonts.inter()),
                                backgroundColor: Colors.red),
                          );
                        }
                      },
                child: _isDeleting
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Delete Forever', style: GoogleFonts.inter(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );

    if (deleted == true && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ Option B: light green background throughout
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0FDF4),
        elevation: 0,
        title: Text(
          'My Profile',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _loadProfile,
          ),
        ],
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  // ─── Error State ─────────────────────────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          Text('Failed to load profile', style: GoogleFonts.inter(color: Colors.red)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loadProfile,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text('Retry', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── Main Content ────────────────────────────────────────────────────────────
  Widget _buildContent() {
    final profile  = _profile!;
    final name     = profile['display_name'] ?? profile['full_name'] ?? 'User';
    final phone    = profile['phone'] ?? '';
    final role     = profile['role']  ?? 'user';
    final badge    = profile['badge'] ?? 'none';
    final photoUrl = profile['profile_photo_url'] as String?;
    final verifiedOn = profile['verified_at'] != null
        ? _formatDate(profile['verified_at'])
        : null;
    final memberSince = profile['created_at'] != null
        ? _formatDate(profile['created_at'])
        : 'Unknown';

    return SingleChildScrollView(
      child: Column(
        children: [
          // ── Top section: avatar + name + chips ─────────────────────────
          _buildTopSection(name, phone, role, badge, photoUrl),

          const Divider(color: Color(0xFFD1FAE5), thickness: 1, height: 1),

          // ── Body cards ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Column(
              children: [
                if (role == 'admin' || role == 'super_admin') ...[
                  _buildAdminCard(),
                  const SizedBox(height: 10),
                  ],

                // Badge card
                _buildBadgeCard(badge, verifiedOn),

                const SizedBox(height: 10),

                // Account Info card
                _buildAccountInfoCard(memberSince, verifiedOn),

                const SizedBox(height: 10),

                // Permissions card
                _buildPermissionsCard(badge),

                const SizedBox(height: 10),

                // Claim residency button (only if not verified)
                if (badge == 'none' || badge == 'pending')
                  _buildClaimButton(badge),

                if (badge == 'none' || badge == 'pending')
                  const SizedBox(height: 10),

                // Logout button — large and prominent
                _buildLogoutButton(),

                const SizedBox(height: 10),

                // Delete account — small, easy to miss (intentional)
                _buildDeleteButton(),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Top Section ─────────────────────────────────────────────────────────────
  Widget _buildTopSection(
      String name, String phone, String role, String badge, String? photoUrl) {
    return Container(
      color: const Color(0xFFF0FDF4),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        children: [
          // Avatar — tappable to upload photo
          GestureDetector(
            onTap: _handlePhotoUpload,
            child: Stack(
              children: [
                // ✅ Avatar circle
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFBBF7D0),
                    border: Border.all(color: AppColors.primary, width: 2.5),
                    image: (photoUrl != null && photoUrl.isNotEmpty)
                        ? DecorationImage(
                            image: NetworkImage(photoUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: (photoUrl == null || photoUrl.isEmpty)
                      ? Center(
                          child: Text(
                            name[0].toUpperCase(),
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : null,
                ),

                // ✅ Upload spinner overlay
                if (_isUploadingPhoto)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.4),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        ),
                      ),
                    ),
                  ),

                // ✅ Badge dot (verified check)
                if (badge == 'durbe_niwasi')
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                        border: Border.all(color: const Color(0xFFF0FDF4), width: 2),
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 12),
                    ),
                  ),

                // ✅ Camera icon when no photo — hint to upload
                if (photoUrl == null || photoUrl.isEmpty)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: AppColors.primary, width: 1.5),
                      ),
                      child: Icon(Icons.camera_alt_rounded,
                          color: AppColors.primary, size: 11),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Name
          Text(
            name,
            style: GoogleFonts.playfairDisplay(
                fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF111827)),
          ),

          const SizedBox(height: 3),

          // Phone — only visible because this is /me (your own profile)
          Text(
            '+91 $phone',
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
          ),

          const SizedBox(height: 8),

          // Role + badge chips
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (badge == 'durbe_niwasi')
                _chip('🏠 Durbe Niwasi', const Color(0xFFDCFCE7),
                    AppColors.primary, const Color(0xFFBBF7D0)),
              if (badge == 'durbe_niwasi') const SizedBox(width: 6),
              if (badge == 'pending')
                _chip('⏳ Pending Verification', const Color(0xFFFFFBEB),
                    const Color(0xFFD97706), const Color(0xFFFCD34D)),
              if (badge == 'pending') const SizedBox(width: 6),
              _chip(
                _roleLabel(role),
                const Color(0xFFDBEAFE),
                const Color(0xFF1D4ED8),
                const Color(0xFFBFDBFE),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Badge Card ───────────────────────────────────────────────────────────────
  Widget _buildBadgeCard(String badge, String? verifiedOn) {
    if (badge == 'durbe_niwasi') {
      return _card(
        color: const Color(0xFFDCFCE7),
        border: const Color(0xFF86EFAC),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🏠', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Durbe Niwasi',
                      style: GoogleFonts.playfairDisplay(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                  Text('Be aware, raise your voice, and contribute to village development.',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: const Color(0xFF374151))),
                  const SizedBox(height: 4),
                  Text(
                    'You can file complaints, rate officials and bring development proposals.',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: const Color(0xFF374151)),
                  ),
                  
                  if (verifiedOn != null) ...[
                    const SizedBox(height: 4),
                    Text('✅ Verified on $verifiedOn',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (badge == 'pending') {
      return _card(
        color: const Color(0xFFFFFBEB),
        border: const Color(0xFFFCD34D),
        child: Row(
          children: [
            const Text('⏳', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Verification Pending',
                      style: GoogleFonts.playfairDisplay(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: const Color(0xFFD97706))),
                  Text(
                    'Admin will review your profile photo and approve soon.',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: const Color(0xFF374151)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // badge == 'none'
    return _card(
      color: const Color(0xFFF9FAFB),
      border: const Color(0xFFE5E7EB),
      child: Row(
        children: [
          const Text('🔓', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No Residency Badge',
                    style: GoogleFonts.playfairDisplay(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: const Color(0xFF374151))),
                Text(
                  'Claim your Durbe Niwasi badge to vote and rate officials.',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: const Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Account Info Card ────────────────────────────────────────────────────────
  Widget _buildAccountInfoCard(String memberSince, String? verifiedOn) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('Account Info'),
          const SizedBox(height: 10),
          // ✅ Coloured icon boxes (fix #2)
          _infoRow(icon: '📍', bg: const Color(0xFFDCFCE7), label: 'Durbe, Gaya, Bihar'),
          _infoRow(icon: '📅', bg: const Color(0xFFDBEAFE), label: 'Member since  $memberSince'),
          if (verifiedOn != null)
            _infoRow(icon: '✅', bg: const Color(0xFFDCFCE7), label: 'Verified on  $verifiedOn'),
        ],
      ),
    );
  }

  // ─── Permissions Card ─────────────────────────────────────────────────────────
  Widget _buildPermissionsCard(String badge) {
    final isVerified = badge == 'durbe_niwasi';
    final perms = [
      {'icon': '📖', 'label': 'Browse all village information', 'always': true},
      {'icon': '📢', 'label': 'File complaints (Gram Awaaz)',   'always': false},
      {'icon': '📋', 'label': 'View government schemes',        'always': true},
      {'icon': '💰', 'label': 'Check crop prices & weather',   'always': true},
      {'icon': '💼', 'label': 'View and apply for job posts',   'always': true},
      {'icon': '⭐', 'label': 'Rate officials (Neta Report Card)','always': false},
      {'icon': '🏗️', 'label': 'Submit Vikas Prastav proposals',  'always': false},
    ];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('What you can do'),
          const SizedBox(height: 10),
          // ✅ 2-column permission grid (fix #2)
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 3.0,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            children: perms.map((p) {
              final unlocked = p['always'] == true || isVerified;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: unlocked
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: unlocked
                        ? const Color(0xFFBBF7D0)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Row(
                  children: [
                    Text(p['icon'] as String, style: const TextStyle(fontSize: 11)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        p['label'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: unlocked
                              ? const Color(0xFF166534)
                              : const Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      unlocked ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                      size: 12,
                      color: unlocked ? AppColors.primary : const Color(0xFFD1D5DB),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── Claim Residency Button ───────────────────────────────────────────────────
  Widget _buildClaimButton(String badge) {
    final isPending = badge == 'pending';
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: isPending ? null : _handleClaimResidency,
        icon: Icon(
          isPending ? Icons.hourglass_top_rounded : Icons.verified_user_rounded,
          size: 16,
        ),
        label: Text(
          isPending ? 'Verification Pending…' : 'Claim Durbe Residency',
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: isPending ? Colors.grey : AppColors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }

  // ─── Admin Panel Card — only shown to admin/super_admin ──────────────────────
  Widget _buildAdminCard() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
      ).then((_) => _loadPendingCount()),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          border: Border.all(color: const Color(0xFFFCD34D)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(child: Text('🛡️', style: TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Admin Panel',
                      style: GoogleFonts.playfairDisplay(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: const Color(0xFF92400E))),
                  Text('Manage village & verifications',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: const Color(0xFF78350F))),
                ],
              ),
            ),
            if (_pendingCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$_pendingCount pending',
                    style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: Color(0xFF92400E)),
          ],
        ),
      ),
    );
  }

  // ─── Logout Button — large, prominent ────────────────────────────────────────
  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _handleLogout,
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: Text(
          'Logout',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFDC2626),
          side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: Colors.white,
        ),
      ),
    );
  }

  // ─── Delete Button — small, easy to miss (intentional) ───────────────────────
  Widget _buildDeleteButton() {
    return _isDeleting
        ? const Center(child: CircularProgressIndicator(color: Colors.red))
        : GestureDetector(
            onTap: _handleDeleteAccount,
            child: Text(
              'Delete my account',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF9CA3AF),
                decoration: TextDecoration.underline,
                decorationColor: const Color(0xFF9CA3AF),
              ),
            ),
          );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Widget _card({
    required Widget child,
    Color color = Colors.white,
    Color border = const Color(0xFFE5E7EB),
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _cardTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _infoRow({required String icon, required Color bg, required String label}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          // ✅ Coloured icon box
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 14))),
          ),
          const SizedBox(width: 10),
          Text(label,
              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF374151))),
        ],
      ),
    );
  }

  Widget _chip(String label, Color bg, Color text, Color border) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
            fontSize: 10, fontWeight: FontWeight.w600, color: text),
      ),
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

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${dt.day} ${months[dt.month]} ${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}