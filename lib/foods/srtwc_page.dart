import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cart.dart';

class SrtwcPage extends StatefulWidget {
  const SrtwcPage({super.key});

  @override
  State<SrtwcPage> createState() => _SrtwcPageState();
}

class _SrtwcPageState extends State<SrtwcPage> {
  late YoutubePlayerController _ytController;

  final int price = 50;
  final TextEditingController qtyCtrl = TextEditingController();
  final TextEditingController commentCtrl = TextEditingController();
  int totalPrice = 0;

  final double shopLatitude = 18.273041486031918;
  final double shopLongitude = 99.50163563543747;

  double? currentLat;
  double? currentLng;
  double distance = 0;
  String travelTime = '';

  final MapController mapCtrl = MapController();
  List<LatLng> routePoints = [];

  final String orsApiKey = "YOUR_ORS_API_KEY";

  @override
  void initState() {
    super.initState();
    final videoId = YoutubePlayer.convertUrlToId('https://www.youtube.com/watch?v=tF196vSo-oQ');
    _ytController = YoutubePlayerController(
      initialVideoId: videoId ?? '',
      flags: const YoutubePlayerFlags(autoPlay: false),
    );
  }

  @override
  void dispose() {
    _ytController.dispose();
    qtyCtrl.dispose();
    commentCtrl.dispose();
    super.dispose();
  }

  // ---------- LOGIC ----------

  void calcPrice() {
    final q = int.tryParse(qtyCtrl.text) ?? 0;
    setState(() => totalPrice = q * price);
  }

