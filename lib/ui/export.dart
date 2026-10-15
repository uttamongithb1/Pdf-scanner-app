import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app.dart';
import '../core/models.dart';
import 'theme.dart';
import 'viewer.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});
  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  final name = TextEditingController(text: defaultTitle(DateTime.now()));
  late String format;
  late int quality;
  int margin = 5;
  bool landscape = false;
  SavedDocument? saved;
  String? error;
  bool cancelling = false;
  @override
  void initState() {
    super.initState();
    final c = ref.read(scannerProvider);
    format = c.format;
    quality = c.quality;
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(scannerProvider);
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !c.exporting,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !c.exporting,
          title: Text(
            saved != null
                ? 'Document saved'
                : c.exporting
                ? 'Saving your document'
                : 'Save PDF',
          ),
        ),
        body: saved != null
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 24),
                  Icon(
                    Icons.check_circle_outline,
                    size: 72,
                    color: scheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    saved!.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${saved!.pages} pages · ${formatSize(saved!.bytes)}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Icon(Icons.folder_outlined),
                          const SizedBox(height: 12),
                          Text(saved!.location, textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          Text(
                            saved!.images.isEmpty
                                ? 'PDF saved. No image copies were requested.'
                                : 'PDF and ${saved!.images.length} page image files saved.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => PdfViewer(saved!),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open PDF'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () =>
                        report(context, () => c.open(saved!, share: true)),
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Share'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () =>
                        Navigator.popUntil(context, (route) => route.isFirst),
                    child: const Text('Done'),
                  ),
                ],
              )
            : c.exporting
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 84,
                        height: 84,
                        child: CircularProgressIndicator(
                          value: c.total > 0 && c.phase == 'Processing pages'
                              ? c.completed / c.total
                              : null,
                          strokeWidth: 5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        c.phase,
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text('${c.completed} of ${c.total} pages'),
                      const SizedBox(height: 20),
                      Text(c.location, textAlign: TextAlign.center),
                      const SizedBox(height: 28),
                      OutlinedButton(
                        onPressed: cancelling
                            ? null
                            : () async {
                                setState(() => cancelling = true);
                                await c.cancel();
                              },
                        child: Text(
                          cancelling ? 'Cancelling…' : 'Cancel export',
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Your draft will be kept if you cancel.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Text(
                    '${c.draft?.pages.length ?? 0} pages, ready to keep.',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: name,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      labelText: 'File name',
                      suffixText: '.pdf',
                      helperText: 'Existing files are never overwritten.',
                    ),
                  ),
                  const SectionLabel('Page format'),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final entry in const {
                        'a4': 'A4',
                        'letter': 'Letter',
                        'fit': 'Image-fit',
                      }.entries)
                        ChoiceChip(
                          label: Text(entry.value),
                          selected: format == entry.key,
                          onSelected: (_) => setState(() => format = entry.key),
                        ),
                    ],
                  ),
                  if (format != 'fit')
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Landscape'),
                      value: landscape,
                      onChanged: (v) => setState(() => landscape = v),
                    ),
                  const SectionLabel('Quality'),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (var i = 0; i < qualityLabels.length; i++)
                        ChoiceChip(
                          label: Text(qualityLabels[i]),
                          selected: quality == i,
                          onSelected: (_) => setState(() => quality = i),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${qualityDpi[quality]} DPI target · final size depends on your pages.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (format != 'fit') ...[
                    const SectionLabel('Margins'),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final m in [0, 5, 10])
                          ChoiceChip(
                            label: Text(m == 0 ? 'None' : '$m mm'),
                            selected: margin == m,
                            onSelected: (_) => setState(() => margin = m),
                          ),
                      ],
                    ),
                  ],
                  const SectionLabel('Save location'),
                  Card(
                    color: scheme.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.folder_outlined),
                          const SizedBox(width: 12),
                          Expanded(child: Text(c.location)),
                          TextButton(
                            onPressed: () =>
                                report(context, () => c.chooseFolder()),
                            child: Text(
                              Theme.of(context).platform == TargetPlatform.iOS
                                  ? 'Files'
                                  : 'Change',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Save page images'),
                    subtitle: const Text(
                      'Keep a JPEG of each edited page in Images/Processed.',
                    ),
                    value: c.saveImages,
                    onChanged: (v) => c.preference('images', v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Keep original images'),
                    subtitle: const Text(
                      'Keep unedited copies in Images/Originals. Uses extra storage.',
                    ),
                    value: c.keepOriginals,
                    onChanged: (v) => c.preference('originals', v),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'PDF size is known after processing. High quality and image copies use more space. Shared files can be opened outside this app.',
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error!,
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: () async {
                      setState(() {
                        error = null;
                        cancelling = false;
                      });
                      try {
                        final result = await c.export(
                          title: name.text,
                          format: format,
                          quality: quality,
                          margin: margin,
                          landscape: landscape,
                        );
                        if (mounted) setState(() => saved = result);
                      } catch (e) {
                        if (mounted)
                          setState(
                            () => error = e is ScanFailure
                                ? e.message
                                : 'Could not finish. Your draft is safe. Please try again.',
                          );
                      }
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Save PDF'),
                  ),
                ],
              ),
      ),
    );
  }
}
