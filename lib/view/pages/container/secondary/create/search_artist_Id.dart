import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Import Firestore
import 'package:provider/provider.dart';
import 'package:soundify/provider/song_provider.dart';
import 'package:soundify/view/style/style.dart';

// Controller for the search text field
TextEditingController searchArtistController = TextEditingController();
TextEditingController artistIdController = TextEditingController();
// List to hold user data and filtered search results
List<QueryDocumentSnapshot> users = [];
List<QueryDocumentSnapshot> filteredUsers = [];

class SearchArtistId extends StatefulWidget {
  const SearchArtistId({super.key});

  @override
  State<SearchArtistId> createState() => _SearchArtistIdState();
}

class _SearchArtistIdState extends State<SearchArtistId> {
  @override
  void initState() {
    super.initState();
    _loadUsers();

    // Add listener for search field
    searchArtistController.addListener(() {
      setState(() {
        _filterUsers(); // Update filtered users when the search field changes
      });
    });
  }

  // Function to fetch data from Firestore
  Future<void> _loadUsers() async {
    QuerySnapshot usersSnapshot =
        await FirebaseFirestore.instance.collection('users').get();

    setState(() {
      users = usersSnapshot.docs;
      filteredUsers = users; // Initially display all users
    });
  }

  // Function to filter users
  List<QueryDocumentSnapshot> _filterUsers(
      [List<QueryDocumentSnapshot>? userList]) {
    String query = searchArtistController.text.toLowerCase(); // Get search input
    List<QueryDocumentSnapshot> userDocs = userList ?? users;

    if (query.isEmpty) {
      return userDocs; // If query is empty, return all users
    }

    return userDocs.where((user) {
      return user['username']
          .toLowerCase()
          .contains(query); // Filter users based on username
    }).toList();
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
              "Select Artist ID",
              style: TextStyle(color: Colors.white), // primaryTextColor
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextFormField(
              style: const TextStyle(color: Colors.white), // primaryTextColor
              controller: searchArtistController,
              readOnly: false,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.all(8),
                prefixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _filterUsers(); // Call filter function
                        });
                      },
                      icon: const Icon(
                        Icons.search,
                        color: Colors.white, // primaryTextColor
                      ),
                    ),
                    const VerticalDivider(
                      color: Colors.white, // Divider color
                      width: 1,
                      thickness: 1,
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
                hintText: 'Search Username',
                hintStyle:
                    const TextStyle(color: Colors.white), // primaryTextColor
                border: const OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.white, // primaryTextColor
                  ),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.white, // primaryTextColor
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16.0),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Divider(),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: primaryTextColor,
                    ),
                  );
                }

                List<QueryDocumentSnapshot> allUsers = snapshot.data!.docs;
                List<QueryDocumentSnapshot> displayedUsers =
                    _filterUsers(allUsers);

                return ListView(
                  children: displayedUsers.map((user) {
                    return ListTile(
                      title: Text(
                        user['username'],
                        style: const TextStyle(
                          color: Colors.white, // primaryTextColor
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      onTap: () {
                        // Access and update the provider
                        Provider.of<SongProvider>(context, listen: false)
                            .setArtistId(user['userId']);
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
