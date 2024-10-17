import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // For platform detection
import 'package:flutter/material.dart';
import 'package:soundify/view/pages/container/primary/home_container.dart';
import 'package:soundify/provider/album_provider.dart';
import 'package:soundify/provider/image_provider.dart';
import 'package:soundify/provider/song_provider.dart';
import 'package:soundify/provider/widget_state_provider_1.dart';
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

class EditSongContainer extends StatefulWidget {
  final Function(Widget)
      onChangeWidget; // Tambahkan callback function ke constructor
  final String songId;
  final String songUrl;
  final String songImageUrl;
  final String artistId;
  final String albumId;
  final int artistFileIndex;
  final String songTitle;
  final int duration;
  const EditSongContainer({
    super.key,
    required this.onChangeWidget,
    required this.songId,
    required this.songUrl,
    required this.songImageUrl,
    required this.artistId,
    required this.albumId,
    required this.artistFileIndex,
    required this.songTitle,
    required this.duration,
  });

  @override
  _EditSongContainerState createState() => _EditSongContainerState();
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
bool isFetchingDuration = false;

// Define variables
Duration? songDuration;
int? songDurationS;

// Controller for the song file name
TextEditingController songFileNameController = TextEditingController();
TextEditingController songImageFileNameController = TextEditingController();
TextEditingController songTitleController = TextEditingController();
TextEditingController artistIdController = TextEditingController();
TextEditingController albumIdController = TextEditingController();

String? senderId; // Untuk menyimpan user ID (senderId)

class _EditSongContainerState extends State<EditSongContainer> {
  @override
  void initState() {
    super.initState();

    // Initialize the audio player
    audioPlayer = AudioPlayer();

    // Controller for the song file name
    songFileNameController = TextEditingController();
    songImageFileNameController = TextEditingController();
    songTitleController = TextEditingController();
    artistIdController = TextEditingController();
    albumIdController = TextEditingController();

    // Set initial values for controllers
    artistIdController.text = widget.artistId;
    albumIdController.text = widget.albumId;
    songTitleController.text = widget.songTitle;

    // Flags to handle image and song selection
    isSongSelected = false;
    isImageSelected = false;
    isArtistIdEdited = false;
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
      artistIdController.text = widget.artistId;
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
      albumIdController.text = widget.albumId;
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

    if (mounted) {
      // Listen to the current position of the song while playing
      audioPlayer.positionStream.listen((position) {
        currentPosition = position;
      });
    }
  }

// Function to pause the song and save current position
  Future<void> pauseSong() async {
    await audioPlayer.pause(); // Pause the song
  }

  Timer? _timer;
  StreamSubscription? positionStreamSubscription;

