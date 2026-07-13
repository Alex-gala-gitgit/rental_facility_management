import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'picked_image_data.dart';

Future<PickedImageData?> pickImageForUpload() async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/jpeg,image/png,image/webp,image/*'
    ..multiple = false;
  input.style
    ..position = 'fixed'
    ..left = '-9999px'
    ..top = '-9999px';
  html.document.body?.append(input);

  final selection = Completer<html.File?>();
  late StreamSubscription<html.Event> subscription;
  subscription = input.onChange.listen((_) {
    if (!selection.isCompleted) {
      selection.complete(
        input.files == null || input.files!.isEmpty ? null : input.files!.first,
      );
    }
  });
  input.click();

  try {
    final file = await selection.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () => null,
    );
    if (file == null) return null;
    final reader = html.FileReader();
    final loaded = Completer<void>();
    reader.onLoad.listen((_) => loaded.complete());
    reader.onError.listen((_) => loaded.completeError(
          StateError('The selected image could not be read.'),
        ));
    reader.readAsArrayBuffer(file);
    await loaded.future;
    final result = reader.result;
    final bytes = result is ByteBuffer
        ? Uint8List.view(result)
        : result is Uint8List
            ? result
            : throw StateError('The selected image has an unsupported format.');
    return PickedImageData(name: file.name, bytes: bytes);
  } finally {
    await subscription.cancel();
    input.remove();
  }
}
