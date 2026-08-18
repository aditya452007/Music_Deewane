import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:music_deewane/utils/load_image.dart';

Future<PaletteGenerator> getPalleteFromImage(String url) async {
  ImageProvider<Object> placeHolder =
      const AssetImage("assets/icons/logo.jpeg");

  try {
    return await PaletteGenerator.fromImageProvider(
      getImageProviderSync(url),
    );
  } catch (e) {
    return await PaletteGenerator.fromImageProvider(placeHolder);
  }
}
