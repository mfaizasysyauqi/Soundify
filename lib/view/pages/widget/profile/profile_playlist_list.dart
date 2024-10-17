import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:intl/intl.dart'; // Import intl
import 'package:soundify/view/pages/container/primary/playlist_container.dart';

import 'package:soundify/provider/song_provider.dart';
import 'package:soundify/provider/widget_state_provider_1.dart';
import 'package:soundify/view/style/style.dart'; // Pastikan file style sudah ada
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:firebase_storage/firebase_storage.dart';

import 'package:provider/provider.dart'; // Tambahkan provider

class ProfilePlaylistList extends StatefulWidget {
  const ProfilePlaylistList({
    super.key,
  });

  @override
  State<ProfilePlaylistList> createState() => _ProfilePlaylistListState();
}

final currentUserPlaylist = FirebaseAuth.instance.currentUser;

OverlayEntry? _overlayEntryPlaylist;
bool showModalPlaylist = false;
GlobalKey _iconKey1Playlist = GlobalKey();
GlobalKey _iconKey2Playlist = GlobalKey();

class _ProfilePlaylistListState extends State<ProfilePlaylistList> {
  Future<String> getArtistName(String artistId) async {
    try {
      // Pastikan artistId tidak kosong sebelum mengambil dokumen
      if (artistId.isEmpty) {
        return 'Unknown Artist';
      }

      // Ambil dokumen dari Firestore
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(artistId)
          .get();

      // Cek apakah dokumen benar-benar ada
      if (userDoc.exists && userDoc.data() != null) {
        var userData = userDoc.data() as Map<String, dynamic>;

        return userData['name'] ?? 'Unknown Artist';
      } else {}
    } catch (e) {
      print('Error fetching artist name: $e');
    }
    return 'Unknown Artist';
  }

  // Function to get playlistName based on playlistI

  int _clickedIndex = -1; // -1 means no song is clicked

