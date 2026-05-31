// lib/features/mandi_prices/models/vendor_listing.dart
// ══════════════════════════════════════════════════════════════
// Dart model for vendor listings (Mandi prices).
// Mirrors VendorListingResponse from the backend, with joined
// item_name/unit_name fields baked in.
// ══════════════════════════════════════════════════════════════

// — Enums ───────────────────────────────────────────────────
enum TradeMode { buy, sell }

extension TradeModeX on TradeMode {
  String get apiValue => this == TradeMode.buy ? 'buy' : 'sell';
  String get labelEn  => this == TradeMode.buy ? 'Khareedein' : 'Bechein';
  String get labelHi  => this == TradeMode.buy ? 'खरीदें'     : 'बेचें';

  static TradeMode fromApi(String s) =>
      s == 'sell' ? TradeMode.sell : TradeMode.buy;
}

enum StockStatus { inStock, limited, outOfStock }

extension StockStatusX on StockStatus {
  String get apiValue {
    switch (this) {
      case StockStatus.inStock:     return 'in_stock';
      case StockStatus.limited:     return 'limited';
      case StockStatus.outOfStock:  return 'out_of_stock';
    }
  }

  /// Labels swap by mode — sell shows English, buy shows Hindi context.
  String labelFor(TradeMode mode) {
    if (mode == TradeMode.sell) {
      switch (this) {
        case StockStatus.inStock:     return 'In stock';
        case StockStatus.limited:     return 'Limited';
        case StockStatus.outOfStock:  return 'Out of stock';
      }
    } else {
      switch (this) {
        case StockStatus.inStock:     return 'Khareed rahe hain';
        case StockStatus.limited:     return 'Limited';
        case StockStatus.outOfStock:  return 'Abhi nahi khareed rahe';
      }
    }
  }

  static StockStatus fromApi(String s) {
    switch (s) {
      case 'limited':      return StockStatus.limited;
      case 'out_of_stock': return StockStatus.outOfStock;
      default:             return StockStatus.inStock;
    }
  }
}

// — Model ───────────────────────────────────────────────────
class VendorListing {
  final String id;
  final String villageId;
  final String vendorId;
  final String vendorName;
  final String? vendorPhone;
  final String itemId;
  final String? itemName;
  final String? itemNameHindi;
  final String unitId;
  final String? unitName;
  final String? unitNameHindi;
  final TradeMode mode;
  final double price;
  final StockStatus stockStatus;
  final String? notes;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  VendorListing({
    required this.id,
    required this.villageId,
    required this.vendorId,
    required this.vendorName,
    required this.vendorPhone,
    required this.itemId,
    required this.itemName,
    required this.itemNameHindi,
    required this.unitId,
    required this.unitName,
    required this.unitNameHindi,
    required this.mode,
    required this.price,
    required this.stockStatus,
    required this.notes,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VendorListing.fromJson(Map<String, dynamic> j) => VendorListing(
    id:             j['id'] as String,
    villageId:      j['village_id'] as String,
    vendorId:       j['vendor_id'] as String,
    vendorName:     j['vendor_name'] as String,
    vendorPhone:    j['vendor_phone'] as String?,
    itemId:         j['item_id'] as String,
    itemName:       j['item_name'] as String?,
    itemNameHindi:  j['item_name_hindi'] as String?,
    unitId:         j['unit_id'] as String,
    unitName:       j['unit_name'] as String?,
    unitNameHindi:  j['unit_name_hindi'] as String?,
    mode:           TradeModeX.fromApi(j['mode'] as String),
    price:          (j['price'] as num).toDouble(),
    stockStatus:    StockStatusX.fromApi(j['stock_status'] as String),
    notes:          j['notes'] as String?,
    isActive:       j['is_active'] as bool,
    createdAt:      j['created_at'] != null ? DateTime.tryParse(j['created_at'] as String) : null,
    updatedAt:      j['updated_at'] != null ? DateTime.tryParse(j['updated_at'] as String) : null,
  );
}