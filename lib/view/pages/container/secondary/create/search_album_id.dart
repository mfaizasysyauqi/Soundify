import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:soundify/provider/album_provider.dart';
import 'package:soundify/view/style/style.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

class SearchAlbumId extends StatefulWidget {
  const SearchAlbumId({super.key});

  @override
  State<SearchAlbumId> createState() => _SearchAlbumIdState();
}

final TextEditingController _albumNameController = TextEditingController();
bool _isTextFilled = false;
bool _isSecondFieldVisible = false;
TextEditingController searchAlbumController = TextEditingController();
TextEditingController albumIdController = TextEditingController();

class _SearchAlbumIdState extends State<SearchAlbumId> {
  @override
  void initState() {
    super.initState();
    _albumNameController.addListener(() {
      setState(() {
        _isTextFilled = _albumNameController.text.isNotEmpty;
      });
    });

    searchAlbumController.addListener(() {
      setState(() {});
    });
  }

  // Function to filter albums based on search query
  List<QueryDocumentSnapshot> _filterAlbums(
      List<QueryDocumentSnapshot> albums) {
    String query = searchAlbumController.text.toLowerCase();
    if (query.isEmpty) {
      return albums;
    } else {
      return albums.where((album) {
        return album['albumName'].toLowerCase().contains(query);
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              "Select Album ID",
              style: TextStyle(color: Colors.white), // primaryTextColor
            ),
          ),
          // First TextFormField for search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextFormField(
              style: const TextStyle(color: Colors.white), // primaryTextColor
              controller: searchAlbumController,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.all(8),
                prefixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {});
                      },
                      icon: const Icon(
                        Icons.search,
                        color: primaryTextColor,
                      ),
                    ),
                    const VerticalDivider(
                      color: Colors.white,
                      width: 1,
                      thickness: 1,
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _isSecondFieldVisible = !_isSecondFieldVisible;
                    });
                  },
                  icon: Icon(
                    _isSecondFieldVisible ? Icons.remove : Icons.add,
                    color: primaryTextColor,
                  ),
                ),
                hintText: 'Search Album Name',
                hintStyle: const TextStyle(color: Colors.white),
                border: const OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.white,
                  ),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8.0),
          // Second TextFormField for adding album name
          if (_isSecondFieldVisible)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextFormField(
                style: const TextStyle(color: Colors.white), // primaryTextColor
                controller: _albumNameController,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.all(8),
                  prefixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(
                          Icons.album,
                          color: primaryTextColor,
                        ),
                      ),
                      const VerticalDivider(
                        color: Colors.white,
                        width: 1,
                        thickness: 1,
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                  suffixIcon: _isTextFilled
                      ? IconButton(
                          onPressed: () {
                            _submitAlbumData();
                          },
                          icon: const Icon(
                            Icons.check,
                            color: primaryTextColor,
                          ),
                        )
                      : null,
                  hintText: 'Album Name',
                  hintStyle: const TextStyle(color: Colors.white),
                  border: const OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.white,
                    ),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8.0),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Divider(),
          ),
          // Expanded widget with StreamBuilder
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('albums').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
              color: primaryTextColor,
            ),
                  );
                }

                List<QueryDocumentSnapshot> allAlbums = snapshot.data!.docs;
                List<QueryDocumentSnapshot> filteredAlbums =
                    _filterAlbums(allAlbums);

                return SingleChildScrollView(
                  child: ListBody(
                    children: filteredAlbums.map((album) {
                      return ListTile(
                        title: Text(
                          album['albumName'],
                          style: const TextStyle(
                            color: Colors.white, // primaryTextColor
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        onTap: () {
                          // Access and update the provider
                          Provider.of<AlbumProvider>(context, listen: false)
                              .setAlbumId(album['albumId']);
                        },
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  final currentUser = FirebaseAuth.instance.currentUser;

  Future<DocumentReference> _submitAlbumData() async {
    String albumName = _albumNameController.text.trim();

    if (albumName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Album name is missing.')),
      );
      return Future.error("Fields missing");
    }

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User is not logged in')),
      );
      return Future.error("User is not logged in");
    }

    // Step 1: Get the number of albums created by the current user
    QuerySnapshot userPlaylists = await FirebaseFirestore.instance
        .collection('albums')
        .where('creatorId', isEqualTo: currentUser?.uid)
        .get();

    // Calculate albumUserIndex (number of existing albums + 1)
    int albumUserIndex = userPlaylists.docs.length + 1;
    try {
      DocumentReference documentReference =
          await FirebaseFirestore.instance.collection('albums').add(
        {
          'albumId': '',
          'creatorId': currentUser?.uid,
          'albumName': albumName,
          'albumDescription': "",
          'albumImageUrl': "",
          'timestamp': FieldValue.serverTimestamp(),
          'albumUserIndex': albumUserIndex,
          'songListIds': [],
          'totalDuration': 0,
        },
      );

      String albumId = documentReference.id;

      await documentReference.update({'albumId': albumId});

      _albumNameController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Data successfully submitted to Firestore')),
      );

      return documentReference;
    } catch (e) {
      print('Error submitting data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit data: $e')),
      );
      return Future.error("Submission error");
    }
  }
}
