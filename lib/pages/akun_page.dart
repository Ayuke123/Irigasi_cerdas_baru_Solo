import 'package:flutter/material.dart';
import 'login_screen.dart';

class ProfilePage extends StatelessWidget {
  final String email;
  final String phone;

  const ProfilePage({
    Key? key,
    required this.email,
    required this.phone,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xffF7F7F7),
      appBar: AppBar(
        title: Text('Profil Pengguna'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Email
            Card(
              color: Colors.grey[400],
              child: ListTile(
                title: Text(
                  'Email',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  email,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            SizedBox(height: 8),
            // Nomor Telepon
            Card(
              color: Colors.grey[400],
              child: ListTile(
                title: Text(
                  'Nomor Telepon',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  phone,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            Spacer(),
            // Tombol Keluar
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, // warna merah
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  // Navigasi kembali ke LoginPage
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => LoginScreen()),
                  );
                },
                child: Text(
                  'KELUAR',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 4, // karena ini tab "Akun"
        type: BottomNavigationBarType.fixed,
        backgroundColor: Color(0xffEDE4F2),
        selectedItemColor: Colors.black87,
        unselectedItemColor: Colors.black54,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Beranda'),
          BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: 'Riwayat'),
          BottomNavigationBarItem(
              icon: Icon(Icons.notifications_none),
              activeIcon: Icon(Icons.notifications),
              label: 'Notifikasi'),
          BottomNavigationBarItem(
              icon: Icon(Icons.cloud_outlined),
              activeIcon: Icon(Icons.cloud),
              label: 'Cuaca'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Akun'),
        ],
      ),
    );
  }
}
