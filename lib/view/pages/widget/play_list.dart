import 'package:flutter/material.dart';
import 'package:soundify/view/style/style.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PlayList extends StatefulWidget {
  final String creatorId;
  final String playlistId;
  final String playlistName;
  final String playlistDescription;
  final String playlistImageUrl;
  final DateTime timestamp;
  final int playlistUserIndex;
  final List songListIds;
  final int totalDuration;

  const PlayList({
    super.key,
    required this.creatorId,
    required this.playlistId,
    required this.playlistName,
    required this.playlistDescription,
    required this.playlistImageUrl,
    required this.timestamp,
    required this.playlistUserIndex,
    required this.songListIds,
    required this.totalDuration,
  });

  @override
  State<PlayList> createState() => _PlayListState();
}

class _PlayListState extends State<PlayList> {
  // Cache untuk menyimpan user name berdasarkan creatorId
  Map<String, String?> userNameCache = {};

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      color: primaryColor,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                color: widget.playlistImageUrl.isEmpty
                    ? primaryTextColor
                    : tertiaryColor,
              ),
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
                    ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.playlistName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: primaryTextColor,
                    fontSize: smallFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Cek cache sebelum memanggil StreamBuilder
                userNameCache.containsKey(widget.creatorId)
                    ? Text(
                        userNameCache[widget.creatorId] ?? 'Unknown',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: primaryTextColor,
                          fontSize: microFontSize,
                        ),
                      )
                    : StreamBuilder<DocumentSnapshot>(
                        stream: getUserStream(widget.creatorId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Text(
                              '',
                              style: TextStyle(
                                color: primaryTextColor,
                                fontSize: microFontSize,
                              ),
                            );
                          } else if (snapshot.hasError) {
                            return const Text(
                              'Error',
                              style: TextStyle(
                                color: primaryTextColor,
                                fontSize: microFontSize,
                              ),
                            );
                          } else if (snapshot.hasData) {
                            var userData = snapshot.data?.data();
                            String? userName = userData != null
                                ? (userData as Map<String, dynamic>)['name']
                                : 'Unknown';

                            // Simpan nama pengguna ke dalam cache
                            if (!userNameCache.containsKey(widget.creatorId)) {
                              userNameCache[widget.creatorId] = userName;
                            }

                            return Text(
                              userName ?? 'Unknown',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: primaryTextColor,
                                fontSize: microFontSize,
                              ),
                            );
                          } else {
                            return const Text(
                              'Unknown',
                              style: TextStyle(
                                color: primaryTextColor,
                                fontSize: microFontSize,
                              ),
                            );
                          }
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Menggunakan stream untuk mengambil data pengguna secara real-time
  Stream<DocumentSnapshot> getUserStream(String creatorId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(creatorId)
        .snapshots(); // Menggunakan snapshots() untuk mendapatkan stream
  }
}
