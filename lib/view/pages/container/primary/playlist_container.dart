import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:soundify/utils/sticky_header_delegate.dart';
import 'package:soundify/view/pages/container/primary/home_container.dart';
import 'package:soundify/view/pages/main_page.dart';
import 'package:soundify/provider/playlist_provider.dart';
import 'package:soundify/provider/widget_size_provider.dart';
import 'package:soundify/view/pages/container/secondary/show_detail_song.dart';
import 'package:soundify/view/pages/widget/song_list.dart';
import 'package:soundify/view/style/style.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Import the uuid package

class PlaylistContainer extends StatefulWidget {
  final String playlistId;
  const PlaylistContainer({super.key, required this.playlistId});

  @override
  State<PlaylistContainer> createState() => _PlaylistContainerState();
}

bool showModal = false;
OverlayEntry? _overlayEntry;
var currentUser = FirebaseAuth.instance.currentUser;

class _PlaylistContainerState extends State<PlaylistContainer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPlaylistData();
    });
  }

// Function untuk memuat data playlist (jika perlu)
  void _loadPlaylistData() {
    // Contoh penggunaan Provider atau API call untuk load data
    Provider.of<PlaylistProvider>(context, listen: false)
        .fetchPlaylistById(widget.playlistId);
  }

  void _showModal(BuildContext context) {
    // Access the PlaylistProvider
    final playlistProvider =
        Provider.of<PlaylistProvider>(context, listen: false);

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // GestureDetector untuk mendeteksi klik di luar area modal
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                _closeModal(); // Tutup modal jika area luar modal diklik
              },
              child: Container(
                color: Colors.transparent, // Area di luar modal transparan
              ),
            ),
          ),
          Positioned(
            right: 410, // Posisi modal container
            top: 130, // Posisi modal container
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 148, // Atur lebar container
                height: 96, // Atur tinggi container
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 2.0),
                decoration: BoxDecoration(
                  color: tertiaryColor, // Background container
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
                      color: transparentColor,
                      child: InkWell(
                        hoverColor: primaryTextColor.withOpacity(0.1),
                        onTap: () {
                          setState(() {});
                          _closeModal(); // Tutup modal setelah action
                          _showEditProfileModal(
                              context); // Menampilkan AlertDialog
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: SizedBox(
                            width: 200,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit,
                                  color: primaryTextColor,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  "Edit Playlist",
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
                      color: transparentColor,
                      child: InkWell(
                        hoverColor: primaryTextColor.withOpacity(0.1),
                        onTap: () {
                          _deletePlaylist(
                            playlistProvider.playlistId,
                            playlistProvider.playlistImageUrl,
                          );
                          // Pindah ke MainPage setelah menghapus playlist
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MainPage(
                                activeWidget1: HomeContainer(),
                                activeWidget2: ShowDetailSong(),
                              ),
                            ),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: SizedBox(
                            width: 200,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete,
                                  color: primaryTextColor,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  "Delete Playlist",
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
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!); // Tampilkan overlay
  }

  void _showEditProfileModal(BuildContext context) {
    // Access the PlaylistProvider
    final playlistProvider =
        Provider.of<PlaylistProvider>(context, listen: false);

    // Controllers for TextFormField
    TextEditingController _playlistNameController =
        TextEditingController(text: playlistProvider.playlistName);
    TextEditingController _playlistDescriptionController =
        TextEditingController(text: playlistProvider.playlistDescription);

    // Variable to store the selected image
    Uint8List? _selectedImage;

    _overlayEntry = OverlayEntry(
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    _closeModal();
                  },
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                  ),
                ),
              ),
              Center(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 480,
                    height: 248,
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: tertiaryColor,
                      borderRadius: BorderRadius.circular(20),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Edit Playlist',
                              style: TextStyle(
                                color: primaryTextColor,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                _closeModal();
                              },
                              child: const Icon(
                                Icons.close,
                                color: primaryTextColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Content
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () async {
                                // FilePicker to select image
                                final pickedImageFile =
                                    await FilePicker.platform.pickFiles(
                                  type: FileType.image,
                                );

                                if (pickedImageFile != null) {
                                  setState(() {
                                    // Store the selected image
                                    _selectedImage =
                                        pickedImageFile.files.first.bytes;
                                  });
                                }
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    color: _selectedImage == null &&
                                            playlistProvider
                                                .playlistImageUrl.isEmpty
                                        ? primaryTextColor
                                        : tertiaryColor,
                                    image: _selectedImage != null
                                        ? DecorationImage(
                                            image: MemoryImage(
                                              _selectedImage!,
                                            ), // Use MemoryImage if an image is selected
                                            fit: BoxFit.cover,
                                          )
                                        : playlistProvider
                                                .playlistImageUrl.isNotEmpty
                                            ? DecorationImage(
                                                image: NetworkImage(
                                                  playlistProvider
                                                      .playlistImageUrl,
                                                ), // Use NetworkImage if playlistImageUrl is not empty
                                                fit: BoxFit.cover,
                                              )
                                            : null, // No image if neither are available
                                  ),
                                  child: _selectedImage == null &&
                                          playlistProvider
                                              .playlistImageUrl.isEmpty
                                      ? Icon(
                                          Icons.library_music,
                                          color: primaryColor,
                                          size: 80,
                                        )
                                      : null, // Show the icon only if no image is available
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _playlistNameController,
                                    style: const TextStyle(
                                        color: primaryTextColor),
                                    decoration: const InputDecoration(
                                      contentPadding: EdgeInsets.all(8),
                                      labelText: 'Playlist name',
                                      labelStyle:
                                          TextStyle(color: primaryTextColor),
                                      hintText: 'Enter playlist name',
                                      hintStyle:
                                          TextStyle(color: primaryTextColor),
                                      border: OutlineInputBorder(
                                        borderSide:
                                            BorderSide(color: primaryTextColor),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide:
                                            BorderSide(color: primaryTextColor),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    controller: _playlistDescriptionController,
                                    style: const TextStyle(
                                        color: primaryTextColor),
                                    decoration: const InputDecoration(
                                      contentPadding: EdgeInsets.all(8),
                                      labelText: 'Description',
                                      labelStyle:
                                          TextStyle(color: primaryTextColor),
                                      hintText: 'Enter playlist description',
                                      hintStyle:
                                          TextStyle(color: primaryTextColor),
                                      border: OutlineInputBorder(
                                        borderSide:
                                            BorderSide(color: primaryTextColor),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide:
                                            BorderSide(color: primaryTextColor),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 13),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      GestureDetector(
                                        onTap: () async {
                                          _closeModal(); // Close modal

                                          // Get the current playlist
                                          User? user =
                                              FirebaseAuth.instance.currentUser;
                                          if (user != null) {
                                            // Check if image is selected
                                            String? imageUrl;
                                            if (_selectedImage != null) {
                                              // Use user.uid and playlistId to ensure unique image name
                                              String fileName =
                                                  '${user.uid}_${playlistProvider.playlistId}_playlist_image.png';

                                              Reference ref = FirebaseStorage
                                                  .instance
                                                  .ref()
                                                  .child('playlist_images')
                                                  .child(fileName);

                                              // Upload the image
                                              UploadTask uploadTask =
                                                  ref.putData(_selectedImage!);
                                              TaskSnapshot snapshot =
                                                  await uploadTask;
                                              imageUrl = await snapshot.ref
                                                  .getDownloadURL();
                                            }
                                            DocumentReference playlistRef =
                                                FirebaseFirestore.instance
                                                    .collection('playlists')
                                                    .doc(playlistProvider
                                                        .playlistId);

                                            DocumentSnapshot docSnapshot =
                                                await playlistRef.get();

                                            if (docSnapshot.exists) {
                                              // Update Firestore first, then update PlaylistProvider
                                              await playlistRef.update({
                                                'creatorId':
                                                    user.uid, // Use user.uid
                                                'playlistName':
                                                    _playlistNameController
                                                            .text.isNotEmpty
                                                        ? _playlistNameController
                                                            .text
                                                        : playlistProvider
                                                            .playlistName,
                                                'playlistDescription':
                                                    _playlistDescriptionController
                                                            .text.isNotEmpty
                                                        ? _playlistDescriptionController
                                                            .text
                                                        : '',
                                                'playlistImageUrl': imageUrl ??
                                                    playlistProvider
                                                        .playlistImageUrl,
                                                'timestamp': FieldValue
                                                    .serverTimestamp(),
                                                'playlistUserIndex':
                                                    playlistProvider
                                                        .playlistUserIndex,
                                                'playlistId':
                                                    playlistProvider.playlistId,
                                                'songListIds': playlistProvider
                                                    .songListIds,
                                                'totalDuration':
                                                    playlistProvider
                                                        .totalDuration,
                                              }).then((_) {
                                                print(
                                                    "Playlist updated successfully");
                                                playlistProvider.updatePlaylist(
                                                  imageUrl ??
                                                      playlistProvider
                                                          .playlistImageUrl, // Use the new or existing URL
                                                  _playlistNameController
                                                          .text.isNotEmpty
                                                      ? _playlistNameController
                                                          .text
                                                      : playlistProvider
                                                          .playlistName,
                                                  _playlistDescriptionController
                                                          .text.isNotEmpty
                                                      ? _playlistDescriptionController
                                                          .text
                                                      : playlistProvider
                                                          .playlistDescription,
                                                  user.uid, // Pass the correct user ID
                                                  playlistProvider.playlistId,
                                                  DateTime
                                                      .now(), // Update timestamp
                                                  playlistProvider
                                                      .playlistUserIndex,
                                                  playlistProvider.songListIds,
                                                  playlistProvider
                                                      .totalDuration,
                                                );
                                              }).catchError((error) {
                                                print(
                                                    "Failed to update playlist: $error");
                                              });
                                            } else {
                                              print(
                                                  "Playlist not found: ${playlistProvider.playlistId}");
                                            }
                                          }
                                        },
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          child: Container(
                                            color: primaryColor,
                                            width: 80,
                                            height: 40,
                                            alignment: Alignment.center,
                                            child: const Text(
                                              'Edit',
                                              style: TextStyle(
                                                color: primaryTextColor,
                                                fontSize: smallFontSize,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    Overlay.of(context).insert(_overlayEntry!); // Show overlay
  }

  void _closeModal() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove(); // Hapus overlay
      _overlayEntry = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaylistProvider>(
      builder: (context, playlistProvider, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = MediaQuery.of(context).size.width;
            const minContentWidth = 360.0;
            final providedMaxWidth =
                Provider.of<WidgetSizeProvider>(context).expandedWidth;
            final adjustedMaxWidth =
                providedMaxWidth.clamp(minContentWidth, double.infinity);

            final isMediumScreen = constraints.maxWidth >= 800;
            return ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Scaffold(
                backgroundColor: primaryColor,
                body: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: minContentWidth,
                      maxWidth:
                          screenWidth.clamp(minContentWidth, adjustedMaxWidth),
                    ),
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Column(
                            children: [
                              SizedBox(
                                height: 10,
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
                                child: _buildPlaylistHeader(
                                    playlistProvider, isMediumScreen),
                              ),
                            ],
                          ),
                        ),
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: StickyHeaderDelegate(
                              child: Column(
                            children: [
                              SizedBox(
                                height: 10,
                              ),
                              _buildSongListHeader(isMediumScreen),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                ),
                                child: const Divider(color: primaryTextColor),
                              ),
                            ],
                          )),
                        ),
                        SliverFillRemaining(
                          child: SongList(
                            userId: currentUser!.uid,
                            pageName: "PlaylistContainer",
                            playlistId: playlistProvider.playlistId,
                            albumId: '',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPlaylistHeader(
      PlaylistProvider playlistProvider, bool isMediumScreen) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPlaylistImage(playlistProvider),
        SizedBox(width: isMediumScreen ? 16 : 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(
                  top: playlistProvider.playlistDescription.isNotEmpty
                      ? 0.0
                      : (isMediumScreen ? 28.0 : 38.0),
                ),
                child: Text(
                  playlistProvider.playlistName,
                  style: TextStyle(
                    color: primaryTextColor,
                    fontSize: isMediumScreen ? 50 : 30,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                playlistProvider.playlistDescription,
                style: TextStyle(
                  color: primaryTextColor,
                  fontSize: isMediumScreen ? smallFontSize : 12,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: isMediumScreen ? 2 : 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.more_horiz, color: primaryTextColor),
          onPressed: () {
            setState(() {
              showModal = true;
            });
            _showModal(context);
          },
        ),
      ],
    );
  }

  Widget _buildPlaylistImage(PlaylistProvider playlistProvider) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: playlistProvider.playlistImageUrl.isEmpty
              ? primaryTextColor
              : tertiaryColor,
        ),
        child: playlistProvider.playlistImageUrl.isEmpty
            ? Icon(Icons.library_music, color: primaryColor, size: 60)
            : CachedNetworkImage(
                imageUrl: playlistProvider.playlistImageUrl,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: primaryTextColor),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey,
                  child: const Icon(Icons.broken_image,
                      color: Colors.white, size: 60),
                ),
                fit: BoxFit.cover,
              ),
      ),
    );
  }

  Widget _buildSongListHeader(bool isMediumScreen) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Row(
      children: [
        const SizedBox(width: 30),
        const Text(
          "#",
          style: TextStyle(color: primaryTextColor, fontWeight: mediumWeight),
        ),
        const SizedBox(width: 30),
        const Text(
          'Title',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: primaryTextColor, fontWeight: mediumWeight),
        ),
        const SizedBox(width: 30),
        screenWidth > 1280
            // ? SizedBox(width: 255)
            ? const Spacer()
            : const SizedBox.shrink(),
        screenWidth > 1280 ? const SizedBox(width: 5) : const SizedBox.shrink(),
        screenWidth > 1280
            ? const Text(
                "Album",
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: primaryTextColor, fontWeight: mediumWeight),
              )
            : const SizedBox.shrink(),
        screenWidth > 1380
            // ? const SizedBox(width: 205)
            ? const Spacer()
            : const SizedBox.shrink(),
        screenWidth > 1380
            ? const Text(
                "Date added",
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: primaryTextColor, fontWeight: mediumWeight),
              )
            : const SizedBox.shrink(),
        const Spacer(),
        screenWidth < 1380 && screenWidth > 1280
            ? const SizedBox(
                width: 125,
              )
            : const SizedBox.shrink(),
        const Icon(
          Icons.access_time,
          color: primaryTextColor,
        ),
        const SizedBox(width: 60),
      ],
    );
  }

  void _deletePlaylist(String playlistId, String playlistImageUrl) async {
    try {
      // Hapus lagu dari Firestore
      await FirebaseFirestore.instance
          .collection('playlists')
          .doc(playlistId)
          .delete();

      // Hapus gambar lagu dari Firebase Storage jika ada
      if (playlistImageUrl.isNotEmpty) {
        final Reference storageRef =
            FirebaseStorage.instance.refFromURL(playlistImageUrl);
        await storageRef.delete();
      }

      print("Playlist deleted successfully!");
    } catch (e) {
      print("Error deleting song: $e");
    }
  }
}



