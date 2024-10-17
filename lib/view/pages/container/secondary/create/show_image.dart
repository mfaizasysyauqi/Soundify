import 'package:flutter/material.dart';
import 'package:soundify/provider/image_provider.dart';
import 'package:soundify/view/style/style.dart';
import 'package:provider/provider.dart';

class ShowImage extends StatefulWidget {
  const ShowImage({super.key});

  @override
  State<ShowImage> createState() => _ShowImageState();
}

class _ShowImageState extends State<ShowImage> {
  @override
  Widget build(BuildContext context) {
    return Consumer<ImageProviderData>(
      builder: (context, imageProvider, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(
              20), // Membuat sudut melengkung pada Scaffold
          child: Scaffold(
            backgroundColor: primaryColor,
            body: Padding(
              padding: const EdgeInsets.all(
                  8.0), // Menambahkan padding di seluruh Scaffold
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (imageProvider.imageBytes != null)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: AspectRatio(
                            aspectRatio:
                                1, // Set ratio to 1:1 to keep the image square
                            child: InteractiveViewer(
                              scaleEnabled: false,
                              child: Image.memory(
                                imageProvider.imageBytes!,
                                fit: BoxFit
                                    .cover, // Ensures the image fills the square container
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      overflow: TextOverflow.ellipsis,
                      imageProvider.imageFileName ?? 'No Image Selected',
                      style: const TextStyle(color: primaryTextColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
