import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // เพิ่มการ import firestore
import 'firebase_options.dart';

// --- Import ส่วนของหน้าต่างๆ (ตรวจสอบชื่อไฟล์ให้ถูกต้อง) ---
import 'foods/padthai_page.dart';
import 'foods/sweet_page.dart';
import 'foods/srtwc_page.dart';
import 'foods/radna_page.dart';
import 'snacks/brownie_page.dart';
import 'snacks/cake_page.dart';
import 'snacks/icecream_page.dart';
import 'pages/bill_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const FoodApp());
}

class FoodApp extends StatelessWidget {
  const FoodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Food App Delivery',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Kanit', 
        colorSchemeSeed: Colors.orange,
        scaffoldBackgroundColor: const Color(0xFFFBFBFB),
      ),
      routes: {
        '/padthai': (_) => const PadThaiPage(),
        '/radna': (_) => const RadnaPage(),
        '/srtwc': (_) => const SrtwcPage(),
        '/sweet': (_) => const SweetPage(),
        '/brownie': (_) => const BrowniePage(),
        '/cake': (_) => const CakePage(),
        '/icecream': (_) => const IcecreamPage(),
        '/bill': (_) => const BillPage(),
      },
      home: const FoodMenuPage(),
    );
  }
}

// โมเดลข้อมูลเมนู
class MenuItem {
  final String title;
  final String image;
  final String route;
  final String price;

  MenuItem({
    required this.title,
    required this.image,
    required this.route,
    this.price = "50",
  });
}

class FoodMenuPage extends StatelessWidget {
  const FoodMenuPage({super.key});

  // ฟังก์ชันส่งข้อมูลไปยัง Firestore (กดที่ Banner เพื่อทดสอบ)
  Future<void> _testFirebaseConnection() async {
    try {
      await FirebaseFirestore.instance.collection('users').add({
        'name': 'chiaranai',
        'status': 'Connected!',
        'timestamp': FieldValue.serverTimestamp(),
      });
      print("เชื่อมต่อและส่งข้อมูลสำเร็จ!");
    } catch (e) {
      print("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final savoryFoods = [
      MenuItem(title: 'ข้าวมันไก่', image: 'assets/1.jpg', route: '/srtwc', price: "55"),
      MenuItem(title: 'กะเพราหมู', image: 'assets/2.png', route: '/sweet', price: "60"),
      MenuItem(title: 'ราดหน้า', image: 'assets/3.jpg', route: '/radna', price: "50"),
      MenuItem(title: 'ผัดไทย', image: 'assets/4.png', route: '/padthai', price: "65"),
    ];

    final desserts = [
      MenuItem(title: 'บราวนี่', image: 'assets/5.png', route: '/brownie', price: "45"),
      MenuItem(title: 'เค้กช็อกโกแลต', image: 'assets/6.png', route: '/cake', price: "85"),
      MenuItem(title: 'ไอศกรีม', image: 'assets/7.png', route: '/icecream', price: "35"),
    ];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: true,
            expandedHeight: 60,
            backgroundColor: const Color.fromARGB(193, 146, 220, 243).withOpacity(0.9),
            title: const Text(
              'chiaranai_pic Food',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Colors.black),
            ),
            actions: [
              IconButton(
                onPressed: () => Navigator.pushNamed(context, '/bill'),
                icon: const Icon(Icons.shopping_cart_outlined, color: Colors.black),
              ),
              const SizedBox(width: 10),
            ],
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchBar(),
                
                // แก้ไขส่วน Banner ให้กดแล้วส่งข้อมูลไป Firebase ได้จริง
                GestureDetector(
                  onTap: () {
                    _testFirebaseConnection();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ส่งข้อมูล "chiaranai" ไปยัง Firestore แล้ว!'))
                    );
                  },
                  child: _buildHeroBanner(),
                ),

                // แสดงสถานะการเชื่อมต่อจาก Firestore (ดึงข้อมูลล่าสุดมาโชว์)
                _buildFirestoreStatus(),

                _buildSectionHeader('Recommended for You'),
                SliverHorizontalList(items: savoryFoods),
                
                _buildSectionHeader('Delicious Desserts'),
                _buildDessertGrid(desserts),
                
                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // วิดเจ็ตแสดงข้อมูลล่าสุดจาก Firestore
  Widget _buildFirestoreStatus() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').orderBy('timestamp', descending: true).limit(1).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Text('Error connecting to Firestore');
            if (snapshot.connectionState == ConnectionState.waiting) return const Text('Connecting...');
            if (snapshot.data!.docs.isEmpty) return const Text('ยังไม่มีข้อมูลในระบบ');

            var lastUser = snapshot.data!.docs.first;
            return Row(
              children: [
                const Icon(Icons.cloud_done, color: Colors.green),
                const SizedBox(width: 10),
                Text('ล่าสุด: ${lastUser['name']} - ${lastUser['status']}'),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- UI Components คงเดิมตามที่คุณส่งมา ---
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 15),
      height: 55,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: const Row(
        children: [
          Icon(Icons.search, color: Colors.orange),
          SizedBox(width: 10),
          Text('Search your favorite food...', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      margin: const EdgeInsets.all(20),
      height: 140,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        image: const DecorationImage(
          image: NetworkImage('https://images.unsplash.com/photo-1504674900247-0877df9cc836?q=80&w=1000&auto=format&fit=crop'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: LinearGradient(
            colors: [Colors.black.withOpacity(0.7), Colors.transparent],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Test Connection', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
            Text('Click to send data to Firestore!', style: TextStyle(color: Colors.white70, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const Text('See All', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDessertGrid(List<MenuItem> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 15,
        crossAxisSpacing: 15,
        childAspectRatio: 0.8,
      ),
      itemBuilder: (context, i) => _buildModernCard(context, items[i]),
    );
  }

  Widget _buildModernCard(BuildContext context, MenuItem item) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, item.route),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Image.asset(item.image, width: double.infinity, fit: BoxFit.cover),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('฿${item.price}', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.orange)),
                      const Icon(Icons.add_circle, color: Colors.black, size: 24),
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

// --- ส่วนวิดเจ็ตแนวนอน (SliverHorizontalList) ตามโค้ดเดิมของคุณ ---
class SliverHorizontalList extends StatelessWidget {
  final List<MenuItem> items;
  const SliverHorizontalList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        padding: const EdgeInsets.only(left: 20, right: 5),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          return GestureDetector(
            onTap: () => Navigator.pushNamed(context, item.route),
            child: Container(
              width: 160,
              margin: const EdgeInsets.only(right: 15, bottom: 10, top: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: Image.asset(item.image, height: 120, width: 160, fit: BoxFit.cover),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text('฿${item.price}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w900, fontSize: 16)),
                      ],
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}