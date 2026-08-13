// lib/services/mcp/models/swiggy_models.dart
//
// Typed models for Swiggy Food MCP responses.
//
// Parsing rules that matter:
//  - IDs arrive as ints from the server but the tool schema declares them as
//    strings. _asString() normalises both, so a server-side type change
//    cannot silently produce nulls in a voice command.
//  - Only fields VANI actually uses are parsed. Ratings, images and offers are
//    kept because they matter for spoken choice; everything else is dropped.
//  - Nothing throws on a missing optional field. A malformed item is skipped,
//    not fatal — one bad menu row must never kill an order.

String _asString(dynamic v) => v?.toString() ?? '';

double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

class SwiggyAddress {
  final String id;
  final String addressLine;
  final String tag;

  const SwiggyAddress({
    required this.id,
    required this.addressLine,
    required this.tag,
  });

  factory SwiggyAddress.fromJson(Map<String, dynamic> j) => SwiggyAddress(
        id: _asString(j['id']),
        addressLine: _asString(j['addressLine']),
        tag: _asString(j['addressTag']),
      );
}

class Restaurant {
  final String id;
  final String name;
  final String areaName;
  final double? rating;
  final String costForTwo;
  final int? deliveryMinutes;
  final String? offer;
  final bool isOpen;
  final bool isVeg;

  const Restaurant({
    required this.id,
    required this.name,
    required this.areaName,
    this.rating,
    this.costForTwo = '',
    this.deliveryMinutes,
    this.offer,
    this.isOpen = true,
    this.isVeg = false,
  });

  factory Restaurant.fromJson(Map<String, dynamic> j) => Restaurant(
        id: _asString(j['id']),
        name: _asString(j['name']),
        areaName: _asString(j['areaName']),
        rating: _asDouble(j['avgRating']),
        costForTwo: _asString(j['costForTwo']),
        deliveryMinutes: j['deliveryTimeMinutes'] is num
            ? (j['deliveryTimeMinutes'] as num).toInt()
            : null,
        offer: j['offer'] == null ? null : _asString(j['offer']),
        // Absent means open — the server only sends this when it is not.
        isOpen: _asString(j['availabilityStatus']) != 'CLOSED',
        isVeg: j['veg'] == true,
      );

  /// One short line for TTS. Deliberately omits cuisines and offers — a spoken
  /// list of ten restaurants is unusable if each entry runs long.
  String get spokenSummary {
    final r = rating == null ? '' : ', $rating rating';
    final t = deliveryMinutes == null ? '' : ', $deliveryMinutes minute';
    return '$name$r$t';
  }
}

class MenuItem {
  final String id;
  final String name;
  final String? description;
  final double price;
  final bool inStock;
  final bool isVeg;
  final double? rating;
  final bool isBestseller;

  /// Variants and addons are NOT handled yet. An item with either flag set
  /// cannot be added to the cart correctly without asking the user which
  /// variant they want, so callers must check this before adding.
  final bool hasVariants;
  final bool hasAddons;

  const MenuItem({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.inStock = true,
    this.isVeg = false,
    this.rating,
    this.isBestseller = false,
    this.hasVariants = false,
    this.hasAddons = false,
  });

  factory MenuItem.fromJson(Map<String, dynamic> j) => MenuItem(
        id: _asString(j['id']),
        name: _asString(j['name']),
        description:
            j['description'] == null ? null : _asString(j['description']),
        price: _asDouble(j['price']) ?? 0,
        // inStock arrives as 1/0, not a bool.
        inStock: j['inStock'] == 1 || j['inStock'] == true,
        isVeg: j['isVeg'] == true,
        rating: _asDouble(j['rating']),
        isBestseller: j['isBestseller'] == true,
        hasVariants: j['hasVariants'] == true,
        hasAddons: j['hasAddons'] == true,
      );

  bool get needsUserChoice => hasVariants || hasAddons;

  /// Rounded for speech — "do sau" is natural, "two hundred point two four"
  /// is not. The exact price still comes from the cart before confirmation.
  String get spokenSummary => '$name, ${price.round()} rupees';
}

class MenuCategory {
  final String title;
  final List<MenuItem> items;

  const MenuCategory({required this.title, required this.items});

  factory MenuCategory.fromJson(Map<String, dynamic> j) {
    final raw = (j['items'] as List?) ?? const [];
    final items = <MenuItem>[];
    for (final e in raw) {
      if (e is Map<String, dynamic>) {
        try {
          items.add(MenuItem.fromJson(e));
        } catch (_) {
          // Skip a malformed row rather than losing the whole menu.
        }
      }
    }
    return MenuCategory(title: _asString(j['title']), items: items);
  }
}

