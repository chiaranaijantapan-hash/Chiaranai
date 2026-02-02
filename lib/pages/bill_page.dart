import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cart.dart';

class BillPage extends StatefulWidget {
  const BillPage({super.key});

  @override
  State<BillPage> createState() => _BillPageState();
}

class _BillPageState extends State<BillPage> {

  Future<void> submitOrder() async {
    if (Cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ตะกร้าว่าง")),
      );
      return;
    }

    // รอบที่ 1: ยืนยันการสั่งอาหาร
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("ยืนยันการสั่งอาหาร"),
        content: const Text("คุณต้องการสั่งอาหารทั้งหมดหรือไม่?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("ยกเลิก"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("ตกลง"),
          ),
        ],
      ),
    );

    if (firstConfirm != true) return; // ถ้าไม่ตกลง จะหยุด

    // รอบที่ 2: ยืนยันอีกรอบ
    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("ยืนยันอีกครั้ง"),
        content: const Text("คุณแน่ใจแล้วใช่หรือไม่ว่าต้องการสั่งอาหารทั้งหมด?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("ยกเลิก"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("ใช่, สั่งเลย"),
          ),
        ],
      ),
    );

    if (secondConfirm != true) return; // ถ้าไม่ตกลง จะหยุด

    // ส่ง order ไป Firestore
    try {
      await FirebaseFirestore.instance.collection("orders").add({
        "items": Cart.items.map((item) => {
          "name": item.name,
          "price": item.price,
          "qty": item.qty,
          "subtotal": item.price * item.qty,
        }).toList(),
        "totalPrice": Cart.totalPrice(),
        "totalItems": Cart.totalItems(),
        "status": "pending",
        "timestamp": FieldValue.serverTimestamp(),
      });

      Cart.clear();
      setState(() {}); // รีเฟรช UI

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("สั่งอาหารเรียบร้อยแล้ว 🍽️")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("เกิดข้อผิดพลาด: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("บิล / ตะกร้าสินค้า"),
        backgroundColor: Colors.deepOrange,
      ),
      body: Cart.items.isEmpty
          ? const Center(child: Text("ตะกร้าว่าง"))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: Cart.items.length,
                    itemBuilder: (context, index) {
                      final item = Cart.items[index];
                      return ListTile(
                        title: Text(item.name),
                        subtitle: Text(
                          "ราคา: ${item.price} x ${item.qty} = ${item.price * item.qty} บาท",
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              Cart.removeItem(item.name);
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        "รวมทั้งหมด: ${Cart.totalPrice()} บาท",
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: submitOrder,
                        child: const Text("ยืนยันการสั่งอาหาร"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
