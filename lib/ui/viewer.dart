import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app.dart';
import '../core/models.dart';
import 'theme.dart';

class PdfViewer extends ConsumerStatefulWidget {
  const PdfViewer(this.doc, {super.key});
  final SavedDocument doc;
  @override
  ConsumerState<PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends ConsumerState<PdfViewer> {
  int page = 0;
  late Future<Map<String, dynamic>> rendered;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    rendered = ref
        .read(scannerProvider)
        .platform
        .call<Map>('pdfPage', {'uri': widget.doc.uri, 'index': page})
        .then((v) => Map<String, dynamic>.from(v!));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.doc.title),
      actions: [
        IconButton(
          tooltip: 'Share PDF',
          onPressed: () => report(
            context,
            () => ref.read(scannerProvider).open(widget.doc, share: true),
          ),
          icon: const Icon(Icons.ios_share),
        ),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: rendered,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return EmptyPanel(
            icon: Icons.insert_drive_file_outlined,
            title: 'This file is unavailable',
            body: 'It may have been moved, removed or changed outside the app.',
            action: OutlinedButton(
              onPressed: () => setState(load),
              child: const Text('Try again'),
            ),
          );
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        return ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: InteractiveViewer(
            maxScale: 5,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Image.file(
                  File(snapshot.data!['path'] as String),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        );
      },
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Previous page',
              onPressed: page == 0
                  ? null
                  : () => setState(() {
                      page--;
                      load();
                    }),
              icon: const Icon(Icons.chevron_left),
            ),
            Text('Page ${page + 1} of ${widget.doc.pages}'),
            IconButton(
              tooltip: 'Next page',
              onPressed: page >= widget.doc.pages - 1
                  ? null
                  : () => setState(() {
                      page++;
                      load();
                    }),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    ),
  );
}
