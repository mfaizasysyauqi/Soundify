import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SongProvider with ChangeNotifier {
  String _songId = '';
  String _senderId = '';
  String _artistId = '';
  String _songTitle = '';
  String _profileImageUrl = '';
  String _songImageUrl = '';
  String _bioImageUrl = '';
  String _artistName = '';
  String _songUrl = '';
  int _duration = 0;
  bool _isPlaying = false;
  bool _shouldPlay = false;

  int index = 0; // Index of the song in a list

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String userBio = '';

  // Getters
  String get songId => _songId;
  String get senderId => _senderId;
  String get artistId => _artistId;
  String get songTitle => _songTitle;
  String get profileImageUrl => _profileImageUrl;
  String get songImageUrl => _songImageUrl;
  String get bioImageUrl => _bioImageUrl;
  String get artistName => _artistName;
  String get songUrl => _songUrl;
  int get duration => _duration;
  bool get isPlaying => _isPlaying;

  // Getter for shouldPlay
  bool get shouldPlay => _shouldPlay;

  // Set song details and play
  void setSong(
    String songId,
    String senderId,
    String artistId,
    String title,
    String profileImageUrl,
    String songImageUrl,
    String bioImageUrl,
    String artist,
    String songUrl,
    int duration,
    int songIndex,
  ) async {
    if (_songId != songId) {
      // Only update if the song is different
      stop();
      _songId = songId;
      _senderId = senderId;
      _artistId = artistId;
      _songTitle = title;
      _profileImageUrl = profileImageUrl;
      _songImageUrl = songImageUrl;
      _bioImageUrl = bioImageUrl;
      _artistName = artist;
      _songUrl = songUrl;
      _duration = duration;
      _isPlaying = true;
      index = songIndex;

      fetchUserBio(); // Fetch bio in the background
      notifyListeners(); // Notify listeners after all changes
    }
  }

  void setArtistId(String newArtistId) {
    _artistId = newArtistId;
    notifyListeners();
  }

  void resetArtistId() {
    _artistId = ''; // Reset to default value
    notifyListeners();
  }

  // Method to set shouldPlay, allowing you to control when to autoplay
  void setShouldPlay(bool value) {
    _shouldPlay = value;
    notifyListeners();
  }

  // Fetch user bio
  Future<void> fetchUserBio() async {
    if (userBio.isEmpty) {
      // Only fetch if bio is not already loaded
      try {
        QuerySnapshot querySnapshot = await _firestore
            .collection('users')
            .where('userId', isEqualTo: _artistId)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          userBio = querySnapshot.docs.first['bio'];
          notifyListeners(); // Notify listeners of the update
        }
      } catch (e) {
        print("Error fetching user bio: $e");
      }
    }
  }

  // Play song
  void playSong() {
    if (!_isPlaying) {
      _isPlaying = true;
      // Add your audio player logic here
      notifyListeners();
    }
  }

  // Stop song
  void stop() {
    if (_isPlaying) {
      stopCurrentSong();
      _isPlaying = false;
      notifyListeners();
    }
  }

  void stopCurrentSong() {
    // Stop the current song (e.g., stop the audio player)
  }

  // Pause or resume song
  void pauseOrResume() {
    _isPlaying ? pause() : resume();
  }

  void pause() {
    _isPlaying = false;
    notifyListeners();
  }

  void resume() {
    _isPlaying = true;
    notifyListeners();
  }

  // Fungsi untuk menyimpan lastVolumeLevel ke Firebase
  Future<void> saveVolumeToFirebase(double volume) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'lastVolumeLevel': volume,
        });
      } catch (e) {
        print("Error saving volume to Firebase: $e");
      }
    } else {
      print("No user is logged in.");
    }
  }

  // Fungsi untuk menyimpan lastListenedSong ke Firebase
  Future<void> saveLastListenedSongToFirebase(String songUrl) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'lastListenedSongId': songId,
        });
      } catch (e) {
        print("Error saving last listened song to Firebase: $e");
      }
    }
  }

  // Fungsi untuk mengambil lastVolumeLevel dan lastListenedSong dari Firebase
  Future<Map<String, dynamic>> loadUserPreferences() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
    }
    return {};
  }
}
