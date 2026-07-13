import 'package:file_picker/file_picker.dart';

import 'picked_image_data.dart';

Future<PickedImageData?> pickDocumentForUpload() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    allowMultiple: false,
    withData: true,
  );
  if (result == null || result.files.single.bytes == null) return null;
  final file = result.files.single;
  return PickedImageData(name: file.name, bytes: file.bytes!);
}
