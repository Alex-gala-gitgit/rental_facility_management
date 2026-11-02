import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

Future<Uint8List?> rasterizeSettlementText(String text) async {
  if (!RegExp(r'[^\x00-\xFF]').hasMatch(text)) return null;

  const fontSize = 28;
  final measuringCanvas = html.CanvasElement(width: 1, height: 1);
  final measuringContext = measuringCanvas.context2D
    ..font = '${fontSize}px sans-serif';
  final width =
      (measuringContext.measureText(text).width! + 4).ceil().clamp(1, 1800);
  const height = 40;
  final canvas = html.CanvasElement(width: width, height: height);
  canvas.context2D
    ..font = '${fontSize}px sans-serif'
    ..fillStyle = '#17233C'
    ..textBaseline = 'top'
    ..fillText(text, 2, 2);
  final encoded = canvas.toDataUrl('image/png').split(',').last;
  return Uint8List.fromList(base64Decode(encoded));
}
