import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:soundify/firebase_options.dart';
import 'package:soundify/provider/album_provider.dart';
import 'package:soundify/provider/image_provider.dart';

import 'package:soundify/provider/playlist_provider.dart';
import 'package:provider/provider.dart';
import 'package:soundify/provider/song_provider.dart';
import 'package:soundify/provider/widget_size_provider.dart';
import 'package:soundify/provider/widget_state_provider_1.dart';
import 'package:soundify/provider/widget_state_provider_2.dart';
import 'package:soundify/view/pages/splash_screen.dart';
// FirebaseAuth for authentication

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Bungkus aplikasi dengan MultiProvider dan SongProvider
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ImageProviderData()),
        ChangeNotifierProvider(create: (_) => PlaylistProvider()),
        ChangeNotifierProvider(create: (_) => WidgetStateProvider1()),
        ChangeNotifierProvider(create: (_) => WidgetStateProvider2()),
        ChangeNotifierProvider(create: (_) => AlbumProvider()),
        ChangeNotifierProvider(create: (_) => SongProvider()),
        ChangeNotifierProvider(create: (_) => WidgetSizeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Soundify',
      home: SplashScreen(), // Ganti ke SplashScreen
      debugShowCheckedModeBanner: false,
    );
  }
}
