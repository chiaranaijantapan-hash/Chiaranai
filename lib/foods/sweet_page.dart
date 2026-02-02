import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cart.dart';

class SweetPage extends StatefulWidget {
  const SweetPage({super.key});

  @override
  State<SweetPage> createState() => _SweetPageState();
}

class _SweetPageState extends State<SweetPage> {
  late YoutubePlayerController _ytController;

  final int price = 45;
  final TextEditingController qtyCtrl = TextEditingController();
  final TextEditingController commentCtrl = TextEditingController();
  int totalPrice = 0;

  final double shopLatitude = 18.28169;
  final double shopLongitude = 99.51068;

  double? currentLat;
  double? currentLng;
  double distance = 0;
  String travelTime = '';

  final MapController _mapController = MapController();
  List<LatLng> routePoints = [];
  final String orsApiKey = "YOUR_ORS_API_KEY";

  bool isFollowingUser = false;

  @override
  void initState() {
    super.initState();
    final videoId = YoutubePlayer.convertUrlToId(
        'https://www.youtube.com/watch?v=BHfMW2Nxxhg');
    _ytController = YoutubePlayerController(
      initialVideoId: videoId ?? 'dQw4w9WgXcQ',
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

  void calcPrice() {
    final qty = int.tryParse(qtyCtrl.text) ?? 0;
    setState(() => totalPrice = qty * price);
  }

  Future<void> _getCurrentLocationSafe() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return _showMessage("กรุณาเปิด GPS");

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        return _showMessage("กรุณาเปิดสิทธิ์ Location ใน Settings");
      }

      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        currentLat = pos.latitude;
        currentLng = pos.longitude;
        distance = Geolocator.distanceBetween(
                currentLat!, currentLng!, shopLatitude, shopLongitude) /
            1000;
      });

      if (isFollowingUser && currentLat != null) {
        _mapController.move(LatLng(currentLat!, currentLng!), 15);
      }

      await _fetchRoute();
    } catch (e) {
      _showMessage("ไม่สามารถอ่านพิกัด: $e");
    }
  }

  Future<void> _fetchRoute() async {
    if (currentLat == null || currentLng == null) return;

    try {
      final uri = Uri.parse(
          'https://api.openrouteservice.org/v2/directions/driving-car/geojson');
      final res = await http.post(
        uri,
        headers: {
          "Authorization": orsApiKey,
          "Content-Type": "application/json"
        },
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
          routePoints = pts
              .map<LatLng>((e) => LatLng(e[1].toDouble(), e[0].toDouble()))
              .toList();
          travelTime = "${(sum['duration'] / 60).toStringAsFixed(0)} นาที";
        });
      }
    } catch (e) {
      _showMessage("ดึงเส้นทางไม่ได้: $e");
    }
  }

  void _toggleFollow() {
    setState(() => isFollowingUser = !isFollowingUser);
    if (isFollowingUser && currentLat != null) {
      _mapController.move(LatLng(currentLat!, currentLng!), 15);
    }
  }

  void _addToCart() {
    final qty = int.tryParse(qtyCtrl.text) ?? 0;
    final comment = commentCtrl.text.trim();

    if (qty <= 0) return _showMessage("กรุณากรอกจำนวน");

    Cart.addItem(
        "กะเพรา${comment.isNotEmpty ? ' ($comment)' : ''}", price, qty);

    qtyCtrl.clear();
    commentCtrl.clear();
    setState(() => totalPrice = 0);
    _showMessage("เพิ่มลงตะกร้าแล้ว");
  }

  Future<void> _submitCart() async {
    if (Cart.items.isEmpty) return _showMessage("ตะกร้าว่าง");

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
      _showMessage("สั่งสำเร็จแล้ว");
    } catch (e) {
      _showMessage("บันทึกผิดพลาด: $e");
    }
  }

  void _showMessage(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  //---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("กะเพรา")),
      bottomNavigationBar: _bottomOrderBar(),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
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

  Widget _videoSection() => ExpansionTile(
        title: const Text("วิดีโอสอนทำอาหาร"),
        children: [
          SizedBox(
              height: 220,
              child: YoutubePlayer(
                  controller: _ytController,
                  showVideoProgressIndicator: true)),
        ],
      );

  Widget _mapSection() => ExpansionTile(
        title: const Text("ตำแหน่ง & แผนที่"),
        children: [
          SizedBox(
            height: 300,
            child: FlutterMap(
              mapController: _mapController,
              options:
                  MapOptions(center: LatLng(shopLatitude, shopLongitude), zoom: 14),
              children: [
                TileLayer(
                    urlTemplate:
                        "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                    subdomains: const ['a', 'b', 'c']),
                MarkerLayer(markers: [
                  Marker(
                      point: LatLng(shopLatitude, shopLongitude),
                      width: 40,
                      height: 40,
                      builder: (_) =>
                          const Icon(Icons.store, color: Colors.red)),
                  if (currentLat != null && currentLng != null)
                    Marker(
                        point: LatLng(currentLat!, currentLng!),
                        width: 40,
                        height: 40,
                        builder: (_) =>
                            const Icon(Icons.person_pin_circle, color: Colors.blue)),
                ]),
                if (routePoints.isNotEmpty)
                  PolylineLayer(
                      polylines: [
                        Polyline(points: routePoints, strokeWidth: 4)
                      ])
              ],
            ),
          ),
          Row(
            children: [
              ElevatedButton(
                  onPressed: _getCurrentLocationSafe,
                  child: const Text("อ่านพิกัด")),
              const SizedBox(width: 10),
              ElevatedButton(
                  onPressed: _toggleFollow,
                  style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isFollowingUser ? Colors.green : Colors.blue),
                  child: Text(isFollowingUser ? "Following" : "Follow User")),
            ],
          ),
          if (distance > 0)
            Text("ระยะทาง: ${distance.toStringAsFixed(2)} กม."),
          if (travelTime.isNotEmpty) Text("เวลาเดินทาง: $travelTime"),
        ],
      );

  Widget _orderSection() => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("ราคา $price บาท / จาน"),
            TextField(
                controller: qtyCtrl,
                decoration: const InputDecoration(labelText: "จำนวน"),
                keyboardType: TextInputType.number),
            TextField(
                controller: commentCtrl,
                decoration: const InputDecoration(labelText: "หมายเหตุ")),
            Text("รวม: $totalPrice บาท", style: const TextStyle(fontSize: 18)),
            ElevatedButton(onPressed: calcPrice, child: const Text("คำนวณราคา")),
          ]),
        ),
      );

  Widget _bottomOrderBar() => BottomAppBar(
        child: Row(children: [
          Expanded(
              child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text("เพิ่ม"),
                  onPressed: _addToCart)),
          Expanded(
              child: ElevatedButton.icon(
                  icon: const Icon(Icons.send),
                  label: const Text("ส่งคำสั่งซื้อ"),
                  onPressed: _submitCart)),
        ]),
      );
}
