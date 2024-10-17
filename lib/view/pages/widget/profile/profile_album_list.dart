import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:intl/intl.dart'; // Import intl
import 'package:soundify/view/pages/container/primary/album_container.dart';

import 'package:soundify/provider/song_provider.dart';
import 'package:soundify/provider/widget_state_provider_1.dart';
import 'package:soundify/view/pages/container/primary/profile_container.dart';
import 'package:soundify/view/style/style.dart'; // Pastikan file style sudah ada
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:firebase_storage/firebase_storage.dart';

import 'package:provider/provider.dart'; // Tambahkan provider

class ProfileAlbumList extends StatefulWidget {
  const ProfileAlbumList({
    super.key,
  });

  @override
  State<ProfileAlbumList> createState() => _ProfileAlbumListState();
}

final currentUserAlbum = FirebaseAuth.instance.currentUser;

OverlayEntry? _overlayEntryAlbum;
bool showModalAlbum = false;
GlobalKey _iconKey1Album = GlobalKey();
GlobalKey _iconKey2Album = GlobalKey();

class _ProfileAlbumListState extends State<ProfileAlbumList> {
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

  // Function to get albumName based on albumI

  int _clickedIndex = -1; // -1 means no song is clicked

  @override
  Widget build(BuildContext context) {
    Provider.of<SongProvider>(context);
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('albums')
          .where('creatorId', isEqualTo: currentUserAlbum!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error fetching songs'));
        }
        // Jika tidak ada data
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              // 'No albums available',
              '',
              style: TextStyle(color: primaryTextColor),
            ),
          );
        }

        var albumDocs = snapshot.data!.docs;

        List<DocumentSnapshot> sortedAlbumDocs = List.from(albumDocs);
        sortedAlbumDocs.sort((a, b) {
          Timestamp timestampA = a['timestamp'] as Timestamp;
          Timestamp timestampB = b['timestamp'] as Timestamp;
          return timestampB.compareTo(timestampA); // Sort descending
        });

        return ListView.builder(
          itemCount: sortedAlbumDocs.length,
          itemBuilder: (context, index) {
            var albumData =
                sortedAlbumDocs[index].data() as Map<String, dynamic>;
            String creatorId = albumData['creatorId'] ?? '';
            String albumId = albumData['albumId'] ?? '';
            String albumImageUrl = albumData['albumImageUrl'] ?? '';

            List likes = albumData['likes'] ?? [];
            List songListIds = albumData['songListIds'] ?? [];
            int artistFileIndex = albumData['artistFileIndex'] ?? 0;
            int totalDuration = albumData['totalDuration'] ?? 0;
            String albumName = albumData['albumName'] ?? '';
            Timestamp? timestamp = albumData['timestamp'];

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

                return ProfileAlbumListItem(
                  index: index,
                  creatorId: creatorId,
                  artistName: artistName,
                  albumId: albumId,
                  albumName: albumName,
                  artistFileIndex: artistFileIndex,
                  formattedDate: formattedDate,
                  albumImageUrl: albumImageUrl,
                  likedIds: likes,
                  albumIds: songListIds,
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
class ProfileAlbumListItem extends StatefulWidget {
  final int index;
  final String creatorId;
  final String artistName; // Added field
  final String albumId;
  final String albumName;
  final int artistFileIndex;
  final String formattedDate;
  final String albumImageUrl;
  final List likedIds;
  final List albumIds;
  final int songs;
  final int totalDuration;
  final DateTime timestamp;
  final bool isClicked;
  final Function(int) onItemTapped;

  const ProfileAlbumListItem({
    super.key,
    required this.index,
    required this.creatorId,
    required this.artistName, // Added this to the constructor
    required this.albumId,
    required this.albumName,
    required this.artistFileIndex,
    required this.formattedDate,
    required this.albumImageUrl,
    required this.likedIds,
    required this.albumIds,
    required this.songs,
    required this.totalDuration,
    required this.timestamp,
    required this.isClicked,
    required this.onItemTapped,
  });

  @override
  _ProfileAlbumListItemState createState() => _ProfileAlbumListItemState();
}

class _ProfileAlbumListItemState extends State<ProfileAlbumListItem> {
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
    String userId = currentUserAlbum!.uid;

    DocumentSnapshot albumDoc = await FirebaseFirestore.instance
        .collection('albums')
        .doc(widget.albumId)
        .get();

    DocumentSnapshot userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();

    if (albumDoc.exists && userDoc.exists) {
      var songData = albumDoc.data() as Map<String, dynamic>;
      var userData = userDoc.data() as Map<String, dynamic>;

      List<dynamic> likeIds = songData['likeIds'] ?? [];
      List<dynamic> userLikedSongs = userData['userLikedSongs'] ?? [];

      if (!mounted) return;
      setState(() {
        _isLiked =
            likeIds.contains(userId) && userLikedSongs.contains(widget.albumId);
      });
    }
  }

  String formatDuration(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  bool isAlbumModalShown = false; // Flag untuk cek modal kedua
  bool isHoveringAlbumModal =
      false; // Flag untuk mengecek apakah kursor di atas album modal
  bool isHoveringShowAlbumModal = false;

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
              AlbumContainer(albumId: widget.albumId),
              'Album Container',
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
                          color: widget.albumImageUrl.isEmpty
                              ? primaryTextColor
                              : tertiaryColor,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: widget.albumImageUrl.isEmpty
                              ? Icon(
                                  Icons.album,
                                  color: primaryColor,
                                )
                              : CachedNetworkImage(
                                  imageUrl: widget.albumImageUrl,
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
                            widget.albumName,
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
                                    ProfileContainer(userId: widget.creatorId),
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
                                  AlbumContainer(albumId: widget.albumId),
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
    String userId = currentUserAlbum!.uid;

    DocumentReference albumDocRef =
        FirebaseFirestore.instance.collection('songs').doc(widget.albumId);

    DocumentReference userDocRef =
        FirebaseFirestore.instance.collection('users').doc(userId);

    try {
      if (isLiked) {
        // Add userId to the song's likeIds array and albumId to user's liked songs array
        await albumDocRef.update({
          'likeIds': FieldValue.arrayUnion([userId]),
        });
        await userDocRef.update({
          'userLikedSongs': FieldValue.arrayUnion([widget.albumId]),
        });
      } else {
        // Remove userId from the song's likeIds array and albumId from user's liked songs array
        await albumDocRef.update({
          'likeIds': FieldValue.arrayRemove([userId]),
        });
        await userDocRef.update({
          'userLikedSongs': FieldValue.arrayRemove([widget.albumId]),
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

  Future<void> _submitAlbumData(BuildContext context) async {
    try {
      final currentUserAlbum = FirebaseAuth.instance.currentUser;
      if (currentUserAlbum == null) return;

      // Step 1: Get the number of albums created by the current user
      QuerySnapshot userAlbums = await FirebaseFirestore.instance
          .collection('albums')
          .where('creatorId', isEqualTo: currentUserAlbum.uid)
          .get();

      // Calculate albumUserIndex (number of existing albums + 1)
      int albumUserIndex = userAlbums.docs.length + 1;

      // Step 3: Add album data to Firestore 'albums' collection
      DocumentReference albumRef =
          await FirebaseFirestore.instance.collection('albums').add({
        'albumId': '',
        'creatorId': currentUserAlbum.uid,
        'albumName': "Album # $albumUserIndex",
        'albumDescription': "",
        'albumImageUrl': "",
        'timestamp': FieldValue.serverTimestamp(),
        'albumUserIndex': albumUserIndex,
        'songListIdsIds': [],
      });

      // Step 4: Get albumId from the newly added document
      String albumId = albumRef.id;

      // Step 5: Update the album document with the generated albumId
      await albumRef.update({'albumId': albumId});
    } catch (e) {
      print('Error submitting album data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit album data: $e')),
      );
    }
  }

  void _deleteSong(String albumId, String songUrl, String albumImageUrl) async {
    try {
      // Hapus lagu dari Firestore
      await FirebaseFirestore.instance
          .collection('songs')
          .doc(albumId)
          .delete();

      // Hapus gambar lagu dari Firebase Storage jika ada
      if (songUrl.isNotEmpty) {
        final Reference storageRef =
            FirebaseStorage.instance.refFromURL(songUrl);
        await storageRef.delete();
      }

      // Hapus gambar lagu dari Firebase Storage jika ada
      if (albumImageUrl.isNotEmpty) {
        final Reference storageRef =
            FirebaseStorage.instance.refFromURL(albumImageUrl);
        await storageRef.delete();
      }

      print("Song deleted successfully!");
    } catch (e) {
      print("Error deleting song: $e");
    }
  }
}
