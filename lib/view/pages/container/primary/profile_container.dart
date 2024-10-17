import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:soundify/provider/widget_size_provider.dart';
import 'package:soundify/utils/sticky_header_delegate.dart';
import 'package:soundify/view/pages/widget/profile/profile_album_list.dart';
import 'package:soundify/view/pages/widget/profile/profile_playlist_list.dart';
import 'package:soundify/view/pages/widget/song_list.dart';
import 'package:soundify/view/style/style.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';

class ProfileContainer extends StatefulWidget {
  final String userId;

  const ProfileContainer({
    super.key,
    required this.userId,
  });

  @override
  State<ProfileContainer> createState() => _ProfileContainerState();
}

bool showModal = false;

class _ProfileContainerState extends State<ProfileContainer> {
  OverlayEntry? _overlayEntry;
// Change the type to Future<void>

  String _profileImageUrl = '';
  String _bioImageUrl = '';
  String _username = '';
  String _fullName = '';
  String _bio = '';
  int _followers = 0;
  int _following = 0;
  String _role = '';

  bool _isSongClicked = true;
  bool _isHaveSong = true;

  bool _isAlbumClicked = false;
  bool _isHaveAlbum = false;

  bool _isPlaylistClicked = false;
  bool _isHavePlaylist = false;
  bool _isLoading = false; // tambahkan variabel loading

  bool _isFollow = false;

  void onSongClicked() {
    setState(() {
      _isSongClicked = true;
      _isAlbumClicked = false;
      _isPlaylistClicked = false;
    });
  }

  void onAlbumClicked() {
    setState(() {
      _isSongClicked = false;
      _isAlbumClicked = true;
      _isPlaylistClicked = false;
    });
  }

  void onPlaylistClicked() {
    setState(() {
      _isSongClicked = false;
      _isAlbumClicked = false;
      _isPlaylistClicked = true;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    loadUserData();
    _checkIfFollow();
  }

  Future<void> _checkIfFollow() async {
    String userId = currentUser!.uid;

    // Reference to the user being followed
    DocumentSnapshot userToFollowSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();

    // Reference to the current user who is following or unfollowing
    DocumentSnapshot currentUserSnapshot =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();

    if (userToFollowSnapshot.exists && currentUserSnapshot.exists) {
      var followersData = userToFollowSnapshot.data() as Map<String, dynamic>;
      var followingData = currentUserSnapshot.data() as Map<String, dynamic>;

      List<dynamic> followers = followersData['followers'] ?? [];
      List<dynamic> following = followingData['following'] ?? [];

      if (!mounted) return;
      setState(() {
        _isFollow =
            followers.contains(userId) && following.contains(widget.userId);
      });
    }
  }

  Future<void> loadUserData() async {
    var currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await Future.wait([
      checkIfUserHasSong(),
      checkIfUserHasAlbum(),
      checkIfUserHasPlaylist(),
    ]);

    if (mounted) {
      setState(() {
        _isLoading = false; // set loading selesai
      });
    }
  }

  Future<void> checkIfUserHasSong() async {
    var currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) return;

    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('songs')
          .where('artistId', isEqualTo: widget.userId)
          .get();

      if (!mounted) return; // Pastikan widget masih aktif sebelum setState

      setState(() {
        _isHaveSong = querySnapshot.docs.isNotEmpty;
      });
    } catch (e) {
      print('Error querying songs: $e');
    }
  }

  Future<void> checkIfUserHasAlbum() async {
    var currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) return;

    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('albums')
          .where('creatorId', isEqualTo: widget.userId)
          .get();

      if (!mounted) return; // Pastikan widget masih aktif sebelum setState

