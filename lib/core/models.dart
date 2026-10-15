import 'dart:math' as math;

const maxPages = 50;
const filters = ['original', 'enhanced', 'greyscale', 'bw'];
const filterLabels = ['Original', 'Enhanced', 'Greyscale', 'B&W'];
const qualityLabels = ['Small', 'Balanced', 'High'];
const qualityDpi = [150, 200, 300];
const qualityJpeg = [70, 85, 92];

/// Coordinates are in the EXIF-normalised source, clockwise TL/TR/BR/BL.
class PageAsset {
  const PageAsset({
    required this.id,
    required this.path,
    required this.thumb,
    required this.width,
    required this.height,
    this.rotation = 0,
    this.filter = 'original',
    this.corners = const [0, 0, 1, 0, 1, 1, 0, 1],
  });
  final String id, path, thumb, filter;
  final int width, height, rotation;
  final List<double> corners;
  PageAsset copyWith({
    int? rotation,
    String? filter,
    List<double>? corners,
    String? thumb,
  }) => PageAsset(
    id: id,
    path: path,
    thumb: thumb ?? this.thumb,
    width: width,
    height: height,
    rotation: rotation ?? this.rotation,
    filter: filter ?? this.filter,
    corners: corners ?? this.corners,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'thumb': thumb,
    'width': width,
    'height': height,
    'rotation': rotation,
    'filter': filter,
    'corners': corners,
  };
  factory PageAsset.fromJson(Map<String, dynamic> j) => PageAsset(
    id: j['id'] as String,
    path: j['path'] as String,
    thumb: j['thumb'] as String,
    width: (j['width'] as num).toInt(),
    height: (j['height'] as num).toInt(),
    rotation: (j['rotation'] as num?)?.toInt() ?? 0,
    filter: j['filter'] as String? ?? 'original',
    corners:
        (j['corners'] as List?)?.map((e) => (e as num).toDouble()).toList() ??
        const [0, 0, 1, 0, 1, 1, 0, 1],
  );
}

class Draft {
  const Draft(this.id, this.pages, this.createdAt);
  final String id;
  final List<PageAsset> pages;
  final DateTime createdAt;
  Draft withPages(List<PageAsset> value) =>
      Draft(id, List.unmodifiable(value), createdAt);
  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'pages': pages.map((p) => p.toJson()).toList(),
  };
  factory Draft.fromJson(Map<String, dynamic> j) => Draft(
    j['id'] as String,
    (j['pages'] as List)
        .map((p) => PageAsset.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList(),
    DateTime.parse(j['createdAt'] as String),
  );
}

class SavedDocument {
  SavedDocument(this.data);
  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  String get title => data['title'] as String;
  String get uri => data['uri'] as String;
  String get thumb => data['thumb'] as String? ?? '';
  String get location => data['location'] as String? ?? 'App storage';
  int get pages => (data['pages'] as num).toInt();
  int get bytes => (data['bytes'] as num).toInt();
  DateTime get date => DateTime.parse(data['createdAt'] as String);
  List<String> get images => List<String>.from(data['images'] as List? ?? []);
}

String safeStem(String input) {
  var s = input.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '').trim();
  s = s
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'^[. ]+|[. ]+$'), '');
  if (s.isEmpty) s = 'Scan';
  if (RegExp(
    r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$',
    caseSensitive: false,
  ).hasMatch(s))
    s = 'Scan_$s';
  // Clip code points, never split UTF-16 surrogate pairs.
  return String.fromCharCodes(s.runes.take(100));
}

String defaultTitle(DateTime d) {
  String pad(int n) => '$n'.padLeft(2, '0');
  return 'Scan_${d.year}-${pad(d.month)}-${pad(d.day)}_${pad(d.hour)}${pad(d.minute)}${pad(d.second)}';
}

String formatSize(int bytes) => bytes < 1024 * 1024
    ? '${(bytes / 1024).ceil()} KB'
    : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
String shortDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

bool validCorners(List<double> c) {
  if (c.length != 8 || c.any((v) => !v.isFinite || v < 0 || v > 1))
    return false;
  double cross(int a, int b, int d) =>
      (c[b * 2] - c[a * 2]) * (c[d * 2 + 1] - c[b * 2 + 1]) -
      (c[b * 2 + 1] - c[a * 2 + 1]) * (c[d * 2] - c[b * 2]);
  if (List.generate(
    4,
    (i) => cross(i, (i + 1) % 4, (i + 2) % 4),
  ).any((v) => v <= 0))
    return false;
  double area = 0;
  for (var i = 0; i < 4; i++) {
    final n = (i + 1) % 4;
    area += c[i * 2] * c[n * 2 + 1] - c[n * 2] * c[i * 2 + 1];
  }
  return area.abs() / 2 >= 0.02;
}

List<T> moved<T>(List<T> source, int from, int to) {
  final result = List<T>.of(source);
  if (from < 0 || from >= result.length) return result;
  final item = result.removeAt(from);
  result.insert(math.max(0, math.min(to, result.length)), item);
  return result;
}

class ScanFailure implements Exception {
  ScanFailure(this.code);
  final String code;
  bool get cancelled => code == 'cancelled';
  String get message => switch (code) {
    'permission' =>
      'Access is off. Enable it in device Settings or import photos instead.',
    'storage' =>
      'Not enough space. Your draft is safe. Free up space and try again.',
    'localFolder' =>
      'Choose Internal storage or an SD card in the system folder picker. Cloud folders are not supported as the local library.',
    'folder' =>
      'This folder is unavailable. Reconnect it or choose a local folder in Settings.',
    'unsupported' =>
      'Automatic scanning is unavailable. Use the camera fallback or import photos.',
    'index' =>
      'Your PDF was saved, but the library could not update. Retry Save PDF or reopen the app to recover it. Do not discard the draft.',
    'limit' =>
      'This draft has reached the 50-page limit. Save it before adding more pages.',
    'collision' => 'That name is already in use. Choose a different name.',
    'busy' => 'An operation is already running. Please wait.',
    'missing' => 'This file was moved or deleted outside the app.',
    'cancelled' => 'Cancelled. Your draft is safe.',
    _ =>
      'The operation could not finish. Your draft is safe. Please try again.',
  };
  @override
  String toString() => message;
}
