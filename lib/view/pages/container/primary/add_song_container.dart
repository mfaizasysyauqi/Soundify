import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // For platform detection
import 'package:flutter/material.dart';
// import 'package:soundify/pages/page/container/home_container.dart';
import 'package:soundify/provider/album_provider.dart';
import 'package:soundify/provider/image_provider.dart';
import 'package:soundify/provider/song_provider.dart';
// import 'package:soundify/pages/page/provider/widget_state_provider_1.dart';
import 'package:soundify/provider/widget_state_provider_2.dart';
import 'package:soundify/view/pages/container/secondary/create/search_album_id.dart';
import 'package:soundify/view/pages/container/secondary/create/search_artist_Id.dart';
import 'package:soundify/view/pages/container/secondary/show_detail_song.dart';
import 'package:soundify/view/pages/container/secondary/create/show_image.dart';
import 'package:soundify/view/style/style.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';

class AddSongContainer extends StatefulWidget {
  final Function(Widget)
      onChangeWidget; // Tambahkan callback function ke constructor

  const AddSongContainer({super.key, required this.onChangeWidget});

  @override
  _AddSongContainerState createState() => _AddSongContainerState();
}

// Song
String? songPath;
Uint8List? songBytes; // For web
// Image
String? imagePath;
Uint8List? imageBytes; // For web

late AudioPlayer audioPlayer;
bool isPickerActive = false;
bool isSongSelected = false;
bool isImageSelected = false;
bool isPlaying = false;
bool isArtistIdEdited = false;
bool isAlbumIdEdited = false;
bool isFetchingDuration = false; // Menandakan apakah durasi sedang diambil

// Define variables
Duration? songDuration;
int? songDurationS;

// Controller for the song file name
TextEditingController songFileNameController = TextEditingController();
TextEditingController songImageFileNameController = TextEditingController();
TextEditingController songTitleController = TextEditingController();
TextEditingController albumIdController = TextEditingController();
TextEditingController artistIdController = TextEditingController();

String? senderId; // Untuk menyimpan user ID (senderId)

bool _isFormValid() {
  return isSongSelected &&
      isImageSelected &&
      artistIdController.text.isNotEmpty &&
      albumIdController.text.isNotEmpty &&
      songTitleController.text.isNotEmpty &&
      !isFetchingDuration; // Tambahkan pengecekan ini
}

class _AddSongContainerState extends State<AddSongContainer> {
  @override
  void initState() {
    super.initState();
    audioPlayer = AudioPlayer();
    songTitleController = TextEditingController();
    artistIdController = TextEditingController();
    albumIdController = TextEditingController();
    songFileNameController = TextEditingController();
    songImageFileNameController =
        TextEditingController(); // Initialize controller

    // Flags to handle image and song selection
    isSongSelected = false;
    isImageSelected = false;
    isArtistIdEdited = false;

    // Menunggu hingga frame pertama selesai dibangun sebelum melakukan perubahan widget
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<WidgetStateProvider2>(context, listen: false)
          .changeWidget(const ShowDetailSong(), 'ShowDetailSong');
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Ensure the widget is mounted and dependencies have been provided
    if (mounted) {
      // Safely update controllers with new values
      updateArtistIdController();
      updateAlbumIdController();
    }
  }

  void updateArtistIdController() {
    final newArtistId = Provider.of<SongProvider>(context).artistId;

    // Only update if the new value differs from the current one
    if (isArtistIdEdited == false) {
      artistIdController.text = newArtistId;
    } else if (isArtistIdEdited == true) {
      if (isArtistIdEdited == false) {
        artistIdController.text = newArtistId;
      }
    }
  }

  void updateAlbumIdController() {
    final newAlbumId = Provider.of<AlbumProvider>(context).albumId;

    // Only update if the new value differs from the current one
    if (isAlbumIdEdited == false) {
      albumIdController.text = newAlbumId;
    } else if (isAlbumIdEdited == true) {
      if (isAlbumIdEdited == false) {
        albumIdController.text = newAlbumId;
      }
    }
  }

