import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cart.dart';

class RadnaPage extends StatefulWidget {
  const RadnaPage({super.key});

  @override
  State<RadnaPage> createState() => _RadnaPageState();
}

class _RadnaPageState extends State<RadnaPage> {
  late YoutubePlayerController _yt;

  final int price = 120;
  int total = 0;

  final qtyCtrl = TextEditingController();
  final commentCtrl = TextEditingController();

  final double shopLat = 18.29077;
  final double shopLng = 99.49261;

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
    const videoUrl = 'https://www.youtube.com/watch?v=AMQWpYj4wLU';
    final id = YoutubePlayer.convertUrlToId(videoUrl) ?? '';
    _yt = YoutubePlayerController(initialVideoId: id, flags: const YoutubePlayerFlags(autoPlay: false));
  }

  @override
  void dispose() {
    _yt.dispose();
    qtyCtrl.dispose();
    commentCtrl.dispose();
    super.dispose();
  }

  //---------------- LOGIC ----------------

  void calc() {
    final q = int.tryParse(qtyCtrl.text) ?? 0;
    setState(() => total = q * price);
  }

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

    final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      lat = pos.latitude;
      lng = pos.longitude;
      distance = Geolocator.distanceBetween(lat!, lng!, shopLat, shopLng) / 1000;
    });

    mapCtrl.move(LatLng(lat!, lng!), 15);
    await fetchRoute();
  }

  Future<void> fetchRoute() async {
    if (lat == null || lng == null) return;

    final uri = Uri.parse('https://api.openrouteservice.org/v2/directions/driving-car/geojson');

    final res = await http.post(
      uri,
      headers: {"Authorization": orsApiKey, "Content-Type": "application/json"},
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
    }
  }

  void add() {
    final q = int.tryParse(qtyCtrl.text) ?? 0;
    final cmt = commentCtrl.text.trim();

    if (q <= 0) {
      msg("กรุณากรอกจำนวนมากกว่า 0");
      return;
    }

    Cart.addItem("ราดหน้า${cmt.isNotEmpty ? ' ($cmt)' : ''}", price, q);

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
      "time": FieldValue.serverTimestamp(),
    });

    Cart.clear();
    setState(() {});
    msg("สั่งอาหารเรียบร้อยแล้ว");
  }

  void msg(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  //---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ราดหน้า")),
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
          title: const Text("ราดหน้า"),
          subtitle: Text("Lat: $shopLat\nLng: $shopLng"),
        ),
      );

  Widget _ingredientSection() => Card(
        child: const ExpansionTile(
          title: Text("วัตถุดิบ"),
          children: [
            ListTile(
              title: Text("- เส้น\n- แป้ง\n- ผัก\n- พริก\n- น้ำมะนาว\n- น้ำปลา"),
            ),
          ],
        ),
      );

  Widget _recipeSection() => Card(
        child: const ExpansionTile(
          title: Text("วิธีทำ"),
          children: [
            ListTile(
              title: Text(
                "1. ผัดเส้นกับน้ำมันให้หอม ใส่เนื้อสัตว์\n"
                "2. เติมน้ำซุป ปรุงรส ใส่ผักคะน้า\n"
                "3. ใส่น้ำแป้งให้ข้น ราดบนเส้น",
              ),
            ),
          ],
        ),
      );

  Widget _videoSection() => ExpansionTile(
        title: const Text("วิดีโอสอนทำอาหาร"),
        children: [
          SizedBox(height: 220, child: YoutubePlayer(controller: _yt)),
        ],
      );

  Widget _mapSection() => ExpansionTile(
        title: const Text("แผนที่ร้าน"),
        children: [
          SizedBox(
            height: 260,
            child: FlutterMap(
              mapController: mapCtrl,
              options: MapOptions(center: LatLng(shopLat, shopLng), zoom: 14),
              children: [
                TileLayer(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png"),
                MarkerLayer(markers: [
                  Marker(
                    point: LatLng(shopLat, shopLng),
                    width: 40,
                    height: 40,
                    builder: (_) => const Icon(Icons.location_on, color: Colors.red),
                  ),
                  if (lat != null)
                    Marker(
                      point: LatLng(lat!, lng!),
                      width: 40,
                      height: 40,
                      builder: (_) => const Icon(Icons.my_location, color: Colors.blue),
                    ),
                ]),
                if (route.isNotEmpty)
                  PolylineLayer(polylines: [Polyline(points: route, strokeWidth: 4)]),
              ],
            ),
          ),
          ElevatedButton(onPressed: getLocation, child: const Text("อ่านพิกัดปัจจุบัน")),
          if (distance > 0) Text("ระยะทาง: ${distance.toStringAsFixed(2)} กม."),
          if (time.isNotEmpty) Text("เวลาเดินทางโดยรถยนต์: $time"),
        ],
      );

  Widget _orderSection() => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("สั่งอาหาร", style: TextStyle(fontWeight: FontWeight.bold)),
            Text("ราคา $price บาท / จาน"),
            TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "จำนวน")),
            TextField(
                controller: commentCtrl,
                decoration: const InputDecoration(labelText: "หมายเหตุ")),
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
                    onPressed: add)),
            Expanded(
                child: ElevatedButton.icon(
                    icon: const Icon(Icons.send),
                    label: const Text("ส่งคำสั่งซื้อ"),
                    onPressed: submit)),
          ],
        ),
      );
}
