import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:soundify/view/auth/signup_page.dart';
import 'package:soundify/view/pages/container/primary/home_container.dart';
import 'package:soundify/view/pages/main_page.dart';
import 'package:soundify/view/pages/container/secondary/show_detail_song.dart';
import 'package:soundify/view/style/style.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  void clearTextFields() {
    emailController.clear(); // Mengosongkan nilai email pada text field
    passwordController.clear(); // Mengosongkan nilai password pada text field
  }

  Future<void> login() async {
    if (!validateFields()) {
      return;
    }

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>  const MainPage(
            activeWidget1: HomeContainer(),
            activeWidget2: ShowDetailSong(),
          ),
        ),
      );
      clearTextFields();
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email atau password salah!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryColor,
      body: SafeArea(
          child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Spacer(),
            const Column(
              children: [
                Center(
                  child: Center(
                    child: Text(
                      'Soundify',
                      style: TextStyle(
                        fontSize: 64,
                        color: secondaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: TextFormField(
                style: const TextStyle(color: primaryTextColor),
                controller: emailController,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.all(8),
                  hintText: 'Enter your email',
                  hintStyle: TextStyle(color: primaryTextColor),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: primaryTextColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: primaryTextColor,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: TextFormField(
                style: const TextStyle(color: primaryTextColor),
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.all(8),
                  hintText: 'Enter your password',
                  hintStyle: TextStyle(color: primaryTextColor),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: primaryTextColor,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: primaryTextColor,
                    ),
                  ),
                ),
              ),
            ),
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.end,
            //   children: [
            //     TextButton(
            //       onPressed: () {},
            //       child: const Text(
            //         'Forgot password',
            //         style: TextStyle(
            //           color: primaryTextColor,
            //         ),
            //       ),
            //     ),
            //   ],
            // ),
            Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: SizedBox(
                height: 42,
                child: ElevatedButton(
                  onPressed: login,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: transparentColor),
                  child: const Text(
                    "Login",
                    style: TextStyle(
                      color: secondaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Belum punya akun?",
                  style: TextStyle(color: primaryTextColor),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SignUpPage()));
                  },
                  child: const Text(
                    "Sign up",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: secondaryColor,
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      )),
    );
  }

  bool validateFields() {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap lengkapi semua field!'),
        ),
      );
      return false;
    }
    return true;
  }
}