  @override
  void dispose() {
    if (currentPosition == null) {
      audioPlayer.stop();
      audioPlayer.dispose();
    } else {
      // Stop and dispose the audio player
      audioPlayer.stop();
      audioPlayer.dispose();
    }

    // Cancel any active streams or timers
    positionStreamSubscription?.cancel();
    _timer?.cancel();

    // Dispose the controllers
    songFileNameController.dispose();
    songImageFileNameController.dispose();
    artistIdController.dispose();
    albumIdController.dispose();
    songTitleController.dispose();

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
                  controller: songFileNameController.text.isNotEmpty
                      ? songFileNameController
                      : TextEditingController(
                          text: widget.songUrl,
                        ),

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
                                if (mounted) {
                                  // Set isSongSelected menjadi true setelah file dipilih
                                  setState(() {
                                    isSongSelected = true;
                                  });
                                }
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
                  controller: songImageFileNameController.text.isNotEmpty
                      ? songImageFileNameController
                      : TextEditingController(
                          text: widget.songImageUrl), // Use the controller here
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

                                
                                if (mounted) {
                                  setState(() {
                                    isImageSelected = true;
                                  });
                                }
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
                              // Mengganti widget di dalam Provider dengan dua argumen
                              Provider.of<WidgetStateProvider2>(context,
                                      listen: false)
                                  .changeWidget(const ShowImage(), 'ShowImage');
                            },
                            icon: const Icon(Icons.visibility),
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
                  controller: artistIdController.text.isNotEmpty
                      ? artistIdController
                      : TextEditingController(
                          text: widget.artistId), // Use the controller here
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
                  controller: albumIdController.text.isNotEmpty
                      ? albumIdController
                      : TextEditingController(
                          text: widget.albumId), // Use the controller here
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
                            Icons.library_music,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  InkWell(
                    hoverColor: primaryTextColor.withOpacity(0.1),
                    onTap: () {
                      Provider.of<WidgetStateProvider1>(context, listen: false)
                          .changeWidget(const HomeContainer(), 'Home Container');

                      Provider.of<WidgetStateProvider2>(context, listen: false)
                          .changeWidget(const ShowDetailSong(), 'ShowDetailSong');
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        color: secondaryColor,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: 8.0,
                          ),
                          child: Text(
                            "Cancel",
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  InkWell(
                    hoverColor: primaryTextColor.withOpacity(0.1),
                    onTap: () {
                      // Call the function to edit song data
                      setState(() {
                        _editSongData();
                        isArtistIdEdited = true;
                        isAlbumIdEdited = true;
                      });

                      // After data is successfully submitted, change the active widget state
                      Provider.of<WidgetStateProvider1>(context, listen: false)
                          .changeWidget(const HomeContainer(), 'Home Container');

                      // After data is successfully submitted, change the active widget state
                      Provider.of<WidgetStateProvider2>(context, listen: false)
                          .changeWidget(const ShowDetailSong(), 'Show Detail Song');

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
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        color: secondaryColor,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: 8.0,
                          ),
                          child: Text(
                            "Edit",
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
            ],
          ),
        ),
      ),
    );
  }

  final currentUser = FirebaseAuth.instance.currentUser;
  Future<void> _editSongData() async {
    String songFileName = songFileNameController.text.isNotEmpty
        ? songFileNameController.text
        : widget.songUrl;
    String songTitle = songTitleController.text.isNotEmpty
        ? songTitleController.text
        : widget.songTitle;
    String artistId = artistIdController.text.isNotEmpty
        ? artistIdController.text
        : widget.artistId;
    String albumId = albumIdController.text.isNotEmpty
        ? albumIdController.text
        : widget.albumId;
    int artistFileIndex = widget.artistFileIndex;

    if (songFileName.isNotEmpty && isFetchingDuration) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Taking song duration, please wait...')),
      );
      return;
    }

    try {
      if (mounted) {
        String? songDownloadUrl;
        String? imageDownloadUrl;

        // Upload song file if new data is present
        if (songBytes != null) {
          String songStoragePath = artistId.isNotEmpty
              ? 'songs/$artistId/$artistFileIndex'
              : 'songs/${widget.artistId}/${widget.artistFileIndex}';
          TaskSnapshot songUploadTask = await FirebaseStorage.instance
              .ref(songStoragePath)
              .putData(songBytes!);

          songDownloadUrl = await songUploadTask.ref.getDownloadURL();
          songBytes = null;
        }

        // Upload image file if new data is present
        if (imageBytes != null) {
          String imageStoragePath = artistId.isNotEmpty
              ? 'song_images/$artistId/$artistFileIndex'
              : 'song_images/${widget.artistId}/${widget.artistFileIndex}';
          TaskSnapshot imageUploadTask = await FirebaseStorage.instance
              .ref(imageStoragePath)
              .putData(imageBytes!);

          imageDownloadUrl = await imageUploadTask.ref.getDownloadURL();
          imageBytes = null;
        }

        // Step 1: Update song data in 'songs' collection
        DocumentReference songRef =
            FirebaseFirestore.instance.collection('songs').doc(widget.songId);

        DocumentSnapshot docSnapshot = await songRef.get();
        if (docSnapshot.exists) {
          List<dynamic> albumIds = docSnapshot['albumIds'] ?? [];
          String currentAlbumId = docSnapshot['albumId'] ?? '';

          // Step 2: Check if albumId is changing
          if (albumId.isNotEmpty && currentAlbumId != albumId) {
            // Step 2.1: Update the albumIds list
            if (albumIds.contains(currentAlbumId)) {
              albumIds[albumIds.indexOf(currentAlbumId)] =
                  albumId; // Replace the old albumId with the new one
            } else {
              albumIds.add(
                  albumId); // If for some reason it's not there, add the new albumId
            }

            // Step 2.2: Remove songId from the old album's songListIds
            if (currentAlbumId.isNotEmpty) {
              DocumentReference oldAlbumRef = FirebaseFirestore.instance
                  .collection('albums')
                  .doc(currentAlbumId);

              DocumentSnapshot oldAlbumSnapshot = await oldAlbumRef.get();

              if (oldAlbumSnapshot.exists) {
                List<dynamic> oldSongListIds =
                    oldAlbumSnapshot['songListIds'] ?? [];

                oldSongListIds.remove(widget.songId);

                // Update the old album by removing the songId
                await oldAlbumRef.update({'songListIds': oldSongListIds});
              }
            }

            // Step 3: Add songId to the new album's songListIds
            DocumentReference newAlbumRef =
                FirebaseFirestore.instance.collection('albums').doc(albumId);

            DocumentSnapshot newAlbumSnapshot = await newAlbumRef.get();

            if (newAlbumSnapshot.exists) {
              List<dynamic> newSongListIds =
                  newAlbumSnapshot['songListIds'] ?? [];

              // Add the songId to the new album if it's not already there
              if (!newSongListIds.contains(widget.songId)) {
                newSongListIds.add(widget.songId);
              }

              // Update the new album by adding the songId
              await newAlbumRef.update({'songListIds': newSongListIds});
            }
          }

          // Step 4: Update song data in Firestore
          await songRef.update({
            'songUrl': songDownloadUrl ?? widget.songUrl,
            'songImageUrl': imageDownloadUrl ?? widget.songImageUrl,
            'songTitle': (songTitle.isNotEmpty) ? songTitle : widget.songTitle,
            'artistId': (artistId.isNotEmpty) ? artistId : widget.artistId,
            'albumId': (albumId.isNotEmpty) ? albumId : widget.albumId,
            'albumIds': albumIds, // Update albumIds with the new list
            'artistFileIndex': artistFileIndex,
            'songDuration': songDurationS ?? widget.duration,
          });
        }

        // Clear controllers and reset UI
        songFileNameController.clear();
        songImageFileNameController.clear();
        songTitleController.clear();
        artistIdController.clear();
        albumIdController.clear();

        if (mounted) {
          setState(() {
            imagePath = '';
            songPath = '';
            imageBytes = null;
            songBytes = null;

            isSongSelected = false;
            isImageSelected = false;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Song data successfully edited')),
        );

        final artistIdProvider =
            Provider.of<SongProvider>(context, listen: false);
        artistIdProvider.resetArtistId();

        final albumIdProvider =
            Provider.of<AlbumProvider>(context, listen: false);
        albumIdProvider.resetAlbumId();
      }
    } catch (e) {
      if (mounted) {
        print('Error submitting song data: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit song data: $e')),
        );
      }
    }
  }
}
