import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/cart.dart';

class PadThaiPage extends StatefulWidget {
  const PadThaiPage({super.key});

  @override
  State<PadThaiPage> createState() => _PadThaiPageState();
}

class _PadThaiPageState extends State<PadThaiPage> {
  late YoutubePlayerController _yt;

  final int price = 45;
  int total = 0;

  final qtyCtrl = TextEditingController();
  final commentCtrl = TextEditingController();

  final double shopLat = 18.28169;
  final double shopLng = 99.51068;

  double? lat;
  double? lng;
  double distance = 0;
  String time = '';

  final mapCtrl = MapController();
  List<LatLng> route = [];

  final String orsApiKey = "YOUR_ORS_API_KEY";

  @override
  void initState() {
    super.initState();
    final id = YoutubePlayer.convertUrlToId(
        'https://www.youtube.com/watch?v=jpV2pmglE40');
    _yt = YoutubePlayerController(
      initialVideoId: id ?? 'dQw4w9WgXcQ',
      flags: const YoutubePlayerFlags(autoPlay: false),
    );
  }

  @override
  void dispose() {
    _yt.dispose();
    qtyCtrl.dispose();
    commentCtrl.dispose();
    super.dispose();
  }

  // ---------------- LOGIC ----------------

  void calc() {
    final q = int.tryParse(qtyCtrl.text) ?? 0;
    setState(() => total = q * price);
  }

  Future<void> getLocation() async {
    try {
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

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      setState(() {
        lat = pos.latitude;
        lng = pos.longitude;
        distance = Geolocator.distanceBetween(lat!, lng!, shopLat, shopLng) / 1000;
      });

      await fetchRoute();
    } catch (e) {
      msg("ไม่สามารถอ่านพิกัดได้: $e");
    }
  }

  Future<void> fetchRoute() async {
    if (lat == null || lng == null) return;

    final uri = Uri.parse(
        'https://api.openrouteservice.org/v2/directions/driving-car/geojson');

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
        final pts = data['features'][0]['geometry']['coordinates'];
        final sum = data['features'][0]['properties']['summary'];

        setState(() {
          route = pts.map<LatLng>((e) => LatLng(e[1], e[0])).toList();
          time = "${(sum['duration'] / 60).toStringAsFixed(0)} นาที";
        });

        if (route.isNotEmpty) {
          final bounds = LatLngBounds.fromPoints(route);
          mapCtrl.fitBounds(bounds,
              options: const FitBoundsOptions(padding: EdgeInsets.all(50)));
        }
      } else {
        msg("ไม่สามารถดึงเส้นทางได้ ${res.statusCode}");
      }
    } catch (e) {
      msg("ไม่สามารถดึงเส้นทางได้: $e");
    }
  }

  void add() {
    final q = int.tryParse(qtyCtrl.text) ?? 0;
    final cmt = commentCtrl.text.trim();

    if (q <= 0) {
      msg("กรุณากรอกจำนวนมากกว่า 0");
      return;
    }

    Cart.addItem("ผัดไทย${cmt.isNotEmpty ? ' ($cmt)' : ''}", price, q);

    qtyCtrl.clear();
    commentCtrl.clear();
    setState(() => total = 0);

    msg("เพิ่มลงตะกร้าแล้ว");
  }

  Future<void> submit() async {
    if (Cart.items.isEmpty) {
      msg("ตะกร้าว่าง");
      return;
    }

    try {
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
    } catch (e) {
      msg("เกิดข้อผิดพลาดในการบันทึก: $e");
    }
  }

  void msg(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ผัดไทย")),
      bottomNavigationBar: _bottomOrderBar(),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _shopHeader(),
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

  Widget _shopHeader() => Card(
        child: ListTile(
          leading: const Icon(Icons.store, color: Colors.deepOrange),
          title: const Text("ผัดไทย"),
          subtitle: Text("Lat: $shopLat\nLng: $shopLng"),
        ),
      );

  Widget _ingredientSection() => Card(
        child: ExpansionTile(
          title: const Text("วัตถุดิบ (1 ชาม)"),
          children: const [
            ListTile(
              title: Text(
                  "- เส้น\n- กุ้ง/ผัก\n- ไข่\n- น้ำตาล\n- ซีอิ๊ว\n- น้ำปลา\n- พริก\n- มะนาว/ลวก"),
            ),
          ],
        ),
      );

  Widget _recipeSection() => Card(
        child: ExpansionTile(
          title: const Text("วิธีทำ"),
          children: const [
            ListTile(
              title: Text(
                "1. ผัดเส้นกับน้ำมัน ใส่ไข่และเต้าหู้\n"
                "2. ใส่กุ้ง ปรุงรสผัดให้เข้ากัน\n"
                "3. ใส่ถั่วงอก กุยช่าย คลุกแล้วตักเสิร์ฟ\n",
              ),
            ),
          ],
        ),
      );

  Widget _videoSection() => ExpansionTile(
        title: const Text("วิดีโอสอนทำอาหาร"),
        children: [
          SizedBox(
            height: 220,
            child: YoutubePlayer(controller: _yt, showVideoProgressIndicator: true),
          ),
        ],
      );

  Widget _mapSection() => ExpansionTile(
        title: const Text("แผนที่ร้าน & พิกัด"),
        children: [
          SizedBox(
            height: 300,
            child: FlutterMap(
              mapController: mapCtrl,
              options: MapOptions(center: LatLng(shopLat, shopLng), zoom: 14),
              children: [
                TileLayer(
                  urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                  subdomains: const ['a', 'b', 'c'],
                ),
                MarkerLayer(markers: [
                  Marker(
                    point: LatLng(shopLat, shopLng),
                    width: 40,
                    height: 40,
                    builder: (_) =>
                        const Icon(Icons.location_on, color: Colors.red, size: 40),
                  ),
                  if (lat != null && lng != null)
                    Marker(
                      point: LatLng(lat!, lng!),
                      width: 40,
                      height: 40,
                      builder: (_) =>
                          const Icon(Icons.my_location, color: Colors.blue, size: 40),
                    ),
                ]),
                if (route.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(points: route, strokeWidth: 4, color: Colors.blue)
                    ],
                  )
              ],
            ),
          ),
          ElevatedButton(
              onPressed: getLocation, child: const Text("อ่านพิกัดปัจจุบัน")),
          if (distance > 0)
            Text("ระยะทาง: ${distance.toStringAsFixed(2)} กม.",
                style: const TextStyle(fontWeight: FontWeight.bold)),
          if (time.isNotEmpty)
            Text("เวลาเดินทางโดยรถยนต์: $time",
                style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      );

  Widget _orderSection() => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("สั่งอาหาร", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("ราคา $price บาท / ชาม"),
                TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "จำนวน")),
                TextField(
                    controller: commentCtrl,
                    decoration: const InputDecoration(labelText: "หมายเหตุ เช่น ไม่ใส่ผัก")),
                Text("รวม: $total บาท", style: const TextStyle(fontSize: 18)),
                ElevatedButton(onPressed: calc, child: const Text("คำนวณราคา")),
              ]),
        ),
      );

  Widget _bottomOrderBar() => BottomAppBar(
        child: Row(
          children: [
            Expanded(
                child: ElevatedButton.icon(
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text("เพิ่ม"),
              onPressed: add,
            )),
            const SizedBox(width: 10),
            Expanded(
                child: ElevatedButton.icon(
              icon: const Icon(Icons.send),
              label: const Text("ส่งคำสั่งซื้อ"),
              onPressed: submit,
            )),
          ],
        ),
      );
}
