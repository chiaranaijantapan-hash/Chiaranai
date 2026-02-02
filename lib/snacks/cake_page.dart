import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cart.dart';

class CakePage extends StatefulWidget {
  const CakePage({super.key});

  @override
  State<CakePage> createState() => _CakePageState();
}

class _CakePageState extends State<CakePage> {
  late YoutubePlayerController _yt;
  final TextEditingController qtyCtrl = TextEditingController();
  final TextEditingController noteCtrl = TextEditingController();

  final int price = 250;
  int total = 0;

  // พิกัดร้านเค้ก
  final shopLat = 18.283941261524387;
  final shopLng = 99.49677414174985;

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
    final id = YoutubePlayer.convertUrlToId('https://www.youtube.com/watch?v=1vWgqMFZV6s');
    _yt = YoutubePlayerController(
      initialVideoId: id ?? '',
      flags: const YoutubePlayerFlags(autoPlay: false),
    );
    qtyCtrl.addListener(() {
      final q = int.tryParse(qtyCtrl.text) ?? 0;
      setState(() => total = q * price);
    });
  }

  @override
  void dispose() {
    _yt.dispose();
    qtyCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  //---------------- LOGIC ----------------

  Future<void> getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      msg("กรุณาเปิด GPS ในมือถือของคุณ");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        msg("สิทธิ์ Location ถูกปฏิเสธ");
        return;
      }
    }

    msg("กำลังระบุตำแหน่งของคุณ...");
    final pos = await Geolocator.getCurrentPosition();
    setState(() {
      lat = pos.latitude;
      lng = pos.longitude;
      distance = Geolocator.distanceBetween(lat!, lng!, shopLat, shopLng) / 1000;
    });

    // เลื่อนแผนที่ไปจุดที่เราอยู่
    mapCtrl.move(LatLng(lat!, lng!), 14);
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
          route = pts.map((e) => LatLng(e[1], e[0])).toList();
          time = "${(sum['duration'] / 60).toStringAsFixed(0)} นาที";
        });
      } else {
        print("ORS Error: ${res.body}");
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  void add() {
    final q = int.tryParse(qtyCtrl.text) ?? 0;
    if (q <= 0) {
      msg("กรุณากรอกจำนวนมากกว่า 0");
      return;
    }
    Cart.addItem("เค้กช็อกโกแลต", price, q);
    qtyCtrl.clear();
    noteCtrl.clear();
    setState(() => total = 0);
    msg("เพิ่มเค้กลงตะกร้าแล้ว 🍰");
  }

  Future<void> submit() async {
    if (Cart.items.isEmpty) {
      msg("ตะกร้ายังว่างอยู่");
      return;
    }

    await FirebaseFirestore.instance.collection("orders").add({
      "items": Cart.items.map((e) => {"name": e.name, "price": e.price, "qty": e.qty}).toList(),
      "total": Cart.totalPrice(),
      "time": FieldValue.serverTimestamp(),
    });

    Cart.clear();
    setState(() {});
    msg("สั่งซื้อเค้กสำเร็จ!");
  }

  void msg(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  //---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chocolate Cake"),
        backgroundColor: Colors.brown[400],
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: _bottomOrderBar(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _shopHeader(),
          const SizedBox(height: 12),
          _infoSection(),
          const SizedBox(height: 12),
          _videoSection(),
          const SizedBox(height: 12),
          _mapSection(),
          const SizedBox(height: 12),
          _orderSection(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _shopHeader() => Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: ListTile(
          leading: const CircleAvatar(backgroundColor: Colors.brown, child: Icon(Icons.cake, color: Colors.white)),
          title: const Text("Homemade Cake Shop", style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("พิกัด: $shopLat, $shopLng"),
        ),
      );

  Widget _infoSection() => Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: const ExpansionTile(
          leading: Icon(Icons.receipt_long, color: Colors.brown),
          title: Text("ส่วนผสมคัดพิเศษ"),
          children: [
            ListTile(title: Text("• ช็อกโกแลตเบลเยียมเข้มข้น\n• แป้งเค้กเนื้อนุ่ม\n• เนยสดแท้\n• ไข่ไก่ออร์แกนิก")),
          ],
        ),
      );

  Widget _videoSection() => Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: ExpansionTile(
          leading: const Icon(Icons.play_circle_fill, color: Colors.red),
          title: const Text("ชมวิธีการทำ"),
          children: [
            SizedBox(height: 220, child: YoutubePlayer(controller: _yt)),
          ],
        ),
      );

  Widget _mapSection() => Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          leading: const Icon(Icons.map, color: Colors.blue),
          title: const Text("แผนที่ร้านและการเดินทาง"),
          children: [
            SizedBox(
              height: 280,
              child: FlutterMap(
                mapController: mapCtrl,
                options: MapOptions(center: LatLng(shopLat, shopLng), zoom: 14),
                children: [
                  TileLayer(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png"),
                  MarkerLayer(markers: [
                    Marker(
                        point: LatLng(shopLat, shopLng),
                        width: 45,
                        height: 45,
                        builder: (_) => const Icon(Icons.location_on, color: Colors.red, size: 40)),
                    if (lat != null)
                      Marker(
                          point: LatLng(lat!, lng!),
                          width: 45,
                          height: 45,
                          builder: (_) => const Icon(Icons.my_location, color: Colors.blue, size: 35)),
                  ]),
                  if (route.isNotEmpty)
                    PolylineLayer(polylines: [
                      Polyline(points: route, strokeWidth: 5, color: Colors.blue.withOpacity(0.7))
                    ])
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.navigation),
                onPressed: getLocation, 
                label: const Text("อ่านพิกัดเพื่อแสดงเส้นทาง")
              ),
            ),
            if (distance > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text("ห่างจากคุณ: ${distance.toStringAsFixed(2)} กม. ($time)", 
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brown)),
              ),
          ],
        ),
      );

  Widget _orderSection() => Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, 
            children: [
              const Text("ระบุจำนวนการสั่งซื้อ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(),
              TextField(
                controller: qtyCtrl, 
                keyboardType: TextInputType.number, 
                decoration: InputDecoration(
                  labelText: "จำนวนชิ้น (ชิ้นละ $price บาท)",
                  prefixIcon: const Icon(Icons.shopping_basket)
                )
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteCtrl, 
                decoration: const InputDecoration(
                  labelText: "หมายเหตุเพิ่มเติม",
                  prefixIcon: const Icon(Icons.note_add)
                )
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("ราคารวมทั้งหมด:", style: TextStyle(fontSize: 16)),
                  Text("฿ $total", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.brown)),
                ],
              ),
            ]
          ),
        ),
      );

  Widget _bottomOrderBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey, width: 0.2))),
    child: Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            icon: const Icon(Icons.add_shopping_cart), 
            label: const Text("ใส่ตะกร้า"), 
            onPressed: add
          )
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.brown, foregroundColor: Colors.white),
            icon: const Icon(Icons.send), 
            label: const Text("ชำระเงิน"), 
            onPressed: submit
          )
        ),
      ],
    ),
  );
}