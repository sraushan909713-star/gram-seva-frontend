// lib/features/mandi_prices/models/unit.dart
// ══════════════════════════════════════════════════════════════
// Dart model for units (kg, litre, quintal, etc).
// ══════════════════════════════════════════════════════════════

class Unit {
  final String id;
  final String name;
  final String? nameHindi;
  final bool isCustom;
  final String? createdByVendorId;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Unit({
    required this.id,
    required this.name,
    required this.nameHindi,
    required this.isCustom,
    required this.createdByVendorId,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Unit.fromJson(Map<String, dynamic> j) => Unit(
    id:                j['id'] as String,
    name:              j['name'] as String,
    nameHindi:         j['name_hindi'] as String?,
    isCustom:          j['is_custom'] as bool,
    createdByVendorId: j['created_by_vendor_id'] as String?,
    isActive:          j['is_active'] as bool,
    createdAt:         j['created_at'] != null ? DateTime.tryParse(j['created_at'] as String) : null,
    updatedAt:         j['updated_at'] != null ? DateTime.tryParse(j['updated_at'] as String) : null,
  );
}