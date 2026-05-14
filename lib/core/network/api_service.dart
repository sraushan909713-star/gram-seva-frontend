// lib/core/network/api_service.dart
// ─────────────────────────────────────────────────────────────
// Central API service for all HTTP calls to the FastAPI backend.
// All endpoints go through here — one place to manage headers,
// base URL, and error handling.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class ApiService {

  // — Stored JWT token ──────────────────────────────────────
  // Retrieved from SharedPreferences on each request
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.tokenKey);
  }

  // — Save token after login/register ──────────────────────
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
  }

  // — Clear token on logout ─────────────────────────────────
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.userIdKey);
    await prefs.remove(AppConstants.userNameKey);
    await prefs.remove(AppConstants.userRoleKey);
    await prefs.remove(AppConstants.isVerifiedKey);
  }

  // — Standard headers ──────────────────────────────────────
  static Map<String, String> _headers({String? token}) {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── AUTH ENDPOINTS ────────────────────────────────────────

  // POST /auth/send-otp
  static Future<Map<String, dynamic>> sendOtp(String phone) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/auth/send-otp'),
      headers: _headers(),
      body: jsonEncode({'phone': phone, 'purpose': 'registration'}),
    );
    return jsonDecode(response.body);
  }

  // POST /auth/register
  static Future<Map<String, dynamic>> register({
    required String phone,
    required String fullName,
    required String otpCode,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/auth/register'),
      headers: _headers(),
      body: jsonEncode({
        'phone': phone,
        'name': fullName,
        'otp_code': otpCode,
        'password': password,
      }),
    );
    return {'statusCode': response.statusCode, ...jsonDecode(response.body)};
  }

  // POST /auth/login
  static Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/auth/login'),
      headers: _headers(),
      body: jsonEncode({'phone': phone, 'password': password}),
    );
    return {'statusCode': response.statusCode, ...jsonDecode(response.body)};
  }

  // ── CONTACTS ENDPOINTS ────────────────────────────────────

  // GET /contacts/?category=...
  static Future<List<dynamic>> getContacts({String? category}) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/contacts/').replace(
      queryParameters: {
        'village_id': AppConstants.villageId,
        if (category != null) 'category': category,
      },
    );
    final response = await http.get(uri, headers: _headers());
    return jsonDecode(response.body);
  }

  // GET /vendor-listings/