  void onSongPathChanged(String? newSongPath, Uint8List? newSongBytes) async {
    // Stop the current song if it's playing
    if (audioPlayer.playing) {
      await audioPlayer.stop();
    }
    if (mounted) {
      setState(() {
        songPath = newSongPath;
        songBytes = newSongBytes;
        songFileNameController.text =
            newSongPath?.split('/').last ?? ''; // Update the controller's text
        currentPosition = null; // Reset position since a new song is selected
        isSongSelected = true;
      });
    }

    // Automatically play the new song if it's already in play mode
    if (isPlaying) {
      await playSong();
    }

    // Fetch the song's duration after setting the new song
    if (songBytes != null) {
      await audioPlayer.setAudioSource(AudioSource.uri(
        Uri.dataFromBytes(songBytes!, mimeType: 'audio/mpeg'),
      ));
    } else if (songPath != null) {
      await audioPlayer.setFilePath(songPath!);
    }

    // Get the song's duration
    songDuration = audioPlayer.duration;

    // Convert duration to seconds and store it as an integer
    if (songDuration != null) {
      if (mounted) {
        setState(() {
          songDurationS = songDuration!.inSeconds;
        });
      }
    } else {
      // Handle the case where the duration could not be fetched
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to fetch song duration')),
      );
    }
  }

  // Function to update media path and bytes
  void onImagePathChanged(String? newImagePath, Uint8List? newImageBytes) {
    if (mounted) {
      setState(() {
        imagePath = newImagePath;
        imageBytes = newImageBytes; // Set bytes for web
        songImageFileNameController.text =
            newImagePath?.split('/').last ?? ''; // Update the controller's text
      });
    }
  }

  Duration? currentPosition;
// Function to play or resume the selected song
  Future<void> playSong() async {
    if (currentPosition != null) {
      // Resume from the paused position
      await audioPlayer.seek(currentPosition!);
      await audioPlayer.play();
    } else {
      // Start playing from the beginning with a new song
      if (kIsWeb) {
        // For web, play from bytes
        if (songBytes != null) {
          await audioPlayer.setAudioSource(AudioSource.uri(
            Uri.dataFromBytes(songBytes!, mimeType: 'audio/mpeg'),
          ));
        }
      } else {
        // For non-web, play from file path
        if (songPath != null) {
          await audioPlayer.setFilePath(songPath!);
        }
      }

      // Start playback
      await audioPlayer.play();

      // Get the song's duration once loaded
      songDuration = audioPlayer.duration;

      // Convert duration to seconds and store it as an integer
      if (songDuration != null) {
        songDurationS = songDuration!.inSeconds;
      }

      // Output the song duration for debugging or logging
      print('Song duration in seconds: $songDurationS');
    }

    // Listen to the current position of the song while playing
    audioPlayer.positionStream.listen((position) {
      currentPosition = position;
    });
  }

