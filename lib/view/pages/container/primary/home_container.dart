import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:soundify/provider/widget_size_provider.dart';
import 'package:soundify/provider/widget_state_provider_2.dart';
import 'package:soundify/view/pages/container/secondary/show_detail_song.dart';
import 'package:soundify/view/pages/widget/song_list.dart';
import 'package:soundify/view/style/style.dart';
import 'package:provider/provider.dart';

class HomeContainer extends StatefulWidget {
  const HomeContainer({super.key});

  @override
  State<HomeContainer> createState() => _HomeContainerState();
}

final currentUser = FirebaseAuth.instance.currentUser;

class _HomeContainerState extends State<HomeContainer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<WidgetStateProvider2>(context, listen: false)
            .changeWidget(const ShowDetailSong(), 'ShowDetailSong');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double minContentWidth = 360;
    double providedMaxWidth =
        Provider.of<WidgetSizeProvider>(context).expandedWidth;

    // Ensure providedMaxWidth is not smaller than minContentWidth
    double adjustedMaxWidth =
        providedMaxWidth.clamp(minContentWidth, double.infinity);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20), // Atur sudut melengkung
      child: Scaffold(
        backgroundColor: primaryColor,
        body: SingleChildScrollView(
          scrollDirection: Axis.horizontal, // Scroll horizontal
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: minContentWidth,
              maxWidth: screenWidth.clamp(
                minContentWidth,
                adjustedMaxWidth,
              ),
            ),
            child: Column(
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
                          color: primaryTextColor,
                          fontWeight: mediumWeight,
                        ),
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
                  child: Divider(
                    color: primaryTextColor,
                  ),
                ),
                // Expanded widget to give space for the SongList
                Expanded(
                  child: SongList(
                    userId: currentUser!.uid,
                    pageName: "HomeContainer",
                    playlistId: "",
                    albumId: "",
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
