import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cart.dart';

class IcecreamPage extends StatefulWidget {
  const IcecreamPage({super.key});

  @override
  State<IcecreamPage> createState() => _IcecreamPageState();
}

class _IcecreamPageState extends State<IcecreamPage> {
  late YoutubePlayerController _yt;

  final int price = 60;
  int total = 0;

  final qtyCtrl = TextEditingController();
  final commentCtrl = TextEditingController();

  // พิกัดร้านไอศกรีม
  final shopLat = 18.287508189755098;
  final shopLng = 99.473505143151;

  double? lat;
  double? lng;
  double distance = 0;
  String time = '';

  final mapCtrl = MapController();
  List<LatLng> route = [];

  // ใส่ API Key ของคุณที่นี่ (สมัครฟรีที่ openrouteservice.org)
  final String orsApiKey = "YOUR_ORS_API_KEY_HERE";

  @override
  void initState() {
    super.initState();
    final id = YoutubePlayer.convertUrlToId('https://www.youtube.com/watch?v=4muiyUQzeJ8');
    _yt = YoutubePlayerController(
      initialVideoId: id ?? '',
      flags: const YoutubePlayerFlags(autoPlay: false, mute: false),
    );
    
    // ฟังคำสั่งพิมพ์เพื่อคำนวณราคาอัตโนมัติ
    qtyCtrl.addListener(() {
      final q = int.tryParse(qtyCtrl.text) ?? 0;
      setState(() => total = q * price);
    });
  }

  @override
  void dispose() {
    _yt.dispose();
    qtyCtrl.dispose();
    commentCtrl.dispose();
    super.dispose();
  }

  //---------------- LOGIC ----------------

