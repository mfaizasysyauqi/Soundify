// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Import intl
import 'package:provider/provider.dart'; // Tambahkan provider
import 'package:soundify/view/pages/container/primary/album_container.dart';
import 'package:soundify/view/pages/container/primary/edit_song_container.dart';
import 'package:soundify/view/pages/container/primary/profile_container.dart';
import 'package:soundify/provider/playlist_provider.dart';
import 'package:soundify/provider/song_provider.dart';
import 'package:soundify/provider/widget_state_provider_1.dart';
import 'package:soundify/provider/widget_state_provider_2.dart';
import 'package:soundify/view/pages/container/secondary/show_detail_song.dart';
import 'package:soundify/view/pages/container/secondary/create/show_image.dart';
import 'package:soundify/view/style/style.dart'; // Pastikan file style sudah ada

class SongList extends StatefulWidget {
  final String userId;
  final String pageName;
  final String playlistId;
  final String albumId;

  SongList({
    Key? key,
    required this.userId,
    required this.pageName,
    required this.playlistId,
    required this.albumId,
  }) : super(key: key);

  @override
  State<SongList> createState() => _SongListState();
}

String? lastListenedSongId;
int _clickedIndex = -1; // -1 means no song is clicked

final currentUser = FirebaseAuth.instance.currentUser;
FirebaseFirestore firestore = FirebaseFirestore.instance;

OverlayEntry? _overlayEntry;
bool showModal = false;
GlobalKey _iconKey1 = GlobalKey();
GlobalKey _iconKey2 = GlobalKey();

// Controller for the search text field
TextEditingController searchListController = TextEditingController();

// List to hold song data and filtered search results
List<QueryDocumentSnapshot> songs = [];
List<QueryDocumentSnapshot> filteredSongs = [];

// Declare these maps to store artist and album names globally in the state
Map<String, String> _artistNames = {};
Map<String, String> _albumNames = {};

bool isSearch = false;
// Function to filter songs
List<QueryDocumentSnapshot> _filterSongs(
    [List<QueryDocumentSnapshot>? songList]) {
  String query = searchListController.text.toLowerCase(); // Get search input
  List<QueryDocumentSnapshot> songDocs = songList ?? songs;

  if (query.isEmpty) {
    return songDocs; // If query is empty, return all songs
  }

  return songDocs.where((song) {
    String songTitle = song['songTitle'].toString().toLowerCase();
    String artistId = song['artistId'].toString();
    String albumId = song['albumId'].toString();

    String artistName =
        _artistNames[artistId]?.toLowerCase() ?? 'unknown artist';
    String albumName = _albumNames[albumId]?.toLowerCase() ?? 'unknown album';

    return songTitle.contains(query) ||
        artistName.contains(query) ||
        albumName
            .contains(query); // Filter by songTitle, artistName, or albumName
  }).toList();
}

class Artist {
  final String name;
  final String bioImageUrl;
  final String profileImageUrl;

  Artist(
      {required this.name,
      required this.bioImageUrl,
      required this.profileImageUrl});

  factory Artist.fromMap(Map<String, dynamic> data) {
    return Artist(
      name: data['name'] ?? 'Unknown Artist',
      bioImageUrl: data['bioImageUrl'] ?? '',
      profileImageUrl: data['profileImageUrl'] ?? '',
    );
  }
}

Future<Artist> getArtistDetails(String artistId) async {
  try {
    // Pastikan artistId tidak kosong sebelum mengambil dokumen
    if (artistId.isEmpty) {
      return Artist(
          name: 'Unknown Artist', bioImageUrl: '', profileImageUrl: '');
    }

    // Ambil dokumen dari Firestore
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(artistId)
        .get();

    // Cek apakah dokumen benar-benar ada
    if (userDoc.exists && userDoc.data() != null) {
      var userData = userDoc.data() as Map<String, dynamic>;

      // Mengembalikan objek Artist
      return Artist.fromMap(userData);
    }
  } catch (e) {
    print('Error fetching artist details: $e');
  }

  // Return default artist jika gagal
  return Artist(name: 'Unknown Artist', bioImageUrl: '', profileImageUrl: '');
}

// Function to get albumName based on albumId
Future<String> getAlbumName(String albumId) async {
  try {
    DocumentSnapshot albumDoc = await FirebaseFirestore.instance
        .collection('albums')
        .doc(albumId)
        .get();

    if (albumDoc.exists && albumDoc.data() != null) {
      var albumData = albumDoc.data() as Map<String, dynamic>;
      return albumData['albumName'] ?? 'Unknown Album';
    }
  } catch (e) {
    print('Error fetching album name: $e');
  }
  return 'Unknown Album';
}

