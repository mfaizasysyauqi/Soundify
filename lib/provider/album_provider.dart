import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AlbumProvider with ChangeNotifier {
  String _albumName = '';
  String _albumImageUrl = '';
  String _albumDescription = '';
  String _creatorId = '';
  String _albumId = '';
  DateTime _timestamp = DateTime.now();
  int _albumUserIndex = 0;
  List _songListIds = [];
  int _totalDuration = 0;

  bool _isFetching = false; // Status fetch operation
  bool _isFetched = false; // Flag for caching if data is fetched

  // Getters
  String get albumName => _albumName;
  String get albumImageUrl => _albumImageUrl;
  String get albumDescription => _albumDescription;
  String get creatorId => _creatorId;
  String get albumId => _albumId;
  DateTime get timestamp => _timestamp;
  int get albumUserIndex => _albumUserIndex;
  List get songListIds => _songListIds;
  int get totalDuration => _totalDuration;

  bool get isFetching => _isFetching;
  bool get isFetched => _isFetched;

  // Function to update album data
  void updateAlbum(
    String newImageUrl,
    String newName,
    String newDescription,
    String newCreatorId,
    String newAlbumId,
    DateTime newTimestamp,
    int newAlbumUserIndex,
    List newSongListIds,
    int newTotalDuration,
  ) {
    _albumImageUrl = newImageUrl;
    _albumName = newName;
    _albumDescription = newDescription;
    _creatorId = newCreatorId;
    _albumId = newAlbumId;
    _timestamp = newTimestamp;
    _albumUserIndex = newAlbumUserIndex;
    _songListIds = newSongListIds;
    _totalDuration = newTotalDuration;

    _isFetched = true; // Mark as fetched
    notifyListeners(); // Notify listeners once after all updates
  }

  Future<void> fetchAlbumById(String albumId) async {
    if (_isFetching || (_isFetched && _albumId == albumId)) {
      return; // Avoid redundant fetches
    }

    // Reset state if a new albumId is being fetched
    if (_albumId != albumId) {
      resetAlbum();
    }

    _albumId = albumId; // Update the album ID
    _isFetching = true;
    notifyListeners(); // Notify listeners that fetching is starting

    try {
      // Fetch album data from Firestore
      DocumentSnapshot albumSnapshot = await FirebaseFirestore.instance
          .collection('albums')
          .doc(albumId)
          .get();

      if (albumSnapshot.exists) {
        // Extract data from Firestore document
        Map<String, dynamic> data =
            albumSnapshot.data() as Map<String, dynamic>;

        // Update state with new album data
        _updateAlbumData(data, albumId);
      } else {
        throw Exception('Album not found');
      }
    } catch (error) {
      print('Error fetching album: $error');
    } finally {
      _isFetching = false;
      notifyListeners(); // Notify listeners that fetching has finished
    }
  }

  // New method to update album data
  void _updateAlbumData(Map<String, dynamic> data, String albumId) {
    _albumImageUrl = data['albumImageUrl'] ?? '';
    _albumName = data['albumName'] ?? '';
    _albumDescription = data['albumDescription'] ?? '';
    _creatorId = data['creatorId'] ?? '';
    _albumId = albumId;
    _timestamp = (data['timestamp'] as Timestamp).toDate();
    _albumUserIndex = data['albumUserIndex'] ?? 0;
    _songListIds = List<String>.from(data['songListIds'] ?? []);
    _totalDuration = data['totalDuration'] ?? 0;
    _isFetched = true;
    // No notifyListeners() here, it will be called in fetchAlbumById
  }

  // Function to manually set a new albumId
  void setAlbumId(String newAlbumId) {
    if (newAlbumId != _albumId) {
      _albumId = newAlbumId;
      _isFetched = false; // Reset the fetched state to force re-fetch
      notifyListeners();
    }
  }

  // Function to reset the album data
  void resetAlbum() {
    _albumName = '';
    _albumImageUrl = '';
    _albumDescription = '';
    _creatorId = '';
    _albumId = '';
    _timestamp = DateTime.now();
    _albumUserIndex = 0;
    _songListIds = [];
    _totalDuration = 0;
    _isFetched = false;
    notifyListeners();
  }

  void resetAlbumId() {
    _albumId = ''; // Reset to default value
    notifyListeners();
  }
}
