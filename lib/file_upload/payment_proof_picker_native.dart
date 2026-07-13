import 'package:file_picker/file_picker.dart';

import 'picked_image_data.dart';

Future<PickedImageData?> pickPaymentProof() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    withData: true,
  );
  final file = result?.files.single;
  if (file?.bytes == null) return null;
  return PickedImageData(name: file!.name, bytes: file.bytes!);
}
