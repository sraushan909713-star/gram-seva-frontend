// lib/features/mandi_prices/models/item.dart
// ══════════════════════════════════════════════════════════════
// Dart model for items (Mandi master catalog).
// ══════════════════════════════════════════════════════════════

class Item {
  final String id;
  final String name;
  final String? nameHindi;
  final String? defaultUnitId;
  final String? category;
  final int displayOrder;
  final bool isCustom;
  final String? createdByVendorId;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Item({
    required this.id,
    required this.name,
    required this.nameHindi,
    required this.defaultUnitId,
    required this.category,
    required this.displayOrder,
    required this.isCustom,
    required this.createdByVendorId,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Item.fromJson(Map<String, dynamic> j) => Item(
    id:                j['id'] as String,
    name:              j['name'] as String,
    nameHindi:         j['name_hindi'] as String?,
    defaultUnitId:     j['default_unit_id'] as String?,
    category:          j['category'] as String?,
    displayOrder:      j['display_order'] as int,
    isCustom:          j['is_custom'] as bool,
    createdByVendorId: j['created_by_vendor_id'] as String?,
    isActive:          j['is_active'] as bool,
    createdAt:         j['created_at'] != null ? DateTime.tryParse(j['created_at'] as String) : null,
    updatedAt:         j['updated_at'] != null ? DateTime.tryParse(j['updated_at'] as String) : null,
  );
}