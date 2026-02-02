class CartItem {
  final String name;
  final int price;
  int qty;

  CartItem({
    required this.name,
    required this.price,
    required this.qty,
  });
}

class Cart {
  // รายการสินค้าในตะกร้า
  static final List<CartItem> items = [];

  /// เพิ่มสินค้าในตะกร้า
  /// ถ้ามีอยู่แล้ว จะบวกจำนวน qty
  static void addItem(String name, int price, int qty) {
    if (qty <= 0) return; // ป้องกันจำนวน <= 0

    final index = items.indexWhere((item) => item.name == name);

    if (index >= 0) {
      items[index].qty += qty;
    } else {
      items.add(CartItem(name: name, price: price, qty: qty));
    }
  }

  /// ลบสินค้าออกจากตะกร้า
  static void removeItem(String name) {
    items.removeWhere((item) => item.name == name);
  }

  /// ล้างตะกร้า
  static void clear() {
    items.clear();
  }

  /// ราคาสินค้าทั้งหมด
  static int totalPrice() {
    return items.fold(0, (sum, item) => sum + item.price * item.qty);
  }

  /// จำนวนสินค้าทั้งหมด
  static int totalItems() {
    return items.fold(0, (sum, item) => sum + item.qty);
  }

  /// แสดงรายการสินค้า (debug)
  static void printCart() {
    if (items.isEmpty) {
      print("ตะกร้าว่าง");
    } else {
      for (var item in items) {
        print("${item.name} x${item.qty} = ${item.price * item.qty} บาท");
      }
    }
  }
}
