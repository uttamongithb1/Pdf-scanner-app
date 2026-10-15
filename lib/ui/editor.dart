import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app.dart';
import '../core/models.dart';

class PageEditor extends ConsumerStatefulWidget {
  const PageEditor(this.page, {super.key});
  final PageAsset page;
  @override
  ConsumerState<PageEditor> createState() => _PageEditorState();
}

class _PageEditorState extends ConsumerState<PageEditor> {
  late PageAsset page;
  late Future<String> preview;
  final transform = TransformationController();
  @override
  void initState() {
    super.initState();
    page = widget.page;
    preview = ref.read(scannerProvider).platform.preview(page);
  }

  @override
  void dispose() {
    transform.dispose();
    super.dispose();
  }

  void update(PageAsset value) {
    setState(() {
      page = value;
      preview = ref.read(scannerProvider).platform.preview(page);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Edit page'),
      actions: [
        TextButton(
          onPressed: () => update(
            page.copyWith(
              rotation: 0,
              filter: 'original',
              corners: const [0, 0, 1, 0, 1, 1, 0, 1],
            ),
          ),
          child: const Text('Reset'),
        ),
      ],
    ),
    body: Column(
      children: [
        Expanded(
          child: Container(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xff07090d)
                : const Color(0xffe4e7ec),
            child: FutureBuilder<String>(
              future: preview,
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return Center(
                    child: TextButton(
                      onPressed: () => update(page),
                      child: const Text('Preview failed. Try again'),
                    ),
                  );
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                return InteractiveViewer(
                  transformationController: transform,
                  maxScale: 5,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Image.file(
                        File(snapshot.data!),
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final crop = await Navigator.push<List<double>>(
                    context,
                    MaterialPageRoute(builder: (_) => CropScreen(page)),
                  );
                  if (crop != null) update(page.copyWith(corners: crop));
                },
                icon: const Icon(Icons.crop),
                label: const Text('Corners'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    update(page.copyWith(rotation: (page.rotation + 90) % 360)),
                icon: const Icon(Icons.rotate_right),
                label: const Text('Rotate'),
              ),
              IconButton(
                tooltip: 'Zoom in',
                onPressed: () =>
                    transform.value = transform.value.clone()
                      ..multiply(Matrix4.diagonal3Values(1.2, 1.2, 1)),
                icon: const Icon(Icons.zoom_in),
              ),
              IconButton(
                tooltip: 'Reset zoom',
                onPressed: () => transform.value = Matrix4.identity(),
                icon: const Icon(Icons.zoom_out_map),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < filters.length; i++)
                ChoiceChip(
                  label: Text(filterLabels[i]),
                  selected: page.filter == filters[i],
                  onSelected: (_) => update(page.copyWith(filter: filters[i])),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextButton(
            onPressed: () => _all(context),
            child: const Text('Apply this filter to every page'),
          ),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: FilledButton(
          onPressed: () async {
            await report(context, () async {
              final path = await preview;
              if (context.mounted)
                Navigator.pop(context, page.copyWith(thumb: path));
            });
          },
          child: const Text('Done'),
        ),
      ),
    ),
  );
  Future<void> _all(BuildContext context) async {
    final c = ref.read(scannerProvider);
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apply filter to all pages?'),
        content: const Text('Other edits and crops will stay unchanged.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    await report(context, () async {
      final pages = <PageAsset>[];
      for (final p in c.draft!.pages) {
        final edited = p.copyWith(filter: page.filter);
        final path = await c.platform.preview(edited);
        pages.add(edited.copyWith(thumb: path));
      }
      await c.updatePages(pages);
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Filter applied to all pages')),
        );
    });
  }
}

class CropScreen extends StatefulWidget {
  const CropScreen(this.page, {super.key});
  final PageAsset page;
  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  late List<double> corners;
  int selected = 0;
  static const names = ['Top left', 'Top right', 'Bottom right', 'Bottom left'];
  @override
  void initState() {
    super.initState();
    corners = [...widget.page.corners];
  }

  void move(int index, double dx, double dy) {
    final next = [...corners];
    next[index * 2] = (next[index * 2] + dx).clamp(0.0, 1.0).toDouble();
    next[index * 2 + 1] = (next[index * 2 + 1] + dy).clamp(0.0, 1.0).toDouble();
    if (validCorners(next)) setState(() => corners = next);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Adjust page corners'),
      actions: [
        TextButton(
          onPressed: () => setState(() => corners = [0, 0, 1, 0, 1, 1, 0, 1]),
          child: const Text('Reset'),
        ),
      ],
    ),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Drag the corners to the edges of your paper, or select a corner and use the arrow controls. This view shows the original orientation.',
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, size) {
              final ratio = widget.page.width / widget.page.height;
              final width = math.min(
                    size.maxWidth - 40,
                    size.maxHeight * ratio,
                  ),
                  height = width / ratio;
              return Center(
                child: SizedBox(
                  width: width,
                  height: height,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: Image.file(
                          File(widget.page.path),
                          fit: BoxFit.fill,
                          cacheWidth: 1200,
                        ),
                      ),
                      Positioned.fill(
                        child: CustomPaint(painter: _CropPainter(corners)),
                      ),
                      for (var i = 0; i < 4; i++)
                        Positioned(
                          left: corners[i * 2] * width - 24,
                          top: corners[i * 2 + 1] * height - 24,
                          child: Semantics(
                            label: '${names[i]} corner',
                            selected: selected == i,
                            button: true,
                            child: GestureDetector(
                              onTap: () => setState(() => selected = i),
                              onPanUpdate: (d) => move(
                                i,
                                d.delta.dx / width,
                                d.delta.dy / height,
                              ),
                              child: Container(
                                width: 48,
                                height: 48,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: selected == i
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.black,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < 4; i++)
                ChoiceChip(
                  label: Text(names[i]),
                  selected: selected == i,
                  onSelected: (_) => setState(() => selected = i),
                ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Move corner left',
              onPressed: () => move(selected, -0.005, 0),
              icon: const Icon(Icons.arrow_back),
            ),
            IconButton(
              tooltip: 'Move corner up',
              onPressed: () => move(selected, 0, -0.005),
              icon: const Icon(Icons.arrow_upward),
            ),
            IconButton(
              tooltip: 'Move corner down',
              onPressed: () => move(selected, 0, 0.005),
              icon: const Icon(Icons.arrow_downward),
            ),
            IconButton(
              tooltip: 'Move corner right',
              onPressed: () => move(selected, 0.005, 0),
              icon: const Icon(Icons.arrow_forward),
            ),
          ],
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: FilledButton(
          onPressed: () => Navigator.pop(context, corners),
          child: const Text('Use these corners'),
        ),
      ),
    ),
  );
}

class _CropPainter extends CustomPainter {
  _CropPainter(this.c);
  final List<double> c;
  @override
  void paint(Canvas canvas, Size size) {
    final polygon = Path()..moveTo(c[0] * size.width, c[1] * size.height);
    for (var i = 1; i < 4; i++)
      polygon.lineTo(c[i * 2] * size.width, c[i * 2 + 1] * size.height);
    polygon.close();
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      polygon,
    );
    canvas.drawPath(
      outside,
      Paint()..color = Colors.black.withValues(alpha: 0.5),
    );
    canvas.drawPath(
      polygon,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    canvas.drawPath(
      polygon,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_CropPainter old) => old.c != c;
}
