import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CalcPage extends StatefulWidget {
  final String docId;
  const CalcPage({super.key, required this.docId});

  @override
  State<CalcPage> createState() => _CalcPageState();
}

class _CalcPageState extends State<CalcPage> {
  bool loading = true;

  int kapraoTotal = 0;
  int noodleTotal = 0;
  int somtumTotal = 0;
  int total = 0;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final doc = await FirebaseFirestore.instance
        .collection("food_order")
        .doc(widget.docId)
        .get();

    final data = doc.data();
    if (data == null) return;

    final kaprao = (data['kaprao'] ?? 0) * 50;
    final noodle = (data['noodle'] ?? 0) * 40;
    final somtum = (data['somtum'] ?? 0) * 30;

    setState(() {
      kapraoTotal = kaprao;
      noodleTotal = noodle;
      somtumTotal = somtum;
      total = kaprao + noodle + somtum;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("สรุปรายการอาหาร")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("🍳 ผัดกะเพรา = $kapraoTotal บาท"),
                  Text("🍜 ก๋วยเตี๋ยว = $noodleTotal บาท"),
                  Text("🥗 ส้มตำ = $somtumTotal บาท"),
                  const Divider(),
                  Text(
                    "รวมทั้งหมด = $total บาท",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("กลับ"),
                  )
                ],
              ),
            ),
    );
  }
}
