import 'package:flutter/material.dart';
import 'package:soundify/view/pages/widget/song_list.dart';
import 'package:soundify/view/style/style.dart';

class LikedSongContainer extends StatefulWidget {
  const LikedSongContainer({super.key});

  @override
  State<LikedSongContainer> createState() => _LikedSongContainerState();
}

class _LikedSongContainerState extends State<LikedSongContainer> {
  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20), // Atur sudut melengkung
      child: Scaffold(
        backgroundColor: primaryColor,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: Row(
                children: [
                  const SizedBox(width: 30),
                  const Text(
                    "#",
                    style: TextStyle(
                        color: primaryTextColor, fontWeight: mediumWeight),
                  ),
                  const SizedBox(width: 30),
                  const Text(
                    'Title',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: primaryTextColor, fontWeight: mediumWeight),
                  ),
                  const SizedBox(width: 30),
                  screenWidth > 1280
                      // ? SizedBox(width: 255)
                      ? const Spacer()
                      : const SizedBox.shrink(),
                  screenWidth > 1280
                      ? const SizedBox(width: 5)
                      : const SizedBox.shrink(),
                  screenWidth > 1280
                      ? const Text(
                          "Album",
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: primaryTextColor,
                              fontWeight: mediumWeight),
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
                              color: primaryTextColor,
                              fontWeight: mediumWeight),
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
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Divider(color: primaryTextColor,),
            ),
            // Expanded widget to give space for the SongList
            Expanded(
              child: SongList(
                userId: currentUser!.uid,
                pageName: "LikedSongContainer",
                playlistId: "",
                albumId: "",
              ),
            ),
          ],
        ),
      ),
    );
  }
}
