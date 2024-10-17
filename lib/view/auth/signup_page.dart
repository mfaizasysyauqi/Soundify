import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:soundify/view/auth/login_page.dart';
import 'package:soundify/view/style/style.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final usernameController = TextEditingController();
  Future<void> register() async {
    if (!validateFields()) {
      return;
    }

    try {
      bool isUsed = await isEmailUsed(emailController.text.trim());
      if (isUsed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email sudah digunakan sebelumnya!'),
          ),
        );
        return;
      }

      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
              email: emailController.text.trim(),
              password: passwordController.text.trim());

      String userId = userCredential.user!.uid;

      await FirebaseFirestore.instance.collection('users').doc(userId).set(
        {
          'userId': userId,
          'name': nameController.text,
          'username': usernameController.text,
          'profileImageUrl': '',
          'bioImageUrl': '',
          'bio': '',
          'role': 'user',
          'followers': [],
          'following': [],
          'lastListenedSongId': '',
          'lastVolumeLevel': 0.0,
        },
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } catch (e) {
      print("Error: ${e.toString()}");
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryColor,
      body: Padding(
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
                    borderSide: BorderSide(
                      color: primaryTextColor,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: primaryTextColor,
                    ),
                  ),
                  hoverColor: primaryTextColor,
                  focusColor: primaryTextColor,
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
                  hoverColor: primaryTextColor,
                  focusColor: primaryTextColor,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: TextFormField(
                style: const TextStyle(color: primaryTextColor),
                controller: nameController,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.all(8),
                  hintText: 'Enter your full name',
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
                  hoverColor: primaryTextColor,
                  focusColor: primaryTextColor,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: TextFormField(
                style: const TextStyle(color: primaryTextColor),
                controller: usernameController,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.all(8),
                  hintText: 'Enter your username',
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
                  hoverColor: primaryTextColor,
                  focusColor: primaryTextColor,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: SizedBox(
                height: 42,
                child: ElevatedButton(
                  onPressed: register,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: transparentColor),
                  child: const Text(
                    "Sign up",
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
                  "Sudah punya akun?",
                  style: TextStyle(color: primaryTextColor),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const LoginPage()));
                  },
                  child: const Text(
                    "Login",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: secondaryColor),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Future<bool> isEmailUsed(String email) async {
    final QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .get();

    return querySnapshot.docs.isNotEmpty;
  }

  bool validateFields() {
    if (emailController.text.isEmpty ||
        passwordController.text.isEmpty ||
        nameController.text.isEmpty ||
        usernameController.text.isEmpty) {
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
