import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("นางสาวเจียระไน จันทะปัน"),
        backgroundColor: Colors.teal,
        actions: const [
          Icon(Icons.settings, color: Colors.white),
          SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text(
              "นางสาวเจียระไน จันทะปัน  |  เลขที่ 21  ",
              style: TextStyle(fontSize: 20, color: Colors.black87),
            ),
            SizedBox(width: 8),
            Icon(
              Icons.favorite,
              color: Colors.pink,
              size: 28,
            ),
          ],
        ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "next",
            onPressed: () {},
            backgroundColor: Colors.green,
            child: const Icon(Icons.arrow_forward),
          ),
          const SizedBox(width: 15),
          FloatingActionButton(
            heroTag: "exit",
            onPressed: () {},
            backgroundColor: Colors.deepOrange,
            child: const Icon(Icons.logout),
          ),
        ],
      ),
    );
  }
}
