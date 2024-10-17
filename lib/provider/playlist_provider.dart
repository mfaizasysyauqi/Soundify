import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PlaylistProvider with ChangeNotifier {
  String _playlistName = '';
  String _playlistImageUrl = '';
  String _playlistDescription = '';
  String _creatorId = '';
  String _playlistId = '';
  DateTime _timestamp = DateTime.now();
  int _playlistUserIndex = 0;
  List _songListIds = [];
  int _totalDuration = 0;

  bool _isFetching = false; // Status fetch operation
  bool _isFetched = false; // Flag for caching if data is fetched

  // Getters
  String get playlistName => _playlistName;
  String get playlistImageUrl => _playlistImageUrl;
  String get playlistDescription => _playlistDescription;
  String get creatorId => _creatorId;
  String get playlistId => _playlistId;
  DateTime get timestamp => _timestamp;
  int get playlistUserIndex => _playlistUserIndex;
  List get songListIds => _songListIds;
  int get totalDuration => _totalDuration;

  bool get isFetching => _isFetching;
  bool get isFetched => _isFetched;

  // Function to update playlist data
  void updatePlaylist(
    String newImageUrl,
    String newName,
    String newDescription,
    String newCreatorId,
    String newPlaylistId,
    DateTime newTimestamp,
    int newPlaylistUserIndex,
    List newSongListIds,
    int newTotalDuration,
  ) {
    _playlistImageUrl = newImageUrl;
    _playlistName = newName;
    _playlistDescription = newDescription;
    _creatorId = newCreatorId;
    _playlistId = newPlaylistId;
    _timestamp = newTimestamp;
    _playlistUserIndex = newPlaylistUserIndex;
    _songListIds = newSongListIds;
    _totalDuration = newTotalDuration;

    _isFetched = true; // Mark as fetched
    notifyListeners(); // Notify listeners once after all updates
  }

  Future<void> fetchPlaylistById(String playlistId) async {
    if (_isFetching || (_isFetched && _playlistId == playlistId)) {
      return; // Avoid redundant fetches
    }

    // Reset state if a new playlistId is being fetched
    if (_playlistId != playlistId) {
      resetPlaylist();
    }

    _playlistId = playlistId; // Update the playlist ID
    _isFetching = true;
    notifyListeners(); // Notify listeners that fetching is starting

    try {
      // Fetch playlist data from Firestore
      DocumentSnapshot playlistSnapshot = await FirebaseFirestore.instance
          .collection('playlists')
          .doc(playlistId)
          .get();

      if (playlistSnapshot.exists) {
        // Extract data from Firestore document
        Map<String, dynamic> data =
            playlistSnapshot.data() as Map<String, dynamic>;

        // Update state with new playlist data
        _updatePlaylistData(data, playlistId);
      } else {
        throw Exception('Playlist not found');
      }
    } catch (error) {
      print('Error fetching playlist: $error');
    } finally {
      _isFetching = false;
      notifyListeners(); // Notify listeners that fetching has finished
    }
  }

  // New method to update playlist data
  void _updatePlaylistData(Map<String, dynamic> data, String playlistId) {
    _playlistImageUrl = data['playlistImageUrl'] ?? '';
    _playlistName = data['playlistName'] ?? '';
    _playlistDescription = data['playlistDescription'] ?? '';
    _creatorId = data['creatorId'] ?? '';
    _playlistId = playlistId;
    _timestamp = (data['timestamp'] as Timestamp).toDate();
    _playlistUserIndex = data['playlistUserIndex'] ?? 0;
    _songListIds = List<String>.from(data['songListIds'] ?? []);
    _totalDuration = data['totalDuration'] ?? 0;
    _isFetched = true;
    // No notifyListeners() here, it will be called in fetchPlaylistById
  }

  // Function to reset the playlist data
  void resetPlaylist() {
    _playlistName = '';
    _playlistImageUrl = '';
    _playlistDescription = '';
    _creatorId = '';
    _playlistId = '';
    _timestamp = DateTime.now();
    _playlistUserIndex = 0;
    _songListIds = [];
    _totalDuration = 0;
    _isFetched = false;
    notifyListeners(); // Notify listeners that playlist has been reset
  }
}