class RestaurantMenu {
  final String restaurantId;
  final String restaurantName;
  final bool isOpen;
  final List<MenuCategory> categories;

  const RestaurantMenu({
    required this.restaurantId,
    required this.restaurantName,
    required this.categories,
    this.isOpen = true,
  });

  factory RestaurantMenu.fromJson(Map<String, dynamic> j) {
    final r = (j['restaurant'] as Map<String, dynamic>?) ?? const {};
    final rawCats = (j['categories'] as List?) ?? const [];
    return RestaurantMenu(
      restaurantId: _asString(r['id']),
      restaurantName: _asString(r['name']),
      isOpen: r['isOpen'] != false,
      categories: rawCats
          .whereType<Map<String, dynamic>>()
          .map(MenuCategory.fromJson)
          .toList(),
    );
  }


  /// Flattened search across every category — the user says "pav bhaji", not
  /// "the pav bhaji in the 99 Store category".
  List<MenuItem> findItems(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return const [];
    final hits = <MenuItem>[];
    for (final c in categories) {
      for (final i in c.items) {
        if (i.name.toLowerCase().contains(q) && i.inStock) hits.add(i);
      }
    }
    return hits;
  }
}

class CartItem {
  final String menuItemId;
  final String name;
  final int quantity;

  /// Pre-discount line total. Do NOT speak this — it is not what gets charged.
  final double subtotal;

  /// Post-discount price for this line. This is the real number.
  final double finalPrice;

  final bool inStock;

  const CartItem({
    required this.menuItemId,
    required this.name,
    required this.quantity,
    required this.subtotal,
    required this.finalPrice,
    this.inStock = true,
  });

  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
        menuItemId: _asString(j['menu_item_id']),
        name: _asString(j['name']),
        quantity: (j['quantity'] is num) ? (j['quantity'] as num).toInt() : 1,
        subtotal: _asDouble(j['subtotal']) ?? 0,
        finalPrice: _asDouble(j['final_price']) ?? _asDouble(j['total']) ?? 0,
        inStock: j['in_stock'] == 1 || j['in_stock'] == true,
      );

  String get spokenSummary =>
      quantity > 1 ? '$quantity $name' : name;
}

class Cart {
  final String cartId;
  final List<CartItem> items;

  /// The ONLY figure VANI may speak before the confirmation gate. Menu prices
  /// and item subtotals are pre-discount and differ from what is charged —
  /// a Mini Pavbhaji Meal listed at 200.24 billed at 109. Announcing anything
  /// but toPay risks quoting a price the user is not actually charged.
  final double toPay;

  final double itemTotal;
  final double deliveryCharge;
  final double taxesAndCharges;
  final bool freeDelivery;
  final String deliveryEstimate;

  const Cart({
    required this.cartId,
    required this.items,
    required this.toPay,
    this.itemTotal = 0,
    this.deliveryCharge = 0,
    this.taxesAndCharges = 0,
    this.freeDelivery = false,
    this.deliveryEstimate = '',
  });

  /// Parses the `data` object of a get_food_cart / update_food_cart response.
  factory Cart.fromJson(Map<String, dynamic> j) {
    final data = (j['data'] as Map<String, dynamic>?) ?? j;
    final pricing = (data['pricing'] as Map<String, dynamic>?) ?? const {};
    final offers = (data['offers'] as Map<String, dynamic>?) ?? const {};
    final restaurant = (data['restaurant'] as Map<String, dynamic>?) ?? const {};
    final rawItems = (data['items'] as List?) ?? const [];

    return Cart(
      cartId: _asString(data['cart_id']),
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(CartItem.fromJson)
          .toList(),
      toPay: _asDouble(pricing['to_pay']) ?? 0,
      itemTotal: _asDouble(pricing['item_total']) ?? 0,
      deliveryCharge: _asDouble(pricing['delivery_charge']) ?? 0,
      taxesAndCharges: _asDouble(pricing['taxes_and_charges']) ?? 0,
      freeDelivery: offers['free_delivery_applied'] == true,
      deliveryEstimate: _asString(restaurant['deliverySubtitle']),
    );
  }

  bool get isEmpty => items.isEmpty;
  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);

  /// What VANI says at the confirmation gate. Uses toPay only, rounded — the
  /// exact paise are on screen; the spoken number must match what is charged.
  String get spokenSummary {
    if (isEmpty) return 'Cart khaali hai';
    final names = items.map((i) => i.spokenSummary).join(', ');
    return '$names — total ${toPay.round()} rupees';
  }
}