      setState(() {
        _isHaveAlbum = querySnapshot.docs.isNotEmpty;
      });
    } catch (e) {
      print('Error querying albums: $e');
    }
  }

  Future<void> checkIfUserHasPlaylist() async {
    var currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) return;

    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('playlists')
          .where('creatorId', isEqualTo: widget.userId)
          .get();

      if (!mounted) return; // Pastikan widget masih aktif sebelum setState

      setState(() {
        _isHavePlaylist = querySnapshot.docs.isNotEmpty;
      });
    } catch (e) {
      print('Error querying playlists: $e');
    }
  }

  void _updateUserData(DocumentSnapshot userDoc) {
    setState(() {
      // Cache the data into state variables safely outside the build phase
      _profileImageUrl = userDoc['profileImageUrl'] ?? '';
      _bioImageUrl = userDoc['bioImageUrl'] ?? '';
      _username = userDoc['username'] ?? 'No Username';
      _fullName = userDoc['name'] ?? 'No Full Name';
      _bio = userDoc['bio'] ?? 'No Bio';
      _followers = (userDoc['followers'] as List).length;
      _following = (userDoc['following'] as List).length;
      _role = userDoc['role'] ?? 'No Role';
    });
  }

  void _showModal(BuildContext context) {
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
            right: 400, // Posisi modal container
            top: 110, // Posisi modal container
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 133, // Atur lebar container
                height: 80, // Atur tinggi container
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
                    SizedBox(
                      width: 200,
                      child: TextButton(
                        onPressed: () {
                          setState(() {});
                          _closeModal(); // Tutup modal setelah action
                          _showEditProfileModal(
                              context); // Menampilkan AlertDialog
                        },
                        child: const Row(
                          children: [
                            Icon(
                              Icons.edit,
                              color: primaryTextColor,
                            ),
                            SizedBox(width: 12),
                            Text(
                              "Edit Profile",
                              style: TextStyle(
                                color: primaryTextColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: TextButton(
                        onPressed: () {
                          setState(() {});

                          _closeModal(); // Tutup modal setelah action
                          _showEditBioModal(context); // Menampilkan AlertDialog
                        },
                        child: const Row(
                          children: [
                            Icon(
                              Icons.edit_note,
                              color: primaryTextColor,
                            ),
                            SizedBox(width: 12),
                            Text(
                              "Edit Bio",
                              style: TextStyle(
                                color: primaryTextColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
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
    // Controllers untuk TextFormField
    TextEditingController _usernameController =
        TextEditingController(text: _username);
    TextEditingController _fullNameController =
        TextEditingController(text: _fullName);

    // Variabel untuk menyimpan gambar yang dipilih
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
                              'Edit Profile',
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
                                // FilePicker untuk memilih gambar
                                final pickedImageFile =
                                    await FilePicker.platform.pickFiles(
                                  type: FileType.image,
                                );

                                if (pickedImageFile != null) {
                                  setState(() {
                                    // Simpan gambar yang dipilih
                                    _selectedImage =
                                        pickedImageFile.files.first.bytes;
                                  });
                                }
                              },
                              child: CircleAvatar(
                                radius: 80,
                                backgroundColor: _selectedImage == null &&
                                        (_profileImageUrl.isEmpty)
                                    ? primaryTextColor
                                    : tertiaryColor,
                                backgroundImage: _selectedImage != null
                                    ? MemoryImage(_selectedImage!)
                                    : _profileImageUrl.isNotEmpty
                                        ? NetworkImage(_profileImageUrl)
                                        : null, // Assign NetworkImage if _profileImageUrl is valid
                                child: _selectedImage == null &&
                                        (_profileImageUrl.isEmpty)
                                    ? Icon(
                                        Icons.person,
                                        color: primaryColor,
                                        size: 80,
                                      )
                                    : null, // Show icon if no image is selected and no profileImageUrl exists
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _usernameController,
                                    style: const TextStyle(
                                        color: primaryTextColor),
                                    decoration: const InputDecoration(
                                      contentPadding: EdgeInsets.all(8),
                                      labelText: 'Username',
                                      labelStyle:
                                          TextStyle(color: primaryTextColor),
                                      hintText: 'Enter username',
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
                                    controller: _fullNameController,
                                    style: const TextStyle(
                                        color: primaryTextColor),
                                    decoration: const InputDecoration(
                                      contentPadding: EdgeInsets.all(8),
                                      labelText: 'Full name',
                                      labelStyle:
                                          TextStyle(color: primaryTextColor),
                                      hintText: 'Enter full name',
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
                                          _closeModal(); // Menutup modal

                                          // Mendapatkan pengguna saat ini
                                          User? user =
                                              FirebaseAuth.instance.currentUser;

                                          if (user != null) {
                                            // Mendapatkan dokumen user dari Firestore
                                            DocumentSnapshot userDoc =
                                                await FirebaseFirestore.instance
                                                    .collection('users')
                                                    .doc(user.uid)
                                                    .get();

                                            String? profileImageUrl =
                                                userDoc['profileImageUrl'];

                                            if (profileImageUrl != null) {
                                              // Hapus gambar dari Firebase Storage
                                              Reference ref = FirebaseStorage
                                                  .instance
                                                  .refFromURL(profileImageUrl);

                                              try {
                                                // Menghapus file dari Firebase Storage
                                                await ref.delete();
                                                print(
                                                    'Image deleted from Storage');
                                              } catch (e) {
                                                print(
                                                    'Error deleting image from Storage: $e');
                                              }

                                              // Hapus profileImageUrl dari Firestore
                                              await FirebaseFirestore.instance
                                                  .collection('users')
                                                  .doc(user.uid)
                                                  .update({
                                                'profileImageUrl': ""
                                              }).then((_) {
                                                print(
                                                    'profileImageUrl deleted from Firestore');
                                              }).catchError((error) {
                                                print(
                                                    'Failed to delete profileImageUrl from Firestore: $error');
                                              });
                                            } else {
                                              print(
                                                  'No profileImageUrl found to delete');
                                            }
                                          }
                                        },
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          child: Container(
                                            color: primaryColor,
                                            width: 170,
                                            height: 40,
                                            alignment: Alignment.center,
                                            child: const Text(
                                              'Delete profile image',
                                              style: TextStyle(
                                                color: tertiaryTextColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(
                                        width: 8,
                                      ),
                                      GestureDetector(
                                        onTap: () async {
                                          _closeModal(); // Close modal

                                          // Get the current user
                                          User? user =
                                              FirebaseAuth.instance.currentUser;

                                          if (user != null) {
                                            // Check if image is selected
                                            String? imageUrl;
                                            if (_selectedImage != null) {
                                              // Upload image to Firebase Storage
                                              String fileName =
                                                  '${user.uid}_profile_image.png';
                                              Reference ref = FirebaseStorage
                                                  .instance
                                                  .ref()
                                                  .child('profile_images')
                                                  .child(fileName);

                                              UploadTask uploadTask =
                                                  ref.putData(_selectedImage!);

                                              TaskSnapshot snapshot =
                                                  await uploadTask;
                                              imageUrl = await snapshot.ref
                                                  .getDownloadURL();
                                            }

                                            // Update Firestore
                                            await FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(user.uid)
                                                .update({
                                              'username':
                                                  _usernameController.text,
                                              'name': _fullNameController.text,
                                              if (imageUrl != null)
                                                'profileImageUrl': imageUrl,
                                            }).then((_) {
                                              print(
                                                  "Profile updated successfully");
                                            }).catchError((error) {
                                              print(
                                                  "Failed to update profile: $error");
                                            });
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

  void _showEditBioModal(BuildContext context) {
    // Controllers untuk TextFormField
    TextEditingController _bioController = TextEditingController(text: _bio);
    // Variabel untuk menyimpan gambar yang dipilih
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
                    height: 273,
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
                              'Edit Bio',
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
                                // FilePicker untuk memilih gambar
                                final pickedImageFile =
                                    await FilePicker.platform.pickFiles(
                                  type: FileType.image,
                                );

                                if (pickedImageFile != null) {
                                  setState(() {
                                    // Simpan gambar yang dipilih
                                    _selectedImage =
                                        pickedImageFile.files.first.bytes;
                                  });
                                }
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  width: 190,
                                  height: 190,
                                  decoration: BoxDecoration(
                                    color: _selectedImage == null &&
                                            (_bioImageUrl.isEmpty)
                                        ? primaryTextColor
                                        : tertiaryColor,
                                    image: _selectedImage != null
                                        ? DecorationImage(
                                            image: MemoryImage(_selectedImage!),
                                            fit: BoxFit.cover,
                                          )
                                        : _bioImageUrl.isNotEmpty
                                            ? DecorationImage(
                                                image:
                                                    NetworkImage(_bioImageUrl),
                                                fit: BoxFit.cover,
                                              )
                                            : null, // Assign NetworkImage if _bioImageUrl is valid
                                  ),
                                  child: _selectedImage == null &&
                                          (_bioImageUrl.isEmpty)
                                      ? Icon(
                                          Icons.portrait,
                                          color: primaryColor,
                                          size: 90,
                                        )
                                      : null, // Show icon if no image is selected and no profileImageUrl exists
                                ),
                              ),
                            ),
                            const SizedBox(
                              width: 8,
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    minLines: 5,
                                    maxLines: 5,
                                    controller: _bioController,
                                    style: const TextStyle(
                                        color: primaryTextColor),
                                    decoration: const InputDecoration(
                                      contentPadding: EdgeInsets.all(8),
                                      labelText: 'Bio',
                                      labelStyle:
                                          TextStyle(color: primaryTextColor),
                                      floatingLabelBehavior:
                                          FloatingLabelBehavior.always,
                                      hintText: 'Enter bio',
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
                                          _closeModal(); // Menutup modal

                                          // Mendapatkan pengguna saat ini
                                          User? user =
                                              FirebaseAuth.instance.currentUser;

                                          if (user != null) {
                                            // Mendapatkan dokumen user dari Firestore
                                            DocumentSnapshot userDoc =
                                                await FirebaseFirestore.instance
                                                    .collection('users')
                                                    .doc(user.uid)
                                                    .get();

                                            String? bioImageUrl =
                                                userDoc['bioImageUrl'];

                                            if (bioImageUrl != null) {
                                              // Hapus gambar dari Firebase Storage
                                              Reference ref = FirebaseStorage
                                                  .instance
                                                  .refFromURL(bioImageUrl);

                                              try {
                                                // Menghapus file dari Firebase Storage
                                                await ref.delete();
                                                print(
                                                    'Image deleted from Storage');
                                              } catch (e) {
                                                print(
                                                    'Error deleting image from Storage: $e');
                                              }

                                              // Hapus bioImageUrl dari Firestore
                                              await FirebaseFirestore.instance
                                                  .collection('users')
                                                  .doc(user.uid)
                                                  .update({
                                                'bioImageUrl': "",
                                                // Menghapus field bioImageUrl
                                              }).then((_) {
                                                print(
                                                    'bioImageUrl deleted from Firestore');
                                              }).catchError((error) {
                                                print(
                                                    'Failed to delete bioImageUrl from Firestore: $error');
                                              });
                                            } else {
                                              print(
                                                  'No bioImageUrl found to delete');
                                            }
                                          }
                                        },
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          child: Container(
                                            color: primaryColor,
                                            width: 160,
                                            height: 40,
                                            alignment: Alignment.center,
                                            child: const Text(
                                              'Delete bio image',
                                              style: TextStyle(
                                                color: tertiaryTextColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(
                                        width: 8,
                                      ),
                                      GestureDetector(
                                        onTap: () async {
                                          _closeModal(); // Close modal

                                          // Get the current user
                                          User? user =
                                              FirebaseAuth.instance.currentUser;

                                          if (user != null) {
                                            // Check if image is selected
                                            String? imageUrl;
                                            if (_selectedImage != null) {
                                              // Upload image to Firebase Storage
                                              String fileName =
                                                  '${user.uid}_bio_image.png';
                                              Reference ref = FirebaseStorage
                                                  .instance
                                                  .ref()
                                                  .child('bio_images')
                                                  .child(fileName);

                                              UploadTask uploadTask =
                                                  ref.putData(_selectedImage!);

                                              TaskSnapshot snapshot =
                                                  await uploadTask;
                                              imageUrl = await snapshot.ref
                                                  .getDownloadURL();
                                            }

                                            // Update Firestore
                                            await FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(user.uid)
                                                .update({
                                              'bio': _bioController.text,
                                              if (imageUrl != null)
                                                'bioImageUrl': imageUrl,
                                            }).then((_) {
                                              print("Bio updated successfully");
                                            }).catchError((error) {
                                              print(
                                                  "Failed to update bio: $error");
                                            });
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return _buildResponsiveLayout(context, constraints);
      },
    );
  }

  Widget _buildResponsiveLayout(
      BuildContext context, BoxConstraints constraints) {
    final screenWidth = MediaQuery.of(context).size.width;
    const minContentWidth = 360.0;
    final providedMaxWidth =
        Provider.of<WidgetSizeProvider>(context).expandedWidth;
    final adjustedMaxWidth =
        providedMaxWidth.clamp(minContentWidth, double.infinity);

    final isSmallScreen = constraints.maxWidth < 800;
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
              maxWidth: screenWidth.clamp(minContentWidth, adjustedMaxWidth),
            ),
            child: StreamBuilder<QuerySnapshot>(
              stream: _getUserStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error fetching user'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      '',
                      style: TextStyle(color: primaryTextColor),
                    ),
                  );
                }

                DocumentSnapshot userDoc = snapshot.data!.docs.first;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _updateUserData(userDoc);
                });

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child:
                          _buildProfileSection(isSmallScreen, isMediumScreen),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: StickyHeaderDelegate(
                        child: Column(
                          children: [
                            const SizedBox(
                              height: 10,
                            ),
                            _buildHeaderSection(isMediumScreen),
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.0,
                              ),
                              child: Divider(color: primaryTextColor),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverFillRemaining(
                      child: _buildList(),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(bool isSmallScreen, bool isMediumScreen) {
    if (isSmallScreen) {
      return _buildSmallScreenProfile();
    } else {
      return _buildMediumScreenProfile();
    }
  }

  Widget _buildHeaderSection(bool isMediumScreen) {
    return Column(
      children: [
        if (_isHaveSong && _isSongClicked) _buildSongHeader(isMediumScreen),
        if (_isHaveAlbum && _isAlbumClicked) _buildAlbumHeader(isMediumScreen),
        if (_isHavePlaylist && _isPlaylistClicked)
          _buildPlaylistHeader(isMediumScreen),
      ],
    );
  }

  Widget _buildSmallScreenProfile() {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor:
                (_profileImageUrl.isEmpty) ? primaryTextColor : tertiaryColor,
            backgroundImage: _profileImageUrl.isNotEmpty
                ? NetworkImage(_profileImageUrl)
                : null,
            child: (_profileImageUrl.isEmpty)
                ? Icon(Icons.person, color: primaryColor, size: 50)
                : null,
          ),
          const SizedBox(height: 10),
          Text('@$_username',
              style: const TextStyle(
                  color: primaryTextColor, fontSize: smallFontSize)),
          Text(_fullName,
              style: const TextStyle(
                  color: primaryTextColor,
                  fontSize: mediumFontSize,
                  fontWeight: FontWeight.bold)),
          Text('Followers: $_followers | Following: $_following | Role: $_role',
              style: const TextStyle(
                  color: primaryTextColor, fontSize: smallFontSize)),
          if (_bio.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _bio,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: primaryTextColor,
                  fontSize: smallFontSize,
                ),
              ),
            ),
          _buildActionButtons(useRow: true),
        ],
      ),
    );
  }

  Widget _buildMediumScreenProfile() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Stack(
            children: [
              CircleAvatar(
                radius: 75,
                backgroundColor: (_profileImageUrl.isEmpty)
                    ? primaryTextColor
                    : tertiaryColor,
                backgroundImage: _profileImageUrl.isNotEmpty
                    ? NetworkImage(_profileImageUrl)
                    : null,
                child: (_profileImageUrl.isEmpty)
                    ? Icon(Icons.person, color: primaryColor, size: 75)
                    : null,
              ),
              Positioned(
                bottom: 7,
                right: 7,
                child: GestureDetector(
                  onTap: () {
                    if (!mounted) return;
                    setState(() {
                      _isFollow = !_isFollow; // Toggle the value of _isLiked
                      _onFollowChanged(_isFollow); // Update Firestore
                    });
                  },
                  child: CircleAvatar(
                    radius: 15,
                    backgroundColor:
                        _isFollow ? quinaryColor : tertiaryTextColor,
                    child: Icon(
                      _isFollow ? Icons.star : Icons.star_border,
                      color: primaryTextColor,
                      size: 20,
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bio.isNotEmpty
                  ? const SizedBox(
                      height: 7,
                    )
                  : const SizedBox(
                      height: 14,
                    ),
              Text('@$_username',
                  style: const TextStyle(
                      color: primaryTextColor, fontSize: smallFontSize)),
              Text(
                _fullName,
                style: TextStyle(
                  color: primaryTextColor,
                  fontSize:
                      _bio.isNotEmpty ? extraHugeFontSize : superHugeFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                  'Followers: $_followers | Following: $_following | Role: $_role',
                  style: const TextStyle(
                      color: primaryTextColor, fontSize: smallFontSize)),
              if (_bio.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    _bio,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: primaryTextColor,
                      fontSize: smallFontSize,
                    ),
                  ),
                ),
            ],
          ),
        ),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildActionButtons({bool useRow = false}) {
    final List<Widget> buttons = [
      IconButton(
        icon: const Icon(Icons.more_horiz, color: primaryTextColor),
        onPressed: () => _showModal(context),
      ),
      if (_isHaveSong)
        IconButton(
          icon: const Icon(Icons.music_note, color: primaryTextColor),
          onPressed: onSongClicked,
        ),
      if (_isHaveAlbum)
        IconButton(
          icon: const Icon(Icons.album, color: primaryTextColor),
          onPressed: onAlbumClicked,
        ),
      if (_isHavePlaylist)
        IconButton(
          icon: const Icon(Icons.library_music, color: primaryTextColor),
          onPressed: onPlaylistClicked,
        ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 10.0,
      ),
      child: useRow
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: buttons,
            )
          : Column(
              children: buttons,
            ),
    );
  }

  Widget _buildSongHeader(bool isLargeScreen) {
    double screenWidth = MediaQuery.of(context).size.width;
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

  Widget _buildAlbumHeader(bool isLargeScreen) {
    double screenWidth = MediaQuery.of(context).size.width;
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
                "Songs",
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

  Widget _buildPlaylistHeader(bool isLargeScreen) {
    double screenWidth = MediaQuery.of(context).size.width;
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
                "Songs",
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

  Widget _buildList() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: primaryTextColor));
    } else if (_isSongClicked) {
      return SongList(
          userId: widget.userId,
          pageName: "ProfileContainer",
          playlistId: "",
          albumId: "");
    } else if (_isPlaylistClicked) {
      return const ProfilePlaylistList();
    } else if (_isAlbumClicked) {
      return const ProfileAlbumList();
    } else {
      return const SizedBox.shrink();
    }
  }

  Stream<QuerySnapshot> _getUserStream() {
    var currentUser = FirebaseAuth.instance.currentUser;
    if (widget.userId == currentUser?.uid) {
      return FirebaseFirestore.instance
          .collection('users')
          .where('userId', isEqualTo: currentUser!.uid)
          .snapshots();
    } else {
      return FirebaseFirestore.instance
          .collection('users')
          .where('userId', isEqualTo: widget.userId)
          .snapshots();
    }
  }

  // Cached widgets
  Widget? _cachedSongList;
  Widget? _cachedPlaylistList;
  Widget? _cachedAlbumList;

  // This method will be called when widget.userId changes
  @override
  void didUpdateWidget(covariant ProfileContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userId != oldWidget.userId) {
      // Reset the cached widgets and reload data when userId changes
      _cachedSongList = null;
      _cachedPlaylistList = null;
      _cachedAlbumList = null;
      _isLoading = true; // Optionally show loading indicator

      // Reset state dan mulai proses loading ulang
      setState(() {
        _isLoading = true;
        _isHaveSong = false;
        _isHaveAlbum = false;
        _isHavePlaylist = false;
      });

      _loadInitialData();
      loadUserData();
    }
  }

  Future<void> _loadInitialData() async {
    // Simulate initial data loading
    await Future.delayed(const Duration(seconds: 2));

    // Ensure the widget is still mounted before calling setState
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildSongList() {
    _cachedSongList ??= SongList(
      userId: widget.userId,
      pageName: "ProfileContainer",
      playlistId: "",
      albumId: "",
    );
    return _cachedSongList!;
  }

  Widget _buildPlaylistList() {
    _cachedPlaylistList ??= const ProfilePlaylistList();
    return _cachedPlaylistList!;
  }

  Widget _buildAlbumList() {
    _cachedAlbumList ??= const ProfileAlbumList();
    return _cachedAlbumList!;
  }

  Widget buildList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: primaryTextColor,
        ),
      );
    } else if (_isSongClicked) {
      return Expanded(
        child: _buildSongList(),
      );
    } else if (_isPlaylistClicked) {
      return Expanded(
        child: _buildPlaylistList(),
      );
    } else if (_isAlbumClicked) {
      return Expanded(
        child: _buildAlbumList(),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

// Update follow status in Firestore based on whether the user is following or not
  void _onFollowChanged(bool isFollow) async {
    String userId = currentUser!.uid;

    // Reference to the user being followed
    DocumentReference userToFollowDocRef =
        FirebaseFirestore.instance.collection('users').doc(widget.userId);

    // Reference to the current user who is following or unfollowing
    DocumentReference currentUserDocRef =
        FirebaseFirestore.instance.collection('users').doc(userId);

    try {
      if (isFollow) {
        // Add current userId to the 'followers' array of the user being followed
        await userToFollowDocRef.update({
          'followers': FieldValue.arrayUnion([userId]),
        });
        // Add followed userId to the 'following' array of the current user
        await currentUserDocRef.update({
          'following': FieldValue.arrayUnion([widget.userId]),
        });
      } else {
        // Remove current userId from the 'followers' array of the user being followed
        await userToFollowDocRef.update({
          'followers': FieldValue.arrayRemove([userId]),
        });
        // Remove followed userId from the 'following' array of the current user
        await currentUserDocRef.update({
          'following': FieldValue.arrayRemove([widget.userId]),
        });
      }
    } catch (e) {
      print('Error updating follow status: $e');
    }
  }
}