class _SongListState extends State<SongList> {
  @override
  void initState() {
    super.initState();
    _loadSongs();
    _fetchLastListenedSongId();

    // Add listener for search field
    searchListController.addListener(() {
      if (mounted) {
        // Add this check
        setState(() {
          _filterSongs();
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final currentWidgetName =
        Provider.of<WidgetStateProvider1>(context, listen: true).widgetName;

    bool wasSearch = isSearch;

    // Gunakan addPostFrameCallback agar setState dipanggil setelah build selesai
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        isSearch = currentWidgetName != "HomeContainer";

        // Jika isSearch berubah dari false ke true, clear text di searchListController
        if (isSearch && !wasSearch) {
          searchListController
              .clear(); // Kosongkan teks di dalam searchListController
        }
      });
    });
  }

  Future<void> _fetchLastListenedSongId() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (userDoc.exists) {
        setState(() {
          lastListenedSongId = userDoc.get('lastListenedSongId') as String?;
        });
      }
    } catch (e) {
      print('Error fetching lastListenedSongId: $e');
    }
  }

  Future<void> _loadSongs() async {
    QuerySnapshot songsSnapshot =
        await FirebaseFirestore.instance.collection('songs').get();

    if (!mounted) return; // Ensure the widget is still mounted

    List<QueryDocumentSnapshot> fetchedSongs = songsSnapshot.docs;

    Map<String, String> artistNames = {};
    Map<String, String> albumNames = {};

    Set<String> artistIds =
        fetchedSongs.map((doc) => doc['artistId'] as String).toSet();
    Set<String> albumIds =
        fetchedSongs.map((doc) => doc['albumId'] as String).toSet();

    // Fetch artist names
    for (String artistId in artistIds) {
      DocumentSnapshot artistDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(artistId)
          .get();
      if (artistDoc.exists) {
        var artistData = artistDoc.data() as Map<String, dynamic>;
        artistNames[artistId] = artistData['name'] ?? 'Unknown Artist';
      }
    }

    // Fetch album names
    for (String albumId in albumIds) {
      DocumentSnapshot albumDoc = await FirebaseFirestore.instance
          .collection('albums')
          .doc(albumId)
          .get();
      if (albumDoc.exists) {
        var albumData = albumDoc.data() as Map<String, dynamic>;
        albumNames[albumId] = albumData['albumName'] ?? 'Unknown Album';
      }
    }

    if (mounted) {
      setState(() {
        songs = fetchedSongs;
        filteredSongs = songs;
        _artistNames = artistNames;
        _albumNames = albumNames;

        // Find the index of lastListenedSongId
        if (lastListenedSongId != null) {
          _clickedIndex =
              songs.indexWhere((song) => song.id == lastListenedSongId);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<SongProvider>(context);

    Stream<QuerySnapshot> songStream;

    if (widget.pageName == "HomeContainer") {
      songStream = FirebaseFirestore.instance.collection('songs').snapshots();
    } else if (widget.pageName == "ProfileContainer") {
      songStream = FirebaseFirestore.instance
          .collection('songs')
          .where('artistId', isEqualTo: widget.userId)
          .snapshots();
    } else if (widget.pageName == "AlbumContainer") {
      songStream = FirebaseFirestore.instance
          .collection('songs')
          .where('albumIds', arrayContains: widget.albumId)
          .snapshots();
    } else if (widget.pageName == "PlaylistContainer") {
      songStream = FirebaseFirestore.instance
          .collection('songs')
          .where('playlistIds', arrayContains: widget.playlistId)
          .snapshots();
    } else if (widget.pageName == "LikedSongContainer") {
      // Default stream, in case no pageName matches
      songStream = FirebaseFirestore.instance
          .collection('songs')
          .where('likeIds', arrayContains: currentUser?.uid)
          .snapshots();
    } else {
      // Default stream, in case no pageName matches
      songStream = FirebaseFirestore.instance.collection('songs').snapshots();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: songStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error fetching songs'));
        }

        // If no data is available
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              '',
              style: TextStyle(color: primaryTextColor),
            ),
          );
        }

        // Get all songs from snapshot
        List<QueryDocumentSnapshot> allSongs = snapshot.data!.docs;

        // Use _filterSongs function to get the filtered list based on the search query
        List<QueryDocumentSnapshot> displayedSongs = _filterSongs(allSongs);

        // Sort the displayedSongs by timestamp in descending order
        displayedSongs.sort((a, b) {
          Timestamp timestampA = a['timestamp'] as Timestamp;
          Timestamp timestampB = b['timestamp'] as Timestamp;
          return timestampB.compareTo(timestampA);
        });

        // Cari indeks dari lastListenedSongId
        int lastListenedIndex = displayedSongs.indexWhere((song) {
          return song['songId'] == lastListenedSongId;
        });
        // print(lastListenedIndex);

        // Set _clickedIndex ke lastListenedIndex jika ditemukan
        if (lastListenedIndex != -1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _clickedIndex = lastListenedIndex;
            });
          });
        }

        // Build the ListView with the filtered and sorted songs
        return ListView.builder(
          itemCount: displayedSongs.length,
          itemBuilder: (context, index) {
            var songData = displayedSongs[index].data() as Map<String, dynamic>;
            String songId = songData['songId'] ?? '';
            String senderId = songData['senderId'] ?? '';
            final songUrl = songData['songUrl'] ?? '';
            final songImageUrl = songData['songImageUrl'] ?? '';

            String songTitle = songData['songTitle'] ?? 'Unknown Title';
            int songDurationS = songData['songDuration'] ?? 0;
            String artistId = songData['artistId'] ?? '';
            String albumId = songData['albumId'] ?? '';
            int artistFileIndex = songData['artistFileIndex'] ?? '';
            Timestamp? timestamp = songData['timestamp'];

            return FutureBuilder<Artist>(
              future: getArtistDetails(artistId),
              builder: (context, artistSnapshot) {
                if (!artistSnapshot.hasData) {
                  return const SizedBox.shrink();
                }

                Artist artist = artistSnapshot.data!;
                String artistName = artist.name;
                String bioImageUrl = artist.bioImageUrl;
                String profileImageUrl = artist.profileImageUrl;

                return FutureBuilder<String>(
                  future: getAlbumName(albumId),
                  builder: (context, albumSnapshot) {
                    if (!albumSnapshot.hasData) {
                      return const SizedBox.shrink();
                    }

                    String albumName = albumSnapshot.data ?? 'Unknown Album';
                    String formattedDate = 'Unknown Date';
                    if (timestamp != null) {
                      DateTime date = timestamp.toDate();
                      formattedDate = DateFormat('MMM d, yyyy').format(date);
                    }

                    return SongListItem(
                      index: index,
                      songId: songId,
                      senderId: senderId,
                      songTitle: songTitle,
                      artistId: artistId,
                      artistName: artistName,
                      albumId: albumId,
                      albumName: albumName,
                      artistFileIndex: artistFileIndex,
                      formattedDate: formattedDate,
                      duration: songDurationS,
                      songUrl: songUrl,
                      profileImageUrl: profileImageUrl,
                      songImageUrl: songImageUrl,
                      bioImageUrl: bioImageUrl,
                      likedIds: const [],
                      playlistIds: const [],
                      timestamp: timestamp?.toDate() ?? DateTime.now(),
                      isClicked: _clickedIndex == index,
                      onItemTapped: (int tappedIndex) {
                        setState(() {
                          _clickedIndex = tappedIndex;
                          lastListenedSongId =
                              displayedSongs[tappedIndex]['songId'];
                        });
                      },
                      isInitialSong: lastListenedSongId == songData['songId'],
                    );
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
class SongListItem extends StatefulWidget {
  final int index;
  final String songId;
  final String senderId;
  final String songTitle;
  final String artistId;
  final String artistName;
  final String albumId;
  final String albumName;
  final int artistFileIndex;
  final String formattedDate;
  final int duration;
  final String songUrl;
  final String profileImageUrl;
  final String songImageUrl;
  final String bioImageUrl;
  final List likedIds;
  final List playlistIds;
  final DateTime timestamp;
  final bool isClicked; // This is received from the parent widget
  final Function(int) onItemTapped; // Callback to notify parent
  final bool isInitialSong;

  const SongListItem({
    super.key,
    required this.index,
    required this.songId,
    required this.senderId,
    required this.songTitle,
    required this.artistId,
    required this.artistName,
    required this.albumId,
    required this.albumName,
    required this.artistFileIndex,
    required this.formattedDate,
    required this.duration,
    required this.songUrl,
    required this.profileImageUrl,
    required this.songImageUrl,
    required this.bioImageUrl,
    required this.likedIds,
    required this.playlistIds,
    required this.timestamp,
    required this.isClicked, // Add this to the constructor
    required this.onItemTapped, // Add this to the constructor
    required this.isInitialSong,
  });

  @override
  _SongListItemState createState() => _SongListItemState();
}

class _SongListItemState extends State<SongListItem> {
  bool _isHovering = false;
  bool _isLiked = false;
  Widget? activeWidget2;
  bool autoPlay = false;

  String searchText = ''; // Variabel untuk menyimpan input pencarian
  TextEditingController _searchController =
      TextEditingController(); // Controller untuk TextFormField
  StreamController<String> _searchStreamController =
      StreamController<String>.broadcast(); // Stream untuk search

  late SongProvider songProvider;

  @override
  void initState() {
    super.initState();
    _checkIfLiked();
    songProvider = Provider.of<SongProvider>(context, listen: false);
    if (widget.isInitialSong) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _playSelectedSong();
      });
    }
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
    String userId = currentUser!.uid;

    DocumentSnapshot songDoc = await FirebaseFirestore.instance
        .collection('songs')
        .doc(widget.songId)
        .get();

    DocumentSnapshot userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();

    if (songDoc.exists && userDoc.exists) {
      var songData = songDoc.data() as Map<String, dynamic>;
      var userData = userDoc.data() as Map<String, dynamic>;

      List<dynamic> likeIds = songData['likeIds'] ?? [];
      List<dynamic> userLikedSongs = userData['userLikedSongs'] ?? [];

      if (!mounted) return;
      setState(() {
        _isLiked =
            likeIds.contains(userId) && userLikedSongs.contains(widget.songId);
      });
    }
  }

  String formatDuration(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _playSelectedSong() async {
    if (songProvider.songId == widget.songId && songProvider.isPlaying) {
      songProvider.pauseOrResume();
    } else {
      songProvider.stop();
      songProvider.setSong(
        widget.songId,
        widget.senderId,
        widget.artistId,
        widget.songTitle,
        widget.profileImageUrl,
        widget.songImageUrl,
        widget.bioImageUrl,
        widget.artistName,
        widget.songUrl,
        widget.duration,
        widget.index,
      );
      if (!mounted) return;
      setState(() {}); // Rebuild the UI after song and bio are updated
    }
  }

  OverlayEntry? _overlayEntryMoreModal; // Overlay untuk more modal
  OverlayEntry? _overlayEntryPlaylistModal; // Overlay untuk playlist modal
  bool isPlaylistModalShown = false; // Flag untuk cek modal kedua
  bool isHoveringPlaylistModal =
      false; // Flag untuk mengecek apakah kursor di atas playlist modal
  bool isHoveringShowPlaylistModal = false;

  void _closeMoreModal() {
    // Tutup _showPlaylistModal jika terbuka saat _showMoreModal ditutup
    if (isPlaylistModalShown) {
      _closePlaylistModal();
      isPlaylistModalShown = false; // Reset flag
    }

    // Tutup _showMoreModal
    if (_overlayEntryMoreModal != null) {
      if (_overlayEntryMoreModal!.mounted) {
        _overlayEntryMoreModal!.remove();
      }
      _overlayEntryMoreModal = null;
    }
  }

  void _closePlaylistModal() {
    // Tutup modal playlist jika ada
    if (_overlayEntryPlaylistModal != null) {
      if (_overlayEntryPlaylistModal!.mounted) {
        _overlayEntryPlaylistModal!.remove();
      }
      _overlayEntryPlaylistModal = null;
      isPlaylistModalShown = false; // Reset flag
    }
  }

  void _showMoreModal(BuildContext context) {
    final RenderBox renderBox =
        _iconKey1.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.of(context).size;
    const double moreModalHeight = 28;
    const double moreModalWidth = 28;

    double modalTop = position.dy + moreModalHeight;
    double modalLeft = position.dx - moreModalWidth;

    if (modalTop + 280 > screenSize.height) {
      modalTop = position.dy - 215;
    }

    if (modalLeft < 0) {
      modalLeft = 0;
    }

    _overlayEntryMoreModal = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                _closeMoreModal();
                _closePlaylistModal(); // Tutup modal kedua juga jika ada
                songProvider.setShouldPlay(true);
              },
              child: Container(
                color: Colors.transparent, // Area di luar modal transparan
              ),
            ),
          ),
          Positioned(
            left: modalLeft + renderBox.size.height,
            top: modalTop + 12,
            child: Material(
              color: Colors.transparent,
              child: MouseRegion(
                onEnter: (_) {
                  if (!isPlaylistModalShown) {
                    _showPlaylistModal(context, position);
                    isPlaylistModalShown = true;
                  }
                },
                onExit: (_) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      Future.delayed(const Duration(milliseconds: 100), () {
                        try {
                          if (_overlayEntryMoreModal != null &&
                              _overlayEntryMoreModal!.mounted) {
                            _overlayEntryMoreModal!.remove();
                          }
                        } catch (e) {
                          print("Error closing More Modal: $e");
                        }
                      });
                    }
                  });
                },
                child: Container(
                  width: _isLiked ? 254 : 218,
                  height: 192,
                  padding: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 2.0),
                  decoration: BoxDecoration(
                    color: tertiaryColor,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          hoverColor: primaryTextColor.withOpacity(0.1),
                          onTap: () {
                            // aksi jika diklik
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: SizedBox(
                              width: double.infinity,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.add,
                                    color: primaryTextColor,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    "Add to Playlist",
                                    style: TextStyle(
                                      color: primaryTextColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          hoverColor: primaryTextColor.withOpacity(0.1),
                          onTap: () {
                            if (!mounted) return;
                            setState(() {
                              _isLiked =
                                  !_isLiked; // Toggle the value of _isLiked
                              _onLikedChanged(_isLiked); // Update Firestore
                              _closeMoreModal();
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(
                                left: 11, right: 8.0, top: 10.0, bottom: 10.0),
                            child: SizedBox(
                              width: double.infinity,
                              child: Row(
                                children: [
                                  Icon(
                                    _isLiked
                                        ? Icons
                                            .favorite // Menggunakan Icons.favorite langsung
                                        : Icons
                                            .favorite_border_outlined, // Menggunakan Icons.favorite_border_outlined langsung
                                    color: _isLiked
                                        ? secondaryColor
                                        : primaryTextColor, // Mengatur warna berdasarkan _isLiked
                                    size: 18,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _isLiked
                                        ? "Remove from your Liked Songs"
                                        : "Save to your Liked Songs",
                                    style: const TextStyle(
                                      color: primaryTextColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Divider(
                          thickness: 1,
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          hoverColor: primaryTextColor.withOpacity(0.1),
                          onTap: () {
                            final widgetStateProvider1 =
                                Provider.of<WidgetStateProvider1>(context,
                                    listen: false);
                            final widgetStateProvider2 =
                                Provider.of<WidgetStateProvider2>(context,
                                    listen: false);

                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                widgetStateProvider1.changeWidget(
                                  EditSongContainer(
                                    onChangeWidget: (newWidget) {
                                      if (mounted) {
                                        setState(() {
                                          activeWidget2 = const ShowImage();
                                        });
                                      }
                                    },
                                    songId: widget.songId,
                                    songUrl: widget.songUrl,
                                    songImageUrl: widget.songImageUrl,
                                    artistId: widget.artistId,
                                    artistFileIndex: widget.artistFileIndex,
                                    albumId: widget.albumId,
                                    songTitle: widget.songTitle,
                                    duration: widget.duration,
                                  ),
                                  'EditSongContainer',
                                );
                              }
                            });

                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                widgetStateProvider2.changeWidget(
                                    const ShowDetailSong(), 'ShowDetailSong');
                              }
                            });

                            _closeMoreModal();
                            _closePlaylistModal();
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: SizedBox(
                              width: double.infinity,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit,
                                    color: primaryTextColor,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    "Edit Song",
                                    style: TextStyle(
                                      color: primaryTextColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          hoverColor: primaryTextColor.withOpacity(0.1),
                          onTap: () {
                            _deleteSong(
                              widget.songId,
                              widget.songUrl,
                              widget.songImageUrl,
                              widget.artistFileIndex,
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: SizedBox(
                              width: double.infinity,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete,
                                    color: primaryTextColor,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    "Delete Song",
                                    style: TextStyle(
                                      color: primaryTextColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntryMoreModal!);
  }

  void _showPlaylistModal(BuildContext context, Offset moreModalPosition) {
    const double moreModalWidth = 288;
    const double moreModalHeight = 40;
    final screenSize = MediaQuery.of(context).size;

    // Create a local TextEditingController for the modal
    TextEditingController _localSearchController = TextEditingController();

    double modalTop = moreModalPosition.dy + moreModalHeight;
    double modalLeft = moreModalPosition.dx - moreModalWidth;

    if (modalTop + 380 > screenSize.height) {
      modalTop = moreModalPosition.dy - 260;
    }

    if (modalLeft < 0) {
      modalLeft = 0;
    }

    _overlayEntryPlaylistModal = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned(
            left: modalLeft,
            top: modalTop,
            child: Material(
              color: Colors.transparent,
              child: MouseRegion(
                onEnter: (_) {
                  isHoveringPlaylistModal = true;
                },
                onExit: (_) {
                  isHoveringPlaylistModal = false;
                  _closePlaylistModal();
                },
                child: Container(
                  width: 300,
                  height: 350,
                  padding: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 2.0),
                  decoration: BoxDecoration(
                    color: tertiaryColor,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: SizedBox(
                          height: 40,
                          child: TextFormField(
                            controller:
                                _localSearchController, // Use the local controller
                            style: const TextStyle(color: primaryTextColor),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.all(8),
                              prefixIcon: IconButton(
                                onPressed: () {},
                                icon: const Icon(
                                  Icons.search,
                                  color: primaryTextColor,
                                ),
                              ),
                              hintText: 'Search Playlist',
                              hintStyle: const TextStyle(
                                color: primaryTextColor,
                                fontSize: tinyFontSize,
                              ),
                              border: const OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: primaryTextColor,
                                ),
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: primaryTextColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Material(
                        color: Colors
                            .transparent, // Buat latar belakang transparan
                        child: InkWell(
                          onTap: () async {
                            // Panggil fungsi untuk menyimpan data playlist
                            await _submitPlaylistData(context);
                            // Fetch the latest playlist
                            var latestPlaylist;
                            try {
                              final playlistSnapshot = await FirebaseFirestore
                                  .instance
                                  .collection('playlists')
                                  .orderBy('playlistUserIndex',
                                      descending: true)
                                  .limit(1)
                                  .get();

                              if (playlistSnapshot.docs.isNotEmpty) {
                                latestPlaylist =
                                    playlistSnapshot.docs.first.data();
                              }
                            } catch (error) {
                              print("Error fetching playlist: $error");
                            }
                            if (latestPlaylist != null) {
                              var timestamp;
                              if (latestPlaylist['timestamp'] != null &&
                                  latestPlaylist['timestamp'] is Timestamp) {
                                timestamp =
                                    (latestPlaylist['timestamp'] as Timestamp)
                                        .toDate();
                              } else {
                                timestamp = DateTime
                                    .now(); // fallback jika timestamp null atau bukan tipe Timestamp
                              }

                              setState(() {
                                Provider.of<PlaylistProvider>(context,
                                        listen: false)
                                    .updatePlaylist(
                                  latestPlaylist['playlistImageUrl'] ?? '',
                                  latestPlaylist['playlistName'] ??
                                      'Untitled Playlist',
                                  latestPlaylist['playlistDescription'] ?? '',
                                  latestPlaylist['creatorId'] ?? '',
                                  latestPlaylist['playlistId'] ?? '',
                                  timestamp, // gunakan timestamp yang telah diperiksa
                                  latestPlaylist['playlistUserIndex'] ?? 0,
                                  latestPlaylist['songListIds'] ?? [],
                                  latestPlaylist['totalDuration'] ?? 0,
                                );
                              });
                            }
                          },
                          hoverColor: primaryTextColor.withOpacity(0.1),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Container(
                              child: const Row(
                                children: [
                                  SizedBox(
                                    width: 16,
                                  ),
                                  Icon(
                                    Icons.add,
                                    color: primaryTextColor,
                                  ),
                                  SizedBox(
                                    width: 8,
                                  ),
                                  Text(
                                    "New Playlist",
                                    style: TextStyle(
                                      color: primaryTextColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: tinyFontSize,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Divider(
                          thickness: 1,
                        ),
                      ),
                      Expanded(
                        child: StreamBuilder<String>(
                          stream: _searchStreamController.stream,
                          initialData: '',
                          builder: (context, searchSnapshot) {
                            return StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('playlists')
                                  .where('creatorId',
                                      isEqualTo: currentUser?.uid)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }
                                if (!snapshot.hasData ||
                                    snapshot.data!.docs.isEmpty) {
                                  return const Center(
                                      child: Text(
                                    'No playlists found',
                                    style: TextStyle(
                                      color: primaryTextColor,
                                    ),
                                  ));
                                }

                                final playlists = snapshot.data!.docs;
                                final searchQuery =
                                    searchSnapshot.data?.toLowerCase() ?? '';

                                // Filter playlist berdasarkan searchText yang di-stream
                                final filteredPlaylists =
                                    playlists.where((playlist) {
                                  final playlistName = playlist['playlistName']
                                      .toString()
                                      .toLowerCase();
                                  return playlistName.contains(searchQuery);
                                }).toList();

                                filteredPlaylists.sort((a, b) {
                                  return b['playlistUserIndex']
                                      .compareTo(a['playlistUserIndex']);
                                });

                                return ListView.builder(
                                  itemCount: filteredPlaylists.length,
                                  itemBuilder: (context, index) {
                                    final playlist = filteredPlaylists[index];
                                    final playlistName =
                                        playlist['playlistName'];

                                    bool isHovered =
                                        false; // Variable to track hover state

                                    return StatefulBuilder(
                                      builder: (context, setState) {
                                        return MouseRegion(
                                          onEnter: (_) =>
                                              setState(() => isHovered = true),
                                          onExit: (_) =>
                                              setState(() => isHovered = false),
                                          child: Container(
                                            color: isHovered
                                                ? primaryTextColor.withOpacity(
                                                    0.1) // Hover effect
                                                : Colors.transparent,
                                            child: ListTile(
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 0.0,
                                                      horizontal: 16.0),
                                              title: Text(
                                                playlistName,
                                                style: const TextStyle(
                                                  color: primaryTextColor,
                                                  fontSize: tinyFontSize,
                                                ),
                                              ),
                                              tileColor: isHovered
                                                  ? primaryTextColor.withOpacity(
                                                      0.1) // Background on hover
                                                  : Colors.transparent,
                                              onTap: () async {
                                                final songId = widget.songId;
                                                final playlistId =
                                                    playlist['playlistId'];

                                                try {
                                                  final playlistDoc =
                                                      FirebaseFirestore.instance
                                                          .collection(
                                                              'playlists')
                                                          .doc(playlistId);

                                                  final songDoc =
                                                      FirebaseFirestore.instance
                                                          .collection('songs')
                                                          .doc(songId);

                                                  // Gunakan transaction untuk memastikan update atomik
                                                  await FirebaseFirestore
                                                      .instance
                                                      .runTransaction(
                                                          (transaction) async {
                                                    // Ambil data dokumen lagu
                                                    DocumentSnapshot
                                                        songSnapshot =
                                                        await transaction
                                                            .get(songDoc);
                                                    if (!songSnapshot.exists ||
                                                        songSnapshot.data() ==
                                                            null) {
                                                      throw Exception(
                                                          'Song does not exist or is null!');
                                                    }

                                                    // Cast data dokumen lagu ke Map<String, dynamic>
                                                    Map<String, dynamic>
                                                        songData =
                                                        songSnapshot.data()
                                                            as Map<String,
                                                                dynamic>;

                                                    // Ambil durasi lagu (pastikan field ada)
                                                    int songDuration = songData[
                                                            'songDuration'] ??
                                                        0;

                                                    // Ambil data dokumen playlist
                                                    DocumentSnapshot
                                                        playlistSnapshot =
                                                        await transaction
                                                            .get(playlistDoc);
                                                    if (!playlistSnapshot
                                                            .exists ||
                                                        playlistSnapshot
                                                                .data() ==
                                                            null) {
                                                      throw Exception(
                                                          'Playlist does not exist or is null!');
                                                    }

                                                    // Cast data dokumen playlist ke Map<String, dynamic>
                                                    Map<String, dynamic>
                                                        playlistData =
                                                        playlistSnapshot.data()
                                                            as Map<String,
                                                                dynamic>;

                                                    // Ambil daftar songListIds dari playlist
                                                    List<dynamic> songListIds =
                                                        playlistData[
                                                                'songListIds'] ??
                                                            [];

                                                    // Ambil total durasi saat ini dari playlist
                                                    int currentTotalDuration =
                                                        0;

                                                    // Iterasi setiap songId dalam playlist dan jumlahkan durasinya
                                                    for (var id
                                                        in songListIds) {
                                                      DocumentSnapshot
                                                          songInPlaylistSnapshot =
                                                          await FirebaseFirestore
                                                              .instance
                                                              .collection(
                                                                  'songs')
                                                              .doc(id)
                                                              .get();
                                                      if (songInPlaylistSnapshot
                                                              .exists &&
                                                          songInPlaylistSnapshot
                                                                  .data() !=
                                                              null) {
                                                        Map<String, dynamic>
                                                            songInPlaylistData =
                                                            songInPlaylistSnapshot
                                                                    .data()
                                                                as Map<String,
                                                                    dynamic>;
                                                        int duration =
                                                            songInPlaylistData[
                                                                    'songDuration'] ??
                                                                0;
                                                        currentTotalDuration +=
                                                            duration;
                                                      }
                                                    }

                                                    // Tambahkan durasi lagu yang baru ke total durasi playlist
                                                    int newTotalDuration =
                                                        currentTotalDuration +
                                                            songDuration;

                                                    // Update songListIds dan totalDuration di dokumen playlist
                                                    transaction
                                                        .update(playlistDoc, {
                                                      'songListIds':
                                                          FieldValue.arrayUnion(
                                                              [songId]),
                                                      'totalDuration':
                                                          newTotalDuration,
                                                    });

                                                    // Tambahkan playlistId ke playlistIds di dokumen lagu
                                                    transaction
                                                        .update(songDoc, {
                                                      'playlistIds':
                                                          FieldValue.arrayUnion(
                                                              [playlistId]),
                                                    });
                                                  });

                                                  print(
                                                      'Song added to playlist: $playlistName and playlist updated in song.');

                                                  _closePlaylistModal();
                                                } catch (error) {
                                                  print(
                                                      'Error adding song to playlist: $error');
                                                }
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntryPlaylistModal!);

    // Clean up the controller when the modal closes
    _overlayEntryPlaylistModal!.addListener(() {
      if (_overlayEntryPlaylistModal != null &&
          !_overlayEntryPlaylistModal!.mounted) {
        _localSearchController.dispose();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    String formattedDuration = formatDuration(widget.duration);
    final widgetStateProvider1 =
        Provider.of<WidgetStateProvider1>(context, listen: false);
    double screenWidth = MediaQuery.of(context).size.width;

    return MouseRegion(
      onEnter: (event) => _onHover(true),
      onExit: (event) => _onHover(false),
      child: GestureDetector(
        onTap: () {
          widget.onItemTapped(widget.index); // Beri tahu parent tentang tap
          _playSelectedSong(); // Mainkan lagu yang dipilih
          songProvider.setShouldPlay(true);
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
                      child: widget.songImageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: widget.songImageUrl,
                              placeholder: (context, url) =>
                                  const CircularProgressIndicator(
                                color: primaryTextColor,
                              ),
                              errorWidget: (context, url, error) {
                                print("Error loading image: $error");
                                return Container(
                                  color: Colors.grey,
                                  child: const Icon(
                                    Icons.broken_image,
                                    color: Colors.white,
                                  ),
                                );
                              },
                              fit: BoxFit.cover,
                            )
                          : const SizedBox.shrink(),
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
                            widget.songTitle,
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
                                color: quaternaryTextColor,
                                fontWeight: mediumWeight,
                                fontSize: microFontSize,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  widgetStateProvider1.changeWidget(
                                    ProfileContainer(userId: widget.artistId),
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
              screenWidth > 1280
                  ? const SizedBox(width: 5)
                  : const SizedBox.shrink(),
              screenWidth > 1280
                  ? SizedBox(
                      width: screenWidth * 0.125,
                      child: IntrinsicWidth(
                        child: RichText(
                          text: TextSpan(
                            text: widget.albumName,
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
              screenWidth > 1380
                  ? const SizedBox(width: 5)
                  : const SizedBox.shrink(),
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
                      key: _iconKey1,
                      child: IconButton(
                        onPressed: () {
                          setState(() {
                            _showMoreModal(context);
                            widget.onItemTapped(
                                widget.index); // Notify parent about the tap
                          });
                        },
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
                      key: _iconKey2,
                      child: IconButton(
                        onPressed: () {
                          setState(() {
                            _showMoreModal(context);
                          });
                        },
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
    String userId = currentUser!.uid;

    DocumentReference songDocRef =
        FirebaseFirestore.instance.collection('songs').doc(widget.songId);

    DocumentReference userDocRef =
        FirebaseFirestore.instance.collection('users').doc(userId);

    try {
      if (isLiked) {
        // Add userId to the song's likeIds array and songId to user's liked songs array
        await songDocRef.update({
          'likeIds': FieldValue.arrayUnion([userId]),
        });
        await userDocRef.update({
          'userLikedSongs': FieldValue.arrayUnion([widget.songId]),
        });
      } else {
        // Remove userId from the song's likeIds array and songId from user's liked songs array
        await songDocRef.update({
          'likeIds': FieldValue.arrayRemove([userId]),
        });
        await userDocRef.update({
          'userLikedSongs': FieldValue.arrayRemove([widget.songId]),
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
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Step 1: Get the number of playlists created by the current user
      QuerySnapshot userPlaylists = await FirebaseFirestore.instance
          .collection('playlists')
          .where('creatorId', isEqualTo: currentUser.uid)
          .get();

      // Calculate playlistUserIndex (number of existing playlists + 1)
      int playlistUserIndex = userPlaylists.docs.length + 1;

      // Step 3: Add playlist data to Firestore 'playlists' collection
      DocumentReference playlistRef =
          await FirebaseFirestore.instance.collection('playlists').add({
        'playlistId': '',
        'creatorId': currentUser.uid,
        'playlistName': "Playlist # $playlistUserIndex",
        'playlistDescription': "",
        'playlistImageUrl': "",
        'timestamp': FieldValue.serverTimestamp(),
        'playlistUserIndex': playlistUserIndex,
        'songListIds': [],
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

  Future<void> _deleteSong(String songId, String songUrl, String songImageUrl,
      int artistFileIndex) async {
    try {
      // Get the song document to retrieve artistId and duration
      DocumentSnapshot songDoc = await FirebaseFirestore.instance
          .collection('songs')
          .doc(songId)
          .get();
      String artistId = songDoc['artistId'];
      int songDuration = songDoc['songDuration'] ?? 0;

      // Delete the song from Firestore
      await FirebaseFirestore.instance.collection('songs').doc(songId).delete();

      // Update albums
      QuerySnapshot albumSnapshot = await FirebaseFirestore.instance
          .collection('albums')
          .where('songListIds', arrayContains: songId)
          .get();
      for (var doc in albumSnapshot.docs) {
        List<dynamic> songListIds = List.from(doc['songListIds']);
        songListIds.remove(songId);
        int newTotalDuration = doc['totalDuration'] - songDuration;
        await doc.reference.update({
          'songListIds': songListIds,
          'totalDuration': newTotalDuration >= 0 ? newTotalDuration : 0
        });
      }

      // Update playlists
      QuerySnapshot playlistSnapshot = await FirebaseFirestore.instance
          .collection('playlists')
          .where('songListIds', arrayContains: songId)
          .get();
      for (var doc in playlistSnapshot.docs) {
        List<dynamic> songListIds = List.from(doc['songListIds']);
        songListIds.remove(songId);
        int newTotalDuration = doc['totalDuration'] - songDuration;
        await doc.reference.update({
          'songListIds': songListIds,
          'totalDuration': newTotalDuration >= 0 ? newTotalDuration : 0
        });
      }

      // Delete song file from Storage
      if (songUrl.isNotEmpty) {
        final Reference storageRef =
            FirebaseStorage.instance.refFromURL(songUrl);
        await storageRef.delete();
      }

      // Delete song image from Storage
      if (songImageUrl.isNotEmpty) {
        final Reference storageRef =
            FirebaseStorage.instance.refFromURL(songImageUrl);
        await storageRef.delete();
      }

      // Renumber remaining songs
      QuerySnapshot remainingSongs = await FirebaseFirestore.instance
          .collection('songs')
          .where('artistId', isEqualTo: artistId)
          .where('artistFileIndex', isGreaterThan: artistFileIndex)
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var doc in remainingSongs.docs) {
        int currentIndex = doc['artistFileIndex'];
        String oldSongPath = 'songs/$artistId/$currentIndex';
        String newSongPath = 'songs/$artistId/${currentIndex - 1}';
        String oldImagePath = 'song_images/$artistId/$currentIndex';
        String newImagePath = 'song_images/$artistId/${currentIndex - 1}';

        // Update Firestore document
        batch.update(doc.reference, {'artistFileIndex': currentIndex - 1});

        // Rename song file in Storage
        await _moveFile(oldSongPath, newSongPath);

        // Rename song image in Storage
        await _moveFile(oldImagePath, newImagePath);

        // Get the new download URLs
        String newSongUrl =
            await FirebaseStorage.instance.ref(newSongPath).getDownloadURL();
        String newImageUrl =
            await FirebaseStorage.instance.ref(newImagePath).getDownloadURL();

        // Update the URLs in Firestore
        batch.update(doc.reference,
            {'songUrl': newSongUrl, 'songImageUrl': newImageUrl});
      }

      // Commit all the batched writes
      await batch.commit();

      print(
          "Song deleted successfully, remaining songs renumbered, and albums/playlists updated!");
    } catch (e) {
      print("Error deleting song and renumbering: $e");
    }
  }

  Future<void> _moveFile(String oldPath, String newPath) async {
    final Reference oldRef = FirebaseStorage.instance.ref(oldPath);
    final Reference newRef = FirebaseStorage.instance.ref(newPath);

    try {
      // Download the file data
      Uint8List? data = await oldRef.getData();
      if (data != null) {
        // Upload the file data to the new location
        await newRef.putData(data);
        // Delete the old file
        await oldRef.delete();
      }
    } catch (e) {
      print("Error moving file from $oldPath to $newPath: $e");
      // If there's an error, we don't update the Firestore document
      rethrow; // Rethrow the error so the calling function knows something went wrong
    }
  }
}