  Future<void> getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      msg("กรุณาเปิด GPS ในเครื่องมือถือ");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        msg("สิทธิ์การเข้าถึงพิกัดถูกปฏิเสธ");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      msg("กรุณาเปิดสิทธิ์ Location ในตั้งค่าแอป");
      return;
    }

    msg("กำลังระบุตำแหน่งของคุณ...");
    
    final pos = await Geolocator.getCurrentPosition();
    setState(() {
      lat = pos.latitude;
      lng = pos.longitude;
      distance = Geolocator.distanceBetween(lat!, lng!, shopLat, shopLng) / 1000;
    });

    // เลื่อนแผนที่ไปจุดที่เราอยู่
    mapCtrl.move(LatLng(lat!, lng!), 15);
    await fetchRoute();
  }

  Future<void> fetchRoute() async {
    if (lat == null || lng == null || orsApiKey == "YOUR_ORS_API_KEY_HERE") return;

    final uri = Uri.parse('https://api.openrouteservice.org/v2/directions/driving-car/geojson');

    try {
      final res = await http.post(
        uri,
        headers: {
          "Authorization": orsApiKey,
          "Content-Type": "application/json"
        },
        body: jsonEncode({
          "coordinates": [
            [lng, lat],
            [shopLng, shopLat]
          ]
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final pts = data['features'][0]['geometry']['coordinates'] as List;
        final sum = data['features'][0]['properties']['summary'];

        setState(() {
          route = pts.map<LatLng>((e) => LatLng(e[1], e[0])).toList();
          time = "${(sum['duration'] / 60).toStringAsFixed(0)} นาที";
        });
      }
    } catch (e) {
      debugPrint("Route Error: $e");
    }
  }

  void add() {
    final q = int.tryParse(qtyCtrl.text) ?? 0;
    final cmt = commentCtrl.text.trim();

    if (q <= 0) {
      msg("กรุณากรอกจำนวนอย่างน้อย 1 ชิ้น");
      return;
    }

    Cart.addItem("ไอศกรีม${cmt.isNotEmpty ? ' ($cmt)' : ''}", price, q);

    qtyCtrl.clear();
    commentCtrl.clear();
    setState(() => total = 0);
    msg("เพิ่มลงตะกร้าเรียบร้อยแล้ว 🍦");
  }

  Future<void> submit() async {
    if (Cart.items.isEmpty) {
      msg("ยังไม่มีสินค้าในตะกร้า");
      return;
    }

    try {
      await FirebaseFirestore.instance.collection("orders").add({
        "items": Cart.items.map((e) => {
          "name": e.name,
          "price": e.price,
          "qty": e.qty,
          "total": e.price * e.qty
        }).toList(),
        "total": Cart.totalPrice(),
        "time": FieldValue.serverTimestamp(),
      });

      Cart.clear();
      setState(() {});
      msg("ส่งคำสั่งซื้อสำเร็จแล้ว!");
    } catch (e) {
      msg("เกิดข้อผิดพลาด: $e");
    }
  }

  void msg(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t),
        behavior: SnackBarBehavior.floating,
      ));

  //---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Strawberry Ice Cream", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      bottomNavigationBar: _buildBottomAction(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildShopHeader(),
            const SizedBox(height: 16),
            _buildExpansionCard("วัตถุดิบ", Icons.eco_outlined, "• สตรอว์เบอร์รีสด\n• ครีมและนมสด\n• น้ำตาลทราย\n• เกลือเล็กน้อย"),
            _buildExpansionCard("วิธีทำ", Icons.restaurant_menu_outlined, "1. เคี่ยวสตรอว์เบอร์รีกับน้ำตาล\n2. ผสมนมและครีมสดเข้าด้วยกัน\n3. นำไปปั่นในเครื่องทำไอศกรีมจนเนื้อเนียน\n4. แช่แข็งจนเซ็ตตัว"),
            const SizedBox(height: 16),
            const Text("ชมคลิปวิดีโอสอนทำ", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildVideoContainer(),
            const SizedBox(height: 24),
            _buildMapHeader(),
            _buildMapContainer(),
            const SizedBox(height: 24),
            _buildOrderForm(),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildShopHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.pink[50], borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          const CircleAvatar(radius: 30, backgroundColor: Colors.pink, child: Icon(Icons.icecream, color: Colors.white, size: 30)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Strawberry Story", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text("ตำแหน่งร้าน: $shopLat, $shopLng", style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildExpansionCard(String title, IconData icon, String content) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey[200]!)),
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Icon(icon, color: Colors.pink),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Align(alignment: Alignment.centerLeft, child: Text(content, style: const TextStyle(height: 1.5))),
          )
        ],
      ),
    );
  }

  Widget _buildVideoContainer() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
      child: YoutubePlayer(controller: _yt, showVideoProgressIndicator: true),
    );
  }

  Widget _buildMapHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("แผนที่และการจัดส่ง", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        TextButton.icon(
          onPressed: getLocation, 
          icon: const Icon(Icons.my_location), 
          label: const Text("ระบุตำแหน่ง")
        ),
      ],
    );
  }

  Widget _buildMapContainer() {
    return Column(
      children: [
        Container(
          height: 250,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: FlutterMap(
            mapController: mapCtrl,
            options: MapOptions(center: LatLng(shopLat, shopLng), zoom: 14),
            children: [
              TileLayer(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png"),
              MarkerLayer(markers: [
                Marker(point: LatLng(shopLat, shopLng), width: 45, height: 45, builder: (_) => const Icon(Icons.location_on, color: Colors.red, size: 40)),
                if (lat != null)
                  Marker(point: LatLng(lat!, lng!), width: 45, height: 45, builder: (_) => const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40)),
              ]),
              if (route.isNotEmpty) PolylineLayer(polylines: [
                Polyline(points: route, strokeWidth: 5, color: Colors.blue.withOpacity(0.7))
              ]),
            ],
          ),
        ),
        if (distance > 0)
          Container(
            padding: const EdgeInsets.all(12),
            child: Text("ระยะห่างจากคุณ: ${distance.toStringAsFixed(2)} กม. ($time)", 
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.pink)),
          ),
      ],
    );
  }

  Widget _buildOrderForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("รายละเอียดการสั่งซื้อ", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(
          controller: qtyCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: "จำนวน (ถ้วยละ $price บาท)",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
            prefixIcon: const Icon(Icons.add_shopping_cart),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: commentCtrl,
          decoration: InputDecoration(
            labelText: "ระบุความต้องการเพิ่มเติม",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
            prefixIcon: const Icon(Icons.edit_note),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("ยอดรวมชำระ", style: TextStyle(color: Colors.grey)),
                  Text("฿ $total", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.pink)),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: add,
              child: const Text("ใส่ตะกร้า"),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              onPressed: submit,
              icon: const Icon(Icons.send),
              style: IconButton.styleFrom(backgroundColor: Colors.black, padding: const EdgeInsets.all(15)),
            )
          ],
        ),
      ),
    );
  }
}