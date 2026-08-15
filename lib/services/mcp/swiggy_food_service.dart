// lib/services/mcp/swiggy_food_service.dart
//
// Typed wrapper over the Swiggy Food MCP tools.
//
// Two responsibilities beyond parsing:
//  1. addressId injection. Every tool needs it, the caller should never have
//     to remember it, and it is resolved once per session and cached.
//  2. Token-expiry surfacing. Swiggy's OAuth issues NO refresh token, so an
//     expired token means the user must re-authenticate. That has to reach
//     the voice layer as a distinct, speakable state — never a generic
//     failure mid-order.

import '../../models/swiggy_models.dart';
import 'mcp_client.dart';

/// Thrown when the access token is dead and the user must re-authenticate.
/// Callers should speak a re-connect prompt, not a generic error.
class SwiggyAuthExpiredException implements Exception {
  @override
  String toString() => 'SwiggyAuthExpiredException';
}

class SwiggyFoodService {
  static const _endpoint = 'https://mcp.swiggy.com/food';

  final McpClient _client;

  /// Resolved once per session. Swiggy requires it on every call, and it does
  /// not change mid-conversation.
  String? _addressId;

  SwiggyFoodService({
    required Future<String> Function() accessToken,
    McpClient? client,
  }) : _client = client ??
            McpClient(
              endpoint: Uri.parse(_endpoint),
              accessToken: accessToken,
            );

  /// Wraps every call so an expired token surfaces as its own exception.
  Future<Map<String, dynamic>> _call(
    String tool,
    Map<String, dynamic> args,
  ) async {
    try {
      return await _client.callTool(tool, args);
    } on McpException catch (e) {
      final payload = e.payload?.toString().toLowerCase() ?? '';
      if (payload.contains('invalid_token') ||
          payload.contains('unauthorized') ||
          payload.contains('expired')) {
        throw SwiggyAuthExpiredException();
      }
      rethrow;
    }
  }

  Map<String, dynamic> _structured(Map<String, dynamic> result) {
    final sc = result['structuredContent'];
    return sc is Map<String, dynamic> ? sc : const {};
  }

  // ── Addresses ─────────────────────────────────────────────────────────────

  Future<List<SwiggyAddress>> getAddresses() async {
    final res = await _call('get_addresses', {});
    final raw = (_structured(res)['addresses'] as List?) ?? const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(SwiggyAddress.fromJson)
        .toList();
  }

  /// Resolves and caches the delivery address. Returns null when the account
  /// has none saved — the caller must then tell the user to add one in the
  /// Swiggy app, because VANI cannot create addresses.
  Future<String?> ensureAddress() async {
    if (_addressId != null) return _addressId;
    final addresses = await getAddresses();
    if (addresses.isEmpty) return null;
    // First saved address. Choosing between several is a product decision
    // that needs a spoken prompt — not something to guess at here.
    _addressId = addresses.first.id;
    return _addressId;
  }

  Future<String> _requireAddress() async {
    final id = await ensureAddress();
    if (id == null) {
      throw StateError('No saved Swiggy address on this account.');
    }
    return id;
  }

  // ── Discovery ─────────────────────────────────────────────────────────────

  Future<List<Restaurant>> searchRestaurants(String query) async {
    final addressId = await _requireAddress();
    final res = await _call('search_restaurants', {
      'addressId': addressId,
      'query': query,
    });
    final raw = (_structured(res)['restaurants'] as List?) ?? const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(Restaurant.fromJson)
        .where((r) => r.isOpen)
        // Swiggy injects paid placements suffixed "(Ad)" — about half the
        // results. VANI speaks these as its own suggestions to a user who
        // cannot see the label, so they are filtered at the source.
        .where((r) => !r.name.contains('(Ad)'))
        .toList();
  }

  Future<RestaurantMenu> getMenu(String restaurantId) async {
    final addressId = await _requireAddress();
    final res = await _call('get_restaurant_menu', {
      'addressId': addressId,
      'restaurantId': restaurantId,
    });
    return RestaurantMenu.fromJson(_structured(res));
  }

  // ── Cart ──────────────────────────────────────────────────────────────────

  /// Adds or updates one item. Rejects items with variants or addons: those
  /// need a spoken choice VANI cannot make on the user's behalf, and adding
  /// them blind would put the wrong thing in a real cart.
  Future<Cart> addItem({
    required String restaurantId,
    required MenuItem item,
    int quantity = 1,
  }) async {
    if (item.needsUserChoice) {
      throw ArgumentError(
          '${item.name} has variants or addons — ask the user first.');
    }
    final addressId = await _requireAddress();
    final res = await _call('update_food_cart', {
      'addressId': addressId,
      'restaurantId': restaurantId,
      'cartItems': [
        {'menu_item_id': item.id, 'quantity': quantity}
      ],
    });
    return Cart.fromJson(_structured(res));
  }

  Future<Cart> getCart() async {
    final addressId = await _requireAddress();
    final res = await _call('get_food_cart', {'addressId': addressId});
    return Cart.fromJson(_structured(res));
  }

  Future<void> flushCart() async {
    final addressId = await _requireAddress();
    await _call('flush_food_cart', {'addressId': addressId});
  }

  void dispose() => _client.dispose();
}