// Function to pause the song and save current position
  Future<void> pauseSong() async {
    await audioPlayer.pause(); // Pause the song
  }

  Timer? _timer;
  @override
  void dispose() {
    if (audioPlayer.playing) {
      audioPlayer.stop();
    }
    // songTitleController.dispose();
    audioPlayer.dispose();
    songTitleController.dispose();
    artistIdController.dispose();
    albumIdController.dispose();
    songFileNameController.dispose();
    _timer?.cancel();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Scaffold(
        backgroundColor: primaryColor,
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                height: 50, // Atur tinggi sesuai kebutuhan
                child: TextFormField(
                  style: const TextStyle(color: primaryTextColor),
                  controller: songFileNameController, // Use the controller here
                  readOnly:
                      true, // Make the text field read-only since the user doesn't manually input the file name
                  onChanged: (value) => setState(() {}),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.all(
                        8), // Optional: tambahkan padding jika perlu
                    prefixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () async {
                            if (isPickerActive) {
                              return; // Prevent multiple clicks
                            }
                            if (mounted) {
                              setState(() {
                                isPickerActive = true;
                              });
                            }

                            try {
                              final pickedSongFile =
                                  await FilePicker.platform.pickFiles(
                                type: FileType.audio,
                              );
                              if (pickedSongFile != null) {
                                // Web platform: access bytes instead of path
                                Uint8List? fileBytes =
                                    pickedSongFile.files.first.bytes;
                                String? filePath =
                                    pickedSongFile.files.first.name;

                                // Update the media path and file name
                                onSongPathChanged(filePath, fileBytes);

                                // Set isSongSelected menjadi true setelah file dipilih
                                setState(() {
                                  isSongSelected = true;
                                });
                              }
                            } catch (e) {
                              print("Error picking file: $e");
                            } finally {
                              if (mounted) {
                                // Reset isPickerActive after file selection
                                setState(() {
                                  isPickerActive = false;
                                });
                              }
                            }
                          },
                          icon: const Icon(
                            Icons.music_note,
                            color: primaryTextColor,
                          ),
                        ),
                        const VerticalDivider(
                          color: primaryTextColor, // Warna divider
                          width: 1, // Lebar divider
                          thickness: 1, // Ketebalan divider
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                    suffixIcon: isSongSelected
                        ? IconButton(
                            onPressed: () {
                              if (mounted) {
                                setState(() {
                                  if (isPlaying) {
                                    pauseSong(); // Fungsi untuk pause musik
                                    isPlaying = false;
                                  } else {
                                    playSong(); // Fungsi untuk play musik
                                    isPlaying = true;
                                  }
                                });
                              }
                            },
                            icon: Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              color: primaryTextColor,
                            ),
                          )
                        : null,
                    hintText: 'Song Name File',
                    hintStyle: const TextStyle(color: primaryTextColor),
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
              const SizedBox(
                height: 8,
              ),
              SizedBox(
                height: 50, // Atur tinggi sesuai kebutuhan
                child: TextFormField(
                  style: const TextStyle(color: primaryTextColor),
                  controller:
                      songImageFileNameController, // Use the controller here
                  readOnly:
                      true, // Make the text field read-only since the user doesn't manually input the file name
                  onChanged: (value) => setState(() {}),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.all(
                        8), // Optional: tambahkan padding jika perlu
                    prefixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () async {
                            if (isPickerActive) {
                              return; // Prevent multiple clicks
                            }
                            if (mounted) {
                              setState(() {
                                isPickerActive = true;
                              });
                            }
                            try {
                              final pickedImageFile =
                                  await FilePicker.platform.pickFiles(
                                type: FileType.image,
                              );
                              if (pickedImageFile != null) {
                                Uint8List? fileBytes =
                                    pickedImageFile.files.first.bytes;
                                String? filePath =
                                    pickedImageFile.files.first.name;

                                onImagePathChanged(filePath, fileBytes);

                                // Update image data di Provider
                                Provider.of<ImageProviderData>(context,
                                        listen: false)
                                    .setImageData(filePath, fileBytes!);

                                setState(() {
                                  isImageSelected = true;
                                });
                              }
                            } catch (e) {
                              print("Error picking file: $e");
                            } finally {
                              if (mounted) {
                                setState(() {
                                  isPickerActive = false;
                                });
                              }
                            }
                          },
                          icon: const Icon(
                            Icons.image,
                            color: primaryTextColor,
                          ),
                        ),
                        const VerticalDivider(
                          color: primaryTextColor, // Warna divider
                          width: 1, // Lebar divider
                          thickness: 1, // Ketebalan divider
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                    suffixIcon: isImageSelected
                        ? IconButton(
                            onPressed: () {
                              setState(() {
                                // Mengganti widget di dalam Provider dengan dua argumen
                                Provider.of<WidgetStateProvider2>(context,
                                        listen: false)
                                    .changeWidget(
                                        const ShowImage(), 'ShowImage');
                              });
                            },
                            icon: const Icon(
                              Icons.visibility,
                              color: primaryTextColor,
                            ),
                          )
                        : null,
                    hintText: 'Image Name File',
                    hintStyle: const TextStyle(color: primaryTextColor),
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
              const SizedBox(
                height: 8,
              ),
              SizedBox(
                height: 50, // Atur tinggi sesuai kebutuhan
                child: TextFormField(
                  style: const TextStyle(color: primaryTextColor),
                  controller: artistIdController, // Use the controller here
                  readOnly:
                      true, // Make the text field read-only since the user doesn't manually input the file name
                  onChanged: (value) => setState(() {}),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.all(
                        8), // Optional: tambahkan padding jika perlu
                    prefixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () {
                            setState(() {
                              isArtistIdEdited =
                                  false; // Mengganti widget di dalam Provider dengan dua argumen
                              Provider.of<WidgetStateProvider2>(context,
                                      listen: false)
                                  .changeWidget(
                                      const SearchArtistId(), 'ShowArtistId');
                            });
                          },
                          icon: const Icon(
                            Icons.person,
                            color: primaryTextColor,
                          ),
                        ),
                        const VerticalDivider(
                          color: primaryTextColor, // Warna divider
                          width: 1, // Lebar divider
                          thickness: 1, // Ketebalan divider
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),

                    hintText: 'Artist ID',
                    hintStyle: const TextStyle(color: primaryTextColor),
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
              const SizedBox(
                height: 8,
              ),
              SizedBox(
                height: 50, // Atur tinggi sesuai kebutuhan
                child: TextFormField(
                  style: const TextStyle(color: primaryTextColor),
                  controller: albumIdController, // Use the controller here
                  readOnly:
                      true, // Make the text field read-only since the user doesn't manually input the file name
                  onChanged: (value) => setState(() {}),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.all(
                        8), // Optional: tambahkan padding jika perlu
                    prefixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () {
                            setState(() {
                              isAlbumIdEdited =
                                  false; // Mengganti widget di dalam Provider dengan dua argumen
                              Provider.of<WidgetStateProvider2>(context,
                                      listen: false)
                                  .changeWidget(
                                      const SearchAlbumId(), 'SearchAlbumId');
                            });
                          },
                          icon: const Icon(
                            Icons.album,
                            color: primaryTextColor,
                          ),
                        ),
                        const VerticalDivider(
                          color: primaryTextColor, // Warna divider
                          width: 1, // Lebar divider
                          thickness: 1, // Ketebalan divider
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),

                    hintText: 'Album ID',
                    hintStyle: const TextStyle(color: primaryTextColor),
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
              const SizedBox(
                height: 8,
              ),
              SizedBox(
                height: 50, // Atur tinggi sesuai kebutuhan
                child: TextFormField(
                  style: const TextStyle(color: primaryTextColor),
                  controller: songTitleController, // Use the controller here
                  readOnly:
                      false, // Make the text field read-only since the user doesn't manually input the file name
                  onChanged: (value) => setState(() {}),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.all(
                        8), // Optional: tambahkan padding jika perlu
                    prefixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(
                            Icons.headset,
                            color: primaryTextColor,
                          ),
                        ),
                        const VerticalDivider(
                          color: primaryTextColor, // Warna divider
                          width: 1, // Lebar divider
                          thickness: 1, // Ketebalan divider
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),

                    hintText: 'Song Title',
                    hintStyle: const TextStyle(color: primaryTextColor),
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
              const Spacer(),
              GestureDetector(
                onTap: () {
                  if (_isFormValid()) {
                    _submitSongData(); // Panggil fungsi submit data

                    // Reset artistId using SongProvider
                    final artistIdProvider =
                        Provider.of<SongProvider>(context, listen: false);
                    artistIdProvider
                        .resetArtistId(); // Reset nilai artistId menjadi string kosong

                    // Reset albumId using AlbumProvider
                    final albumIdProvider =
                        Provider.of<AlbumProvider>(context, listen: false);
                    albumIdProvider
                        .resetAlbumId(); // Reset nilai albumId menjadi string kosong

                    // After data is successfully submitted, change the active widget state
                    // Provider.of<WidgetStateProvider1>(context, listen: false)
                    //     .changeWidget(HomeContainer(), 'HomeContainer');

                    // After data is successfully submitted, change the active widget state
                    Provider.of<WidgetStateProvider2>(context, listen: false)
                        .changeWidget(const ShowDetailSong(), 'ShowDetailSong');
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    color: _isFormValid() ? secondaryColor : tertiaryTextColor,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 8.0,
                      ),
                      child: Text(
                        "Submit",
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  final currentUser = FirebaseAuth.instance.currentUser;

  Future<void> _submitSongData() async {
    String songFileName = songFileNameController.text;
    String imageFileName = songImageFileNameController.text;
    String songTitle = songTitleController.text;
    String artistId = artistIdController.text;
    String albumId = albumIdController.text; // single albumId

    String errorMessage = '';

    // Validations
    if (songFileName.isEmpty) {
      errorMessage += 'Song file name is missing.\n';
    }
    if (imageFileName.isEmpty) {
      errorMessage += 'Image file name is missing.\n';
    }
    if (songTitle.isEmpty) {
      errorMessage += 'Song title is missing.\n';
    }
    if (artistId.isEmpty) {
      errorMessage += 'Artist ID is missing.\n';
    }
    if (albumId.isEmpty) {
      errorMessage += 'Album ID is missing.\n';
    }

    if (errorMessage.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
      return;
    }

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User is not logged in')),
      );
      return;
    }

    if (songDurationS == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Song duration is missing. Please play the song to fetch duration')),
      );
      return;
    }

    if (songBytes == null || imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Please select both song and image before submitting.')),
      );
      return;
    }

    if (isFetchingDuration) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Taking song duration, please wait...')),
      );
      return;
    }

    try {
      // Step 1: Query Firestore to get the current artistFileIndex for the artistId
      QuerySnapshot existingSongsSnapshot = await FirebaseFirestore.instance
          .collection('songs')
          .where('artistId', isEqualTo: artistId)
          .get();

      int artistFileIndex = existingSongsSnapshot.size + 1;

      // Upload song file to Firebase Storage
      String songStoragePath = 'songs/$artistId/$artistFileIndex';
      TaskSnapshot songUploadTask = await FirebaseStorage.instance
          .ref(songStoragePath)
          .putData(songBytes!); // Use the songBytes

      String songDownloadUrl = await songUploadTask.ref.getDownloadURL();

      // Upload image file to Firebase Storage
      String imageStoragePath = 'song_images/$artistId/$artistFileIndex';
      TaskSnapshot imageUploadTask = await FirebaseStorage.instance
          .ref(imageStoragePath)
          .putData(imageBytes!); // Use the imageBytes

      String imageDownloadUrl = await imageUploadTask.ref.getDownloadURL();

      // Step 2: Add song data to Firestore 'songs' collection
      DocumentReference songRef =
          await FirebaseFirestore.instance.collection('songs').add({
        'songId': '', // This will be updated with the Firestore-generated ID
        'senderId': currentUser?.uid, // ID of the user from Firebase Auth
        'artistId': artistId,
        'songTitle': songTitle,
        'songImageUrl':
            imageDownloadUrl, // URL of uploaded image in Firebase Storage
        'songUrl': songDownloadUrl, // URL of uploaded song in Firebase Storage
        'songDuration': songDurationS, // Song duration in seconds
        'timestamp': FieldValue.serverTimestamp(), // Server timestamp
        'albumId': albumId, // Single albumId now
        'artistFileIndex': artistFileIndex, // Incremented artistFileIndex
        'likeIds': [],
        'playlistIds': [],
        'albumIds': [],
        'playedIds': [],
      });

      // Get songId from the newly added document
      String songId = songRef.id;

      // Update the song document with the generated songId
      await songRef.update({'songId': songId});

      // Step 3: Add songId to the 'songListIds' field in the specified album document
      DocumentReference albumDoc =
          FirebaseFirestore.instance.collection('albums').doc(albumId);

      // Define songDoc and albumDoc here
      DocumentReference songDoc =
          FirebaseFirestore.instance.collection('songs').doc(songId);

      // Gunakan transaction untuk memastikan update atomik
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Ambil data dokumen lagu
        DocumentSnapshot songSnapshot = await transaction.get(songDoc);
        if (!songSnapshot.exists || songSnapshot.data() == null) {
          throw Exception('Song does not exist or is null!');
        }

        // Cast data dokumen lagu ke Map<String, dynamic>
        Map<String, dynamic> songData =
            songSnapshot.data() as Map<String, dynamic>;

        // Ambil durasi lagu (pastikan field ada)
        int songDuration = songData['songDuration'] ?? 0;

        // Ambil data dokumen album
        DocumentSnapshot albumSnapshot = await transaction.get(albumDoc);
        if (!albumSnapshot.exists || albumSnapshot.data() == null) {
          throw Exception('Album does not exist or is null!');
        }

        // Cast data dokumen album ke Map<String, dynamic>
        Map<String, dynamic> albumData =
            albumSnapshot.data() as Map<String, dynamic>;

        // Ambil daftar songListIds dari album
        List<dynamic> songListIds = albumData['songListIds'] ?? [];

        // Ambil total durasi saat ini dari album
        int currentTotalDuration = 0;

        // Iterasi setiap songId dalam album dan jumlahkan durasinya
        for (var id in songListIds) {
          DocumentSnapshot songInAlbumSnapshot = await FirebaseFirestore
              .instance
              .collection('songs')
              .doc(id)
              .get();
          if (songInAlbumSnapshot.exists &&
              songInAlbumSnapshot.data() != null) {
            Map<String, dynamic> songInAlbumData =
                songInAlbumSnapshot.data() as Map<String, dynamic>;
            int duration = songInAlbumData['songDuration'] ?? 0;
            currentTotalDuration += duration;
          }
        }

        // Tambahkan durasi lagu yang baru ke total durasi album
        int newTotalDuration = currentTotalDuration + songDuration;

        // Update songListIds dan totalDuration di dokumen album
        transaction.update(albumDoc, {
          'songListIds': FieldValue.arrayUnion([songId]),
          'totalDuration': newTotalDuration,
        });

        // Tambahkan albumId ke albumIds di dokumen lagu
        transaction.update(songDoc, {
          'albumIds': FieldValue.arrayUnion([albumId]),
        });
      });

      // Clear the controllers and reset UI
      songFileNameController.clear();
      songImageFileNameController.clear();
      songTitleController.clear();
      artistIdController.clear();
      albumIdController.clear();
      if (mounted) {
        setState(() {
          imagePath = null;
          songPath = null;
          imageBytes = null;
          songBytes = null;
          isSongSelected = false;
          isImageSelected = false;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Song data successfully submitted and added to album')),
      );

      // Reset artistId using SongProvider
      final artistIdProvider =
          Provider.of<SongProvider>(context, listen: false);
      artistIdProvider
          .resetArtistId(); // This will reset the _artistId to an empty string

      final albumIdProvider =
          Provider.of<AlbumProvider>(context, listen: false);
      albumIdProvider
          .resetAlbumId(); // This will reset the _artistId to an empty string
    } catch (e) {
      print('Error submitting song data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit song data: $e')),
      );
    }
  }
}
