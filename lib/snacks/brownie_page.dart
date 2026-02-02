import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cart.dart';

class BrowniePage extends StatefulWidget {
  const BrowniePage({super.key});

  @override
  State<BrowniePage> createState() => _BrowniePageState();
}

class _BrowniePageState extends State<BrowniePage> {
  late YoutubePlayerController _yt;

  final int price = 120;
  int total = 0;

  final qtyCtrl = TextEditingController();
  final commentCtrl = TextEditingController();

  // พิกัดร้านบราวนี่
  final shopLat = 18.285143020181053;
  final shopLng = 99.50010257145512;

  double? lat;
  double? lng;
  double distance = 0;
  String time = '';

  final mapCtrl = MapController();
  List<LatLng> route = [];

  // นำ API Key จาก openrouteservice.org มาใส่ที่นี่
  final String orsApiKey = "YOUR_ORS_API_KEY";

  @override
  void initState() {
    super.initState();
    final id = YoutubePlayer.convertUrlToId('https://www.youtube.com/watch?v=-cSCXPzpy-o');
    _yt = YoutubePlayerController(
      initialVideoId: id ?? '',
      flags: const YoutubePlayerFlags(autoPlay: false),
    );
    
    // คำนวณราคาทันทีเมื่อมีการพิมพ์จำนวน
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
    if (!await Geolocator.isLocationServiceEnabled()) {
      msg("กรุณาเปิด GPS / Location");
      return;
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      msg("กรุณาเปิดสิทธิ์ Location ใน Settings");
      return;
    }

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
    if (lat == null || lng == null || orsApiKey == "YOUR_ORS_API_KEY") return;

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
            [lng, lat], // จุดเริ่มต้น (ตัวเรา)
            [shopLng, shopLat] // จุดปลายทาง (ร้าน)
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
      print("Route Error: $e");
    }
  }

  void add() {
    final q = int.tryParse(qtyCtrl.text) ?? 0;
    final cmt = commentCtrl.text.trim();

    if (q <= 0) {
      msg("กรุณากรอกจำนวนมากกว่า 0");
      return;
    }

    Cart.addItem("บราวนี่${cmt.isNotEmpty ? ' ($cmt)' : ''}", price, q);

    qtyCtrl.clear();
    commentCtrl.clear();
    setState(() => total = 0);
    msg("เพิ่มลงตะกร้าแล้ว 🍫");
  }

  Future<void> submit() async {
    if (Cart.items.isEmpty) {
      msg("ตะกร้าว่าง");
      return;
    }

    await FirebaseFirestore.instance.collection("orders").add({
      "items": Cart.items.map((e) => {
        "name": e.name,
        "price": e.price,
        "qty": e.qty,
        "total": e.price * e.qty
      }).toList(),
      "totalPrice": Cart.totalPrice(),
      "time": FieldValue.serverTimestamp(),
    });

    Cart.clear();
    setState(() {});
    msg("สั่งอาหารเรียบร้อยแล้ว");
  }

  void msg(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  //---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Brownie Homemade"),
        backgroundColor: Colors.brown[700],
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: _bottomOrderBar(),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _shopHeader(),
          const SizedBox(height: 10),
          _ingredientSection(),
          const SizedBox(height: 10),
          _videoSection(),
          const SizedBox(height: 10),
          _mapSection(),
          const SizedBox(height: 10),
          _orderSection(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _shopHeader() => Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: ListTile(
          leading: const CircleAvatar(backgroundColor: Colors.brown, child: Icon(Icons.store, color: Colors.white)),
          title: const Text("ร้านบราวนี่โฮมเมด", style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("พิกัดร้าน: $shopLat, $shopLng"),
        ),
      );

  Widget _ingredientSection() => Card(
        child: ExpansionTile(
          leading: const Icon(Icons.flatware, color: Colors.brown),
          title: const Text("วัตถุดิบและวิธีทำ"),
          children: const [
            ListTile(title: Text("• ช็อกโกแลตแท้เข้มข้น\n• แป้งสาลีคัดพิเศษ\n• เนยสดแท้\n• น้ำตาลทรายแดง")),
            Divider(),
            ListTile(title: Text("1. ผสมช็อกโกแลตและเนยละลายเข้าด้วยกัน\n2. ตีไข่กับน้ำตาลจนฟูแล้วผสมกับแป้ง\n3. นำเข้าเตาอบที่อุณหภูมิ 175 องศา นาน 20 นาที")),
          ],
        ),
      );

  Widget _videoSection() => Card(
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          leading: const Icon(Icons.play_circle_fill, color: Colors.red),
          title: const Text("วิดีโอสอนทำบราวนี่"),
          children: [
            SizedBox(height: 220, child: YoutubePlayer(controller: _yt)),
          ],
        ),
      );

  Widget _mapSection() => Card(
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          leading: const Icon(Icons.map, color: Colors.blue),
          title: const Text("ตำแหน่งร้านและการเดินทาง"),
          children: [
            SizedBox(
              height: 280,
              child: FlutterMap(
                mapController: mapCtrl,
                options: MapOptions(center: LatLng(shopLat, shopLng), zoom: 14),
                children: [
                  TileLayer(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png"),
                  MarkerLayer(markers: [
                    // หมุดร้าน
                    Marker(
                        point: LatLng(shopLat, shopLng),
                        width: 45,
                        height: 45,
                        builder: (_) => const Icon(Icons.location_on, color: Colors.red, size: 40)),
                    // หมุดเรา
                    if (lat != null)
                      Marker(
                          point: LatLng(lat!, lng!),
                          width: 45,
                          height: 45,
                          builder: (_) => const Icon(Icons.my_location, color: Colors.blue, size: 30)),
                  ]),
                  // วาดเส้นทาง
                  if (route.isNotEmpty)
                    PolylineLayer(polylines: [
                      Polyline(points: route, strokeWidth: 5, color: Colors.blue.withOpacity(0.7))
                    ])
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton.icon(
                  onPressed: getLocation,
                  icon: const Icon(Icons.gps_fixed),
                  label: const Text("เช็คตำแหน่งเพื่อดูเส้นทาง")),
            ),
            if (distance > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text("ระยะทาง: ${distance.toStringAsFixed(2)} กม. | เดินทาง: $time",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brown)),
              ),
          ],
        ),
      );

  Widget _orderSection() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("ระบุรายการสั่งซื้อ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: "จำนวน (ราคาชิ้นละ $price บาท)", prefixIcon: const Icon(Icons.numbers))),
            TextField(
                controller: commentCtrl,
                decoration: const InputDecoration(labelText: "หมายเหตุ (เช่น ความหวาน, เพิ่มถั่ว)", prefixIcon: const Icon(Icons.comment))),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("ราคารวมทั้งหมด:", style: TextStyle(fontSize: 16)),
                Text("฿ $total", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.brown)),
              ],
            ),
          ]),
        ),
      );

  Widget _bottomOrderBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    child: Row(
      children: [
        Expanded(
            child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text("เพิ่มลงตะกร้า"),
                onPressed: add)),
        const SizedBox(width: 10),
        Expanded(
            child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.brown, foregroundColor: Colors.white),
                icon: const Icon(Icons.send),
                label: const Text("สั่งซื้อเลย"),
                onPressed: submit)),
      ],
    ),
  );
}