static Future<List<dynamic>> getVendorListings({String? category}) async {
  final uri = Uri.parse('${AppConstants.baseUrl}/vendor-listings/').replace(
    queryParameters: {
      'village_id': AppConstants.villageId,
      if (category != null) 'category': category,
    },
  );
  final response = await http.get(uri, headers: _headers());
  return jsonDecode(response.body);
}

  // ── SCHEMES ENDPOINTS ─────────────────────────────────────

  // GET /schemes/
  static Future<List<dynamic>> getSchemes({String? category, String? search}) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/schemes/').replace(
      queryParameters: {
        'village_id': AppConstants.villageId,
        if (category != null) 'category': category,
        if (search != null)   'search': search,
      },
    );
    final response = await http.get(uri, headers: _headers());
    return jsonDecode(response.body);
  }

  // ── GUIDES ENDPOINTS ──────────────────────────────────────

  // GET /guides/
  static Future<List<dynamic>> getGuides({String? category}) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/guides/').replace(
      queryParameters: {
        'village_id': AppConstants.villageId,
        if (category != null) 'category': category,
      },
    );
    final response = await http.get(uri, headers: _headers());
    return jsonDecode(response.body);
  }

  // ── WEATHER ENDPOINTS ─────────────────────────────────────

  // GET /weather/rain-alert
  static Future<Map<String, dynamic>> getRainAlerts() async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/weather/rain-alert'),
      headers: _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('GET /weather/rain-alert failed: ${response.statusCode}');
  }

  // GET /gram-awaaz/?department=xxx
  // Public — no token needed. Optional department filter.
  // Returns list sorted by upvote_count DESC (most urgent first).
  static Future<List<dynamic>> getGramAwaazPosts({String? department}) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/gram-awaaz').replace(
      queryParameters: department != null ? {'department': department} : null, // ✅ CHANGE: pass null instead of empty map
    );
    final response = await http.get(uri, headers: _headers());

    // ✅ ADD: handle non-200 responses so we see the real error
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('GET /gram-awaaz failed: ${response.statusCode} — ${response.body}');
    }
  }

  // POST /gram-awaaz
  // Login required. Creates a new complaint post.
  // Returns {'statusCode': ..., ...post fields}
  static Future<Map<String, dynamic>> createGramAwaazPost({
    required String title,
    required String description,
    required String location,
    required int affectedCount,       // ✅ int — backend schema enforces this
    required String department,       // ✅ enum value e.g. "panchayat"
    required String demand,
    required String photoUrl1,         // ✅ mandatory
    String? photoUrl2,                 // ✅ optional
    String? photoUrl3,                 // ✅ optional
    String? photoUrl4,                // ✅ optional
  }) async {
    final token = await _getToken();  // ✅ uses private _getToken() like other methods
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/gram-awaaz'),
      headers: _headers(token: token),
      body: jsonEncode({
        'title':          title,
        'description':    description,
        'location':       location,
        'affected_count': affectedCount,
        'department':     department,
        'demand':         demand,
        'photo_url_1':    photoUrl1,           // ✅ CHANGED
        if (photoUrl2 != null) 'photo_url_2': photoUrl2,  // ✅ ADD
        if (photoUrl3 != null) 'photo_url_3': photoUrl3,  // ✅ ADD
        if (photoUrl4 != null) 'photo_url_4': photoUrl4,  // ✅ ADD
      }),
    );
    return {'statusCode': response.statusCode, ...jsonDecode(response.body)};
  }

  // POST /gram-awaaz/{postId}/upvote
  // Login required. Backend returns 400 if already upvoted.
  // Returns {'statusCode': ..., 'message': ..., 'upvote_count': int}
  static Future<Map<String, dynamic>> upvoteGramAwaazPost(String postId) async {
    final token = await _getToken(); // ✅ uses private _getToken()
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/gram-awaaz/$postId/upvote'),
      headers: _headers(token: token),
    );
    return {'statusCode': response.statusCode, ...jsonDecode(response.body)};
  }

  // — VIKAS PRASTAV ENDPOINTS ───────────────────────────────────

  // GET /vikas-prastav?category=xxx
  // Public — no token needed. Optional category filter.
  // Returns proposals sorted by upvote_count DESC.
  static Future<List<dynamic>> getVikasPrastavPosts({String? category}) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/vikas-prastav').replace(
      queryParameters: category != null ? {'category': category} : null,
    );
    final response = await http.get(uri, headers: _headers());
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('GET /vikas-prastav failed: ${response.statusCode}');
    }
  }

  // POST /vikas-prastav
  // Login required. Creates a new development proposal.
  static Future<Map<String, dynamic>> createVikasPrastavPost({
    required String title,
    required String description,
    required String location,
    required String category,
    required String photoUrl1,         // ✅ mandatory
    String? photoUrl2,                 // ✅ optional
    String? photoUrl3,                 // ✅ optional
    String? photoUrl4,                 // ✅ optional
    String? estimatedCost,          
    String? fundingSource,          
  }) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/vikas-prastav'),
      headers: _headers(token: token),
      body: jsonEncode({
        'title':           title,
        'description':     description,
        'location':        location,
        'category':        category,
        'photo_url_1':     photoUrl1,          // ✅ CHANGED
        if (photoUrl2 != null) 'photo_url_2': photoUrl2,
        if (photoUrl3 != null) 'photo_url_3': photoUrl3,
        if (photoUrl4 != null) 'photo_url_4': photoUrl4,
        if (estimatedCost != null) 'estimated_cost': estimatedCost,
        if (fundingSource != null)  'funding_source': fundingSource,
      }),
    );
    return {'statusCode': response.statusCode, ...jsonDecode(response.body)};
  }

  // POST /vikas-prastav/{proposalId}/upvote
  // Login required. Backend returns 400 if already upvoted.
  static Future<Map<String, dynamic>> upvoteVikasPrastav(String proposalId) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/vikas-prastav/$proposalId/upvote'),
      headers: _headers(token: token),
    );
    return {'statusCode': response.statusCode, ...jsonDecode(response.body)};
  }

  // — SCHEMES ENDPOINTS ─────────────────────────────────────────

  // GET /schemes/{id}
  // Public — returns full scheme detail including eligibility, how_to_apply
  static Future<Map<String, dynamic>> getSchemeDetail(String schemeId) async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/schemes/$schemeId'),
      headers: _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('GET /schemes/$schemeId failed: ${response.statusCode}');
  }

  // GET /community-members/scheme/{schemeId}
  // Public — returns list of people availing this scheme
  static Future<List<dynamic>> getSchemeMembers(String schemeId) async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/community-members/scheme/$schemeId'),
      headers: _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('GET /community-members/scheme failed: ${response.statusCode}');
  }

  // GET /gram-awaaz/{postId} — full post detail including description + demand
  static Future<Map<String, dynamic>> getGramAwaazDetail(String postId) async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/gram-awaaz/$postId'),
      headers: _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('GET /gram-awaaz/$postId failed: ${response.statusCode}');
  }

  // GET /vikas-prastav/{proposalId} — full proposal detail
  static Future<Map<String, dynamic>> getVikasPrastavDetail(String proposalId) async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/vikas-prastav/$proposalId'),
      headers: _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('GET /vikas-prastav/$proposalId failed: ${response.statusCode}');
  }

  // ── NETA REPORT CARD ENDPOINTS ────────────────────────────────
  // Add these methods to your ApiService class in:
  // lib/core/network/api_service.dart

  // GET /neta/window/status
  static Future<Map<String, dynamic>> getNetaWindowStatus() async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/neta/window/status'),
      headers: _headers(),
    );
    return jsonDecode(response.body);
  }

  // GET /neta
  static Future<List<dynamic>> getNetaList() async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/neta'),
      headers: _headers(),
    );
    final data = jsonDecode(response.body);
    return data is List ? data : [];
  }

  // GET /neta/{neta_id}
  static Future<Map<String, dynamic>> getNetaDetail(String netaId) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/neta/$netaId'),
      headers: _headers(token: token),
    );
    return jsonDecode(response.body);
  }

  // GET /neta/{neta_id}/history
  static Future<Map<String, dynamic>> getNetaHistory(String netaId) async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/neta/$netaId/history'),
      headers: _headers(),
    );
    return jsonDecode(response.body);
  }

  // POST /neta/{neta_id}/rate
  static Future<Map<String, dynamic>> submitNetaRating({
    required String netaId,
    required int stars,
  }) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/neta/$netaId/rate'),
      headers: _headers(token: token),
      body: jsonEncode({'stars': stars}),
    );
    return jsonDecode(response.body);
  }

  // ── JOB ALERTS ENDPOINTS ─────────────────────────────────────────

  // GET /job-alerts  (optional category filter)
  static Future<List<dynamic>> getJobAlerts({String? category}) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/job-alerts').replace(
      queryParameters: category != null ? {'category': category} : null,
    );
    final response = await http.get(uri, headers: _headers());
    final data = jsonDecode(response.body);
    return data is List ? data : [];
  }

  // GET /job-alerts/{id}
  static Future<Map<String, dynamic>> getJobAlertDetail(String jobId) async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/job-alerts/$jobId'),
      headers: _headers(),
    );
    return jsonDecode(response.body);
  }

  // GET /job-alerts/{id}/applicants
  static Future<List<dynamic>> getJobApplicants(String jobId) async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/job-alerts/$jobId/applicants'),
      headers: _headers(),
    );
    final data = jsonDecode(response.body);
    return data is List ? data : [];
  }

  // ── GUIDES ENDPOINTS ─────────────────────────────────────────────
 
  // GET /guides/{id}
  static Future<Map<String, dynamic>> getGuideDetail(String guideId) async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/guides/$guideId'),
      headers: _headers(),
    );
    return jsonDecode(response.body);
  }

  // GET /banners/
  static Future<List<dynamic>> getBanners() async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/banners/'),
      headers: _headers(),
    );
    final data = jsonDecode(response.body);
    return data is List ? data : [];
  }

  // GET /auth/me — fetch logged-in user's full profile
  static Future<Map<String, dynamic>> getProfile() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/auth/me'),
      headers: _headers(token: token),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load profile: ${response.statusCode}');
  }
 
  // POST /auth/claim-residency — user claims Durbe residency
  static Future<Map<String, dynamic>> claimResidency({
    required String profilePhotoUrl,
  }) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/auth/claim-residency'),
      headers: _headers(token: token),
      body: jsonEncode({'profile_photo_url': profilePhotoUrl}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw Exception(data['detail'] ?? 'Failed to claim residency');
  }

  // PATCH /auth/update-photo
  // Returns the response body. Frontend uses badge_revoked flag.
  // If user was verified (badge=durbe_niwasi) when changing DP,
  // backend auto-revokes and returns: { message, badge_revoked: true, new_badge: 'none' }
  static Future<Map<String, dynamic>> updateProfilePhoto(String photoUrl) async {  // ✅ CHANGE — returns Map now
    final token = await _getToken();
    final response = await http.patch(
      Uri.parse('${AppConstants.baseUrl}/auth/update-photo'),
      headers: _headers(token: token),
      body: jsonEncode({'profile_photo_url': photoUrl}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update photo: ${response.body}');
    }
    return jsonDecode(response.body);
  }

  // POST /auth/request-account-deletion
  // Step 1 of self-delete: backend verifies password, sends OTP.
  // Returns { message, otp } — otp is echoed back for dev testing only.
  static Future<Map<String, dynamic>> requestAccountDeletion(String password) async {  // ✅ NEW
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/auth/request-account-deletion'),
      headers: _headers(token: token),
      body: jsonEncode({'password': password}),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(body['detail'] ?? 'Failed to request deletion');
    }
    return body;
  }

  // POST /auth/delete-account
  // Step 2: backend verifies password + OTP, soft-deletes + anonymizes PII.
  static Future<void> deleteAccount({                                                  // ✅ CHANGE — new signature
    required String password,
    required String otpCode,
  }) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/auth/delete-account'),
      headers: _headers(token: token),
      body: jsonEncode({'password': password, 'otp_code': otpCode}),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Failed to delete account');
    }
  }

  // GET /auth/pending-verifications
  static Future<List<dynamic>> getPendingVerifications() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/auth/pending-verifications'),
      headers: _headers(token: token),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load pending verifications');
  }
 
  // POST /auth/verify/{userId}
  static Future<void> approveUser(String userId) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/auth/verify/$userId'),
      headers: _headers(token: token),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Failed to approve user');
    }
  }
 
  // POST /auth/revoke/{userId}
  static Future<void> revokeUser(String userId) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/auth/revoke/$userId'),
      headers: _headers(token: token),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Failed to revoke user');
    }
  }
 
  // GET /community/members
  static Future<List<dynamic>> getCommunityMembers() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/auth/users'),
      headers: _headers(token: token),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load community members');
  }

  // ADD these 6 methods to lib/core/network/api_service.dart
  // Paste after your existing methods, before the closing }

  // GET /promises
  static Future<List<dynamic>> getPromises() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/promises'),
      headers: _headers(token: token),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load promises');
  }

  // GET /promises/{id}
  static Future<Map<String, dynamic>> getPromise(String promiseId) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/promises/$promiseId'),
      headers: _headers(token: token),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load promise');
  }

  // GET /promises/{id}/witnesses
  static Future<List<dynamic>> getPromiseWitnesses(String promiseId) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/promises/$promiseId/witnesses'),
      headers: _headers(token: token),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load witnesses');
  }

  // POST /promises/{id}/witness
  static Future<void> witnessPromise(String promiseId) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/promises/$promiseId/witness'),
      headers: _headers(token: token),
    );
    if (response.statusCode != 201) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Failed to confirm witness');
    }
  }

  // POST /promises
  static Future<void> createPromise(Map<String, dynamic> data) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/promises'),
      headers: _headers(token: token),
      body: jsonEncode(data),
    );
    if (response.statusCode != 201) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Failed to create promise');
    }
  }

  // PATCH /promises/{id}/status
  static Future<void> updatePromiseStatus(
      String promiseId, String status) async {
    final token = await _getToken();
    final response = await http.patch(
      Uri.parse('${AppConstants.baseUrl}/promises/$promiseId/status'),
      headers: _headers(token: token),
      body: jsonEncode({'status': status}),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Failed to update status');
    }
  }

  // DELETE /promises/{id}
  static Future<void> deletePromise(String promiseId) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('${AppConstants.baseUrl}/promises/$promiseId'),
      headers: _headers(token: token),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Failed to delete promise');
    }
  }

  // ADD these 3 methods to lib/core/network/api_service.dart
  // Paste after your existing methods, before the closing }

  // POST /neta/window — super admin only
  static Future<void> createRatingWindow({
    required String label,
    required DateTime opensAt,
    required DateTime closesAt,
  }) async {
    final token = await _getToken();
    final uri = Uri.parse('${AppConstants.baseUrl}/neta/window')
        .replace(queryParameters: {
      'label':     label,
      'opens_at':  opensAt.toIso8601String(),
      'closes_at': closesAt.toIso8601String(),
    });
    final response = await http.post(uri, headers: _headers(token: token));
    if (response.statusCode != 201) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Failed to create window');
    }
  }

  // PATCH /neta/window/hide — super admin only
  static Future<void> hideRatingWindow() async {
    final token = await _getToken();
    final response = await http.patch(
      Uri.parse('${AppConstants.baseUrl}/neta/window/hide'),
      headers: _headers(token: token),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Failed to hide window');
    }
  }

  // PATCH /neta/window/unhide — super admin only
  static Future<void> unhideRatingWindow(String windowId) async {
    final token = await _getToken();
    final uri = Uri.parse('${AppConstants.baseUrl}/neta/window/unhide')
        .replace(queryParameters: {'window_id': windowId});
    final response = await http.patch(uri, headers: _headers(token: token));
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Failed to unhide window');
    }
  }

  static Future<void> deleteGramAwaazPost(String postId) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('${AppConstants.baseUrl}/gram-awaaz/$postId'),
      headers: _headers(token: token),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Failed to delete post');
    }
  }

  static Future<void> deleteVikasPrastavPost(String proposalId) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('${AppConstants.baseUrl}/vikas-prastav/$proposalId'),
      headers: _headers(token: token),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Failed to delete proposal');
    }
  }

  // POST /job-alerts — admin only
  static Future<void> createJobAlert(Map<String, dynamic> data) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/job-alerts'),
      headers: _headers(token: token),
      body: jsonEncode(data),
    );
    if (response.statusCode != 201) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Failed to create job');
    }
  }

  // DELETE /job-alerts/{id}
  static Future<void> deleteJobAlert(String jobId) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('${AppConstants.baseUrl}/job-alerts/$jobId'),
      headers: _headers(token: token),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Failed to delete job');
    }
  }

  // POST /job-alerts/{id}/applicants
  static Future<void> addJobApplicant(
      String jobId, Map<String, dynamic> data) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/job-alerts/$jobId/applicants'),
      headers: _headers(token: token),
      body: jsonEncode(data),
    );
    if (response.statusCode != 201) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Failed to add applicant');
    }
  }

  static Future<void> createVendorListing(Map<String, dynamic> data) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/vendor-listings/'),
      headers: _headers(token: token),
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Failed to create listing');
    }
  }

  static Future<void> updateVendorListing(String id, Map<String, dynamic> data) async {
    final token = await _getToken();
    final response = await http.put(
      Uri.parse('${AppConstants.baseUrl}/vendor-listings/$id'),
      headers: _headers(token: token),
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Failed to update listing');
    }
  }

  static Future<void> deleteVendorListing(String id) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('${AppConstants.baseUrl}/vendor-listings/$id'),
      headers: _headers(token: token),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Failed to delete listing');
    }
  }

  static Future<Map<String, dynamic>> promoteToVendor({
    required String phone,
    required String shopName,
  }) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/auth/promote-vendor'),
      headers: _headers(token: token),
      body: jsonEncode({'phone': phone, 'shop_name': shopName}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    final body = jsonDecode(response.body);
    throw Exception(body['detail'] ?? 'Failed to promote vendor');
  }

  static Future<List<dynamic>> getVendors() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/auth/users?role=vendor'),
      headers: _headers(token: token),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load vendors');
  }

  // PATCH /auth/users/{id}/role
  static Future<void> changeUserRole(String userId, String role) async {
    final token = await _getToken();
    final response = await http.patch(
      Uri.parse('${AppConstants.baseUrl}/auth/users/$userId/role'),
      headers: _headers(token: token),
      body: jsonEncode({'role': role}),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Failed to change role');
    }
  }

  // POST /banners/
  static Future<void> createBanner(Map<String, dynamic> data) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/banners/'),
      headers: _headers(token: token),
      body: jsonEncode(data),
    );
    if (response.statusCode != 201) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Failed to create banner');
    }
  }

  // DELETE /banners/{id}
  static Future<void> deleteBanner(String bannerId) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('${AppConstants.baseUrl}/banners/$bannerId'),
      headers: _headers(token: token),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Failed to delete banner');
    }
  }

  // POST /neta/leaders
  static Future<void> createNeta(Map<String, dynamic> data) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/neta/leaders'),
      headers: _headers(token: token),
      body: jsonEncode(data),
    );
    if (response.statusCode != 201) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Failed to add leader');
    }
  }

  static Future<void> createContact(Map<String, dynamic> data) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/contacts/'),
      headers: _headers(token: token),
      body: jsonEncode(data),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      String detail = 'Failed to save. Please try again.';
      if (response.body.isNotEmpty) {
        try {
          final body = jsonDecode(response.body);
          detail = body['detail'] ?? detail;
        } catch (_) {}
      }
      throw Exception(detail);
    }
  }

  static Future<void> createScheme(Map<String, dynamic> data) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/schemes'),
      headers: _headers(token: token),
      body: jsonEncode(data),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      String detail = 'Failed to save. Please try again.';
      if (response.body.isNotEmpty) {
        try {
          final body = jsonDecode(response.body);
          detail = body['detail'] ?? detail;
        } catch (_) {}
      }
      throw Exception(detail);
    }
  }

  // DELETE /schemes/{id}
  // Soft-deletes the scheme (backend sets is_active=False).
  // Backend gates on admin/super_admin role.
  static Future<void> deleteScheme(String schemeId) async {                       // ✅ ADD
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('${AppConstants.baseUrl}/schemes/$schemeId'),
      headers: _headers(token: token),
    );
    if (response.statusCode != 200) {
      String detail = 'Failed to delete scheme.';
      if (response.body.isNotEmpty) {
        try {
          final body = jsonDecode(response.body);
          detail = body['detail'] ?? detail;
        } catch (_) {}
      }
      throw Exception(detail);
    }
  }

  static Future<void> createGuide(Map<String, dynamic> data) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/guides/'),
      headers: _headers(token: token),
      body: jsonEncode(data),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      String detail = 'Failed to save. Please try again.';
      if (response.body.isNotEmpty) {
        try {
          final body = jsonDecode(response.body);
          detail = body['detail'] ?? detail;
        } catch (_) {}
      }
      throw Exception(detail);
    }
  }

  // POST /community-members — add scheme beneficiary
  static Future<void> addSchemeMember(
      String schemeId, Map<String, dynamic> data) async {
    final token = await _getToken();
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/community-members'),
      headers: _headers(token: token),
      body: jsonEncode({
        'scheme_id':     schemeId,
        'name':          data['name'],
        'relative_name': data['relative_name'] ?? '',
        'gender':        data['gender'],
        'since_date':    today,
        'village_id':    '1',
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      String detail = 'Failed to add member.';
      if (response.body.isNotEmpty) {
        try {
          final body = jsonDecode(response.body);
          detail = body['detail'] ?? detail;
        } catch (_) {}
      }
      throw Exception(detail);
    }
  }

}
