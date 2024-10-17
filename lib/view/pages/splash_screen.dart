import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:soundify/view/auth/login_page.dart';
import 'package:soundify/view/pages/container/primary/home_container.dart';
import 'package:soundify/view/pages/main_page.dart';
import 'package:soundify/view/pages/container/secondary/show_detail_song.dart';
import 'package:soundify/view/style/style.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkUserLoginStatus(); // Cek status login saat halaman dimulai
  }

  // Cek apakah pengguna sudah login
  void _checkUserLoginStatus() async {
    // Tambahkan penundaan untuk memastikan Firebase selesai memuat
    await Future.delayed(const Duration(seconds: 2));

    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Jika ada pengguna yang sedang login, arahkan ke MainPage
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) =>  const MainPage(
            activeWidget1: HomeContainer(),
            activeWidget2: ShowDetailSong(),
          ),
        ),
      );
    } else {
      // Jika tidak ada pengguna yang login, arahkan ke LoginPage
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryColor,
      body: const Center(
        child: CircularProgressIndicator(
          color: primaryTextColor,
        ), // Spinner saat loading
      ),
    );
  }
}