  Future<void> _getLocation() async {
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
      currentLat = pos.latitude;
      currentLng = pos.longitude;
      distance = Geolocator.distanceBetween(currentLat!, currentLng!, shopLatitude, shopLongitude) / 1000;
    });

    mapCtrl.move(LatLng(currentLat!, currentLng!), 15);
    await _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    if (currentLat == null || currentLng == null) return;

    final uri = Uri.parse('https://api.openrouteservice.org/v2/directions/driving-car/geojson');

    final res = await http.post(
      uri,
      headers: {"Authorization": orsApiKey, "Content-Type": "application/json"},
      body: jsonEncode({
        "coordinates": [
          [currentLng, currentLat],
          [shopLongitude, shopLatitude]
        ]
      }),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final pts = data['features'][0]['geometry']['coordinates'];
      final sum = data['features'][0]['properties']['summary'];

      setState(() {
        routePoints = pts.map<LatLng>((e) => LatLng(e[1], e[0])).toList();
        travelTime = "${(sum['duration'] / 60).toStringAsFixed(0)} นาที";
      });
    }
  }

  void _addToCart() {
    final q = int.tryParse(qtyCtrl.text) ?? 0;
    final cmt = commentCtrl.text.trim();

    if (q <= 0) {
      msg("กรุณากรอกจำนวนมากกว่า 0");
      return;
    }

    Cart.addItem("ข้าวมันไก่${cmt.isNotEmpty ? ' ($cmt)' : ''}", price, q);

    qtyCtrl.clear();
    commentCtrl.clear();
    setState(() => totalPrice = 0);

    msg("เพิ่มลงตะกร้าแล้ว");
  }

  Future<void> _submitCart() async {
    if (Cart.items.isEmpty) {
      msg("ตะกร้าว่าง");
      return;
    }

    await FirebaseFirestore.instance.collection("orders").add({
      "items": Cart.items
          .map((e) => {
                "name": e.name,
                "price": e.price,
                "qty": e.qty,
                "total": e.price * e.qty
              })
          .toList(),
      "totalPrice": Cart.totalPrice(),
      "timestamp": FieldValue.serverTimestamp(),
    });

    Cart.clear();
    setState(() {});
    msg("สั่งอาหารเรียบร้อยแล้ว");
  }

  void msg(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ข้าวมันไก่")),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _headerSection(),
          const SizedBox(height: 10),
          _ingredientSection(),
          const SizedBox(height: 10),
          _recipeSection(),
          const SizedBox(height: 10),
          _videoSection(),
          const SizedBox(height: 10),
          _mapSection(),
          const SizedBox(height: 20),
          _orderSection(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _headerSection() => Card(
        child: ListTile(
          leading: const Icon(Icons.store, color: Colors.red),
          title: const Text("ข้าวมันไก่"),
          subtitle: Text("Lat: $shopLatitude\nLng: $shopLongitude"),
        ),
      );

  Widget _ingredientSection() => Card(
        child: ExpansionTile(
          title: const Text("วัตถุดิบ (สำหรับ 1 จาน)"),
          children: const [
            ListTile(
                title: Text(
                    "- ไก่\n- ข้าวสาร 1 กำมือ\n- พริก 3-5 เม็ด\n- กระเทียม 2 กลีบ\n- ข้าวสวย 1 จาน\n- ขิง\n- น้ำปลา, น้ำตาล, ซอสปรุงรส")),
          ],
        ),
      );

  Widget _recipeSection() => Card(
        child: ExpansionTile(
          title: const Text("วิธีทำ"),
          children: const [
            ListTile(
                title: Text(
                    "1. ต้มไก่กับน้ำและขิงจนสุก เก็บน้ำซุปไว้\n2. หุงข้าวด้วยน้ำซุปและมันไก่\n3. สับไก่ เสิร์ฟพร้อมข้าวและน้ำจิ้ม")),
          ],
        ),
      );

  Widget _videoSection() => ExpansionTile(
        title: const Text("วิดีโอสอนทำอาหาร"),
        children: [
          SizedBox(height: 220, child: YoutubePlayer(controller: _ytController)),
        ],
      );

  Widget _mapSection() => ExpansionTile(
        title: const Text("แผนที่ร้าน & พิกัด"),
        children: [
          SizedBox(
            height: 260,
            child: FlutterMap(
              mapController: mapCtrl,
              options: MapOptions(center: LatLng(shopLatitude, shopLongitude), zoom: 14),
              children: [
                TileLayer(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png"),
                MarkerLayer(markers: [
                  Marker(
                      point: LatLng(shopLatitude, shopLongitude),
                      width: 40,
                      height: 40,
                      builder: (_) => const Icon(Icons.location_on, color: Colors.red)),
                  if (currentLat != null)
                    Marker(
                        point: LatLng(currentLat!, currentLng!),
                        width: 40,
                        height: 40,
                        builder: (_) => const Icon(Icons.my_location, color: Colors.blue)),
                ]),
                if (routePoints.isNotEmpty)
                  PolylineLayer(polylines: [Polyline(points: routePoints, strokeWidth: 4)])
              ],
            ),
          ),
          ElevatedButton(onPressed: _getLocation, child: const Text("อ่านพิกัดปัจจุบัน")),
          if (distance > 0) Text("ระยะทาง: ${distance.toStringAsFixed(2)} กม."),
          if (travelTime.isNotEmpty) Text("เวลาเดินทางโดยรถยนต์: $travelTime"),
        ],
      );

  Widget _orderSection() => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("สั่งอาหาร", style: TextStyle(fontWeight: FontWeight.bold)),
            Text("ราคา $price บาท / จาน"),
            TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "จำนวน")),
            TextField(controller: commentCtrl, decoration: const InputDecoration(labelText: "หมายเหตุ")),
            Text("รวม: $totalPrice บาท", style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 6),
            ElevatedButton(onPressed: calcPrice, child: const Text("คำนวณราคา")),
            Row(
              children: [
                Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.shopping_cart), label: const Text("เพิ่มลงตะกร้า"), onPressed: _addToCart)),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.send), label: const Text("สั่งอาหารทั้งหมด"), onPressed: _submitCart)),
              ],
            )
          ]),
        ),
      );
}