  @override
  Widget build(BuildContext context) {
    Provider.of<SongProvider>(context);
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('playlists')
          .where('creatorId', isEqualTo: currentUserPlaylist!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error fetching songs'));
        }
        // Jika tidak ada data
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              // 'No playlists available',
              '',
              style: TextStyle(color: primaryTextColor),
            ),
          );
        }

        var playlistDocs = snapshot.data!.docs;

        List<DocumentSnapshot> sortedPlaylistDocs = List.from(playlistDocs);
        sortedPlaylistDocs.sort((a, b) {
          Timestamp timestampA = a['timestamp'] as Timestamp;
          Timestamp timestampB = b['timestamp'] as Timestamp;
          return timestampB.compareTo(timestampA); // Sort descending
        });

        return ListView.builder(
          itemCount: sortedPlaylistDocs.length,
          itemBuilder: (context, index) {
            var playlistData =
                sortedPlaylistDocs[index].data() as Map<String, dynamic>;
            String creatorId = playlistData['creatorId'] ?? '';
            String playlistId = playlistData['playlistId'] ?? '';
            String playlistImageUrl = playlistData['playlistImageUrl'] ?? '';

            List likes = playlistData['likes'] ?? [];
            List songListIds = playlistData['songListIds'] ?? [];
            int artistFileIndex = playlistData['artistFileIndex'] ?? 0;
            int totalDuration = playlistData['totalDuration'] ?? 0;
            String playlistName = playlistData['playlistName'] ?? '';
            Timestamp? timestamp = playlistData['timestamp'];

            return FutureBuilder<String>(
              future: getArtistName(creatorId),
              builder: (context, artistSnapshot) {
                if (!artistSnapshot.hasData) {
                  return const SizedBox.shrink();
                }

                String artistName = artistSnapshot.data ?? 'Unknown Artist';

                String formattedDate = 'Unknown Date';
                if (timestamp != null) {
                  DateTime date = timestamp.toDate();
                  formattedDate = DateFormat('MMM d, yyyy').format(date);
                }

                return ProfilePlaylistListItem(
                  index: index,
                  creatorId: creatorId,
                  artistName: artistName,
                  playlistId: playlistId,
                  playlistName: playlistName,
                  artistFileIndex: artistFileIndex,
                  formattedDate: formattedDate,
                  playlistImageUrl: playlistImageUrl,
                  likedIds: likes,
                  playlistIds: songListIds,
                  songs: songListIds.length,
                  totalDuration: totalDuration,
                  timestamp: timestamp?.toDate() ?? DateTime.now(),
                  isClicked: _clickedIndex == index,
                  onItemTapped: (int index) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      setState(() {
                        _clickedIndex = index;
                      });
                    });
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

// Widget terpisah untuk setiap item
class ProfilePlaylistListItem extends StatefulWidget {
  final int index;
  final String creatorId;
  final String artistName; // Added field
  final String playlistId;
  final String playlistName;
  final int artistFileIndex;
  final String formattedDate;
  final String playlistImageUrl;
  final List likedIds;
  final List playlistIds;
  final int songs;
  final int totalDuration;
  final DateTime timestamp;
  final bool isClicked;
  final Function(int) onItemTapped;

  const ProfilePlaylistListItem({
    super.key,
    required this.index,
    required this.creatorId,
    required this.artistName, // Added this to the constructor
    required this.playlistId,
    required this.playlistName,
    required this.artistFileIndex,
    required this.formattedDate,
    required this.playlistImageUrl,
    required this.likedIds,
    required this.playlistIds,
    required this.songs,
    required this.totalDuration,
    required this.timestamp,
    required this.isClicked,
    required this.onItemTapped,
  });

  @override
  _ProfilePlaylistListItemState createState() =>
      _ProfilePlaylistListItemState();
}

class _ProfilePlaylistListItemState extends State<ProfilePlaylistListItem> {
  bool _isHovering = false;
  bool _isLiked = false;
  Widget? activeWidget2;

  String searchText = ''; // Variabel untuk menyimpan input pencarian
  TextEditingController _searchController =
      TextEditingController(); // Controller untuk TextFormField
  StreamController<String> _searchStreamController =
      StreamController<String>.broadcast(); // Stream untuk search

  @override
  void initState() {
    super.initState();

    // Check if the song is liked when the widget initializes
    _checkIfLiked();
  }

  @override
  void dispose() {
    // Dispose of the search controller and stream controller
    _searchController.dispose();
    _searchStreamController
        .close(); // Tutup StreamController saat widget tidak digunakan

    super.dispose();
  }

  Future<void> _checkIfLiked() async {
    String userId = currentUserPlaylist!.uid;

    DocumentSnapshot playlistDoc = await FirebaseFirestore.instance
        .collection('playlists')
        .doc(widget.playlistId)
        .get();

    DocumentSnapshot userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();

    if (playlistDoc.exists && userDoc.exists) {
      var songData = playlistDoc.data() as Map<String, dynamic>;
      var userData = userDoc.data() as Map<String, dynamic>;

      List<dynamic> likeIds = songData['likeIds'] ?? [];
      List<dynamic> userLikedSongs = userData['userLikedSongs'] ?? [];

      if (!mounted) return;
      setState(() {
        _isLiked = likeIds.contains(userId) &&
            userLikedSongs.contains(widget.playlistId);
      });
    }
  }

  String formatDuration(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  bool isPlaylistModalShown = false; // Flag untuk cek modal kedua
  bool isHoveringPlaylistModal =
      false; // Flag untuk mengecek apakah kursor di atas playlist modal
  bool isHoveringShowPlaylistModal = false;

  @override
  Widget build(BuildContext context) {
    String formattedDuration = formatDuration(widget.totalDuration);
    double screenWidth = MediaQuery.of(context).size.width;
    final widgetStateProvider1 =
        Provider.of<WidgetStateProvider1>(context, listen: false);
    return MouseRegion(
      onEnter: (event) => _onHover(true),
      onExit: (event) => _onHover(false),
      child: GestureDetector(
        onTap: () async {
          // Notify parent about the tap
          widget.onItemTapped(widget.index);

          // Use addPostFrameCallback to delay the widget change until after the build phase
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Provider.of<WidgetStateProvider1>(context, listen: false)
                .changeWidget(
              PlaylistContainer(playlistId: widget.playlistId),
              'Playlist Container',
            );
          });
        },
        child: Container(
          color: widget.isClicked
              ? primaryTextColor.withOpacity(0.1) // Highlight clicked item
              : (_isHovering
                  ? primaryTextColor.withOpacity(0.1) // Hover effect
                  : Colors.transparent), // Default color

          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            children: [
              const SizedBox(width: 5),
              SizedBox(
                width: 35,
                child: IntrinsicWidth(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      widget.index + 1 > 1000
                          ? "𝅗𝅥"
                          : '${widget.index + 1}', // Tampilkan angka jika <= 1000
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: primaryTextColor,
                        fontWeight: mediumWeight,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 30),
              Row(
                children: [
                  SizedBox(
                    height: 50,
                    width: 50,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        height: 50,
                        width: 50,
                        decoration: BoxDecoration(
                          color: widget.playlistImageUrl.isEmpty
                              ? primaryTextColor
                              : tertiaryColor,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: widget.playlistImageUrl.isEmpty
                              ? Icon(
                                  Icons.library_music,
                                  color: primaryColor,
                                )
                              : CachedNetworkImage(
                                  imageUrl: widget.playlistImageUrl,
                                  placeholder: (context, url) =>
                                      const CircularProgressIndicator(
                                    color: primaryTextColor,
                                  ), // Tampilkan indikator loading saat gambar dimuat
                                  errorWidget: (context, url, error) {
                                    print(
                                        "Error loading image: $error"); // Log error ke konsol
                                    return Container(
                                      color: Colors
                                          .grey, // Background abu-abu ketika gambar gagal dimuat
                                      child: const Icon(
                                        Icons.broken_image,
                                        color: Colors
                                            .white, // Tampilkan ikon broken image
                                      ),
                                    );
                                  },
                                  fit: BoxFit
                                      .cover, // Sesuaikan ukuran gambar agar sesuai dengan container
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  SizedBox(
                    width: screenWidth * 0.1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IntrinsicWidth(
                          child: Text(
                            widget.playlistName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: primaryTextColor,
                              fontWeight: mediumWeight,
                              fontSize: smallFontSize,
                            ),
                          ),
                        ),
                        IntrinsicWidth(
                          child: RichText(
                            text: TextSpan(
                              text: widget.artistName,
                              style: const TextStyle(
                                color: primaryTextColor,
                                fontWeight: mediumWeight,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  widgetStateProvider1.changeWidget(
                                    PlaylistContainer(
                                        playlistId: widget.creatorId),
                                    'Profile Container',
                                  );
                                },
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
              screenWidth > 1280 ? const Spacer() : const SizedBox.shrink(),
              screenWidth > 1280 ? const SizedBox(width: 5) : const SizedBox.shrink(),
              screenWidth > 1280
                  ? SizedBox(
                      width: screenWidth * 0.125,
                      child: IntrinsicWidth(
                        child: RichText(
                          text: TextSpan(
                            text: widget.songs.toString(),
                            style: const TextStyle(
                              color: primaryTextColor,
                              fontWeight: mediumWeight,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                widgetStateProvider1.changeWidget(
                                  PlaylistContainer(playlistId: widget.playlistId),
                                  'Album Container',
                                );
                              },
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
              screenWidth > 1380
                  ?
                  // ? const SizedBox(width: 30)
                  const Spacer()
                  : const SizedBox.shrink(),
              screenWidth > 1380 ? const SizedBox(width: 5) : const SizedBox.shrink(),
              screenWidth > 1380
                  ? SizedBox(
                      width: 82,
                      child: IntrinsicWidth(
                        child: Text(
                          widget.formattedDate,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: primaryTextColor,
                              fontWeight: mediumWeight),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
              const Spacer(),
              screenWidth > 1280
                  ? const SizedBox(
                      width: 70,
                    )
                  : const SizedBox.shrink(),
              widget.isClicked
                  ? SizedBox(
                      width: 45,
                      child: IconButton(
                        icon: _isLiked
                            ? const Icon(
                                Icons.favorite,
                                color: secondaryColor,
                                size: smallFontSize,
                              )
                            : const Icon(
                                Icons.favorite_border_outlined,
                                color: primaryTextColor,
                                size: smallFontSize,
                              ),
                        onPressed: () {
                          if (!mounted) return;
                          setState(() {
                            _isLiked =
                                !_isLiked; // Toggle the value of _isLiked
                            _onLikedChanged(_isLiked); // Update Firestore
                          });
                        },
                      ),
                    )
                  : (_isHovering
                      ? SizedBox(
                          width: 45,
                          child: IconButton(
                            icon: _isLiked
                                ? const Icon(
                                    Icons.favorite,
                                    color: secondaryColor,
                                    size: smallFontSize,
                                  )
                                : const Icon(
                                    Icons.favorite_border_outlined,
                                    color: primaryTextColor,
                                    size: smallFontSize,
                                  ),
                            onPressed: () {
                              if (!mounted) return;
                              setState(() {
                                _isLiked =
                                    !_isLiked; // Toggle the value of _isLiked
                                _onLikedChanged(_isLiked); // Update Firestore
                                widget.onItemTapped(widget
                                    .index); // Notify parent about the tap
                              });
                            },
                          ),
                        )
                      : const SizedBox(width: 45)) as Widget,
              const SizedBox(width: 15),
              SizedBox(
                width: 45,
                child: IntrinsicWidth(
                  child: Text(
                    formattedDuration,
                    style: const TextStyle(
                        color: primaryTextColor, fontWeight: mediumWeight),
                  ),
                ),
              ),
              (_isHovering)
                  ? SizedBox(
                      width: 45,
                      child: IconButton(
                        onPressed: () {},
                        icon: const Icon(
                          Icons.more_horiz,
                          color: primaryTextColor,
                          size: mediumFontSize,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
              (widget.isClicked && !_isHovering)
                  ? SizedBox(
                      width: 45,
                      child: IconButton(
                        onPressed: () {},
                        icon: const Icon(
                          Icons.more_horiz,
                          color: primaryTextColor,
                          size: mediumFontSize,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
              (_isHovering || widget.isClicked)
                  ? const SizedBox(
                      width: 10,
                    )
                  : const SizedBox(
                      width: 55,
                    ),

              
            ],
          ),
        ),
      ),
    );
  }

  // Update like status in Firestore based on whether it's liked or not
  void _onLikedChanged(bool isLiked) async {
    String userId = currentUserPlaylist!.uid;

    DocumentReference playlistDocRef =
        FirebaseFirestore.instance.collection('songs').doc(widget.playlistId);

    DocumentReference userDocRef =
        FirebaseFirestore.instance.collection('users').doc(userId);

    try {
      if (isLiked) {
        // Add userId to the song's likeIds array and playlistId to user's liked songs array
        await playlistDocRef.update({
          'likeIds': FieldValue.arrayUnion([userId]),
        });
        await userDocRef.update({
          'userLikedSongs': FieldValue.arrayUnion([widget.playlistId]),
        });
      } else {
        // Remove userId from the song's likeIds array and playlistId from user's liked songs array
        await playlistDocRef.update({
          'likeIds': FieldValue.arrayRemove([userId]),
        });
        await userDocRef.update({
          'userLikedSongs': FieldValue.arrayRemove([widget.playlistId]),
        });
      }
    } catch (e) {
      print('Error updating likes: $e');
    }
  }

  void _onHover(bool isHovering) {
    if (!mounted) return;
    setState(() {
      _isHovering = isHovering;
    });
  }

  Future<void> _submitPlaylistData(BuildContext context) async {
    try {
      final currentUserPlaylist = FirebaseAuth.instance.currentUser;
      if (currentUserPlaylist == null) return;

      // Step 1: Get the number of playlists created by the current user
      QuerySnapshot userPlaylists = await FirebaseFirestore.instance
          .collection('playlists')
          .where('creatorId', isEqualTo: currentUserPlaylist.uid)
          .get();

      // Calculate playlistUserIndex (number of existing playlists + 1)
      int playlistUserIndex = userPlaylists.docs.length + 1;

      // Step 3: Add playlist data to Firestore 'playlists' collection
      DocumentReference playlistRef =
          await FirebaseFirestore.instance.collection('playlists').add({
        'playlistId': '',
        'creatorId': currentUserPlaylist.uid,
        'playlistName': "Playlist # $playlistUserIndex",
        'playlistDescription': "",
        'playlistImageUrl': "",
        'timestamp': FieldValue.serverTimestamp(),
        'playlistUserIndex': playlistUserIndex,
        'songListIdsIds': [],
      });

      // Step 4: Get playlistId from the newly added document
      String playlistId = playlistRef.id;

      // Step 5: Update the playlist document with the generated playlistId
      await playlistRef.update({'playlistId': playlistId});
    } catch (e) {
      print('Error submitting playlist data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit playlist data: $e')),
      );
    }
  }

  void _deleteSong(
      String playlistId, String songUrl, String playlistImageUrl) async {
    try {
      // Hapus lagu dari Firestore
      await FirebaseFirestore.instance
          .collection('songs')
          .doc(playlistId)
          .delete();

      // Hapus gambar lagu dari Firebase Storage jika ada
      if (songUrl.isNotEmpty) {
        final Reference storageRef =
            FirebaseStorage.instance.refFromURL(songUrl);
        await storageRef.delete();
      }

      // Hapus gambar lagu dari Firebase Storage jika ada
      if (playlistImageUrl.isNotEmpty) {
        final Reference storageRef =
            FirebaseStorage.instance.refFromURL(playlistImageUrl);
        await storageRef.delete();
      }

      print("Song deleted successfully!");
    } catch (e) {
      print("Error deleting song: $e");
    }
  }
}
