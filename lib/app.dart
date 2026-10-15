import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/controller.dart';
import 'core/models.dart';
import 'ui/theme.dart';
import 'ui/review.dart';
import 'ui/settings.dart';
import 'ui/viewer.dart';

final scannerProvider = ChangeNotifierProvider<ScannerController>(
  (ref) => throw UnimplementedError(),
);
final appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const LibraryShell()),
    GoRoute(path: '/review', builder: (_, _) => const ReviewScreen()),
  ],
);

class ScannerApp extends ConsumerWidget {
  const ScannerApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(scannerProvider);
    return MaterialApp.router(
      title: 'PDF Scanner',
      debugShowCheckedModeBanner: false,
      theme: Lumen.theme(Brightness.light),
      darkTheme: Lumen.theme(Brightness.dark),
      themeMode: c.theme,
      routerConfig: appRouter,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('en')],
    );
  }
}

Future<void> report(
  BuildContext context,
  Future<void> Function() operation,
) async {
  try {
    await operation();
  } catch (e) {
    if (context.mounted && !(e is ScanFailure && e.cancelled)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ScanFailure
                ? e.message
                : 'Could not finish. Please try again.',
          ),
        ),
      );
    }
  }
}

Future<void> captureMenu(BuildContext context, ScannerController c) async {
  if (c.busy || c.exporting) return;
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Add pages',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.document_scanner_outlined),
            title: const Text('Automatic document scanner'),
            subtitle: const Text('Detect and straighten paper edges'),
            onTap: () => Navigator.pop(context, 'scan'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Camera · manual crop'),
            subtitle: const Text(
              'Works when automatic scanning is unavailable',
            ),
            onTap: () => Navigator.pop(context, 'manual'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Import photos'),
            onTap: () => Navigator.pop(context, 'gallery'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  await report(context, () async {
    try {
      await c.capture(manual: choice == 'manual', gallery: choice == 'gallery');
    } on ScanFailure catch (e) {
      if (e.code != 'unsupported' || !context.mounted) rethrow;
      final fallback = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Use the camera instead?'),
          content: const Text(
            'Automatic scanning needs a supported device and may require a first-use download. You can capture and adjust the page corners manually, without downloading a model.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Use camera'),
            ),
          ],
        ),
      );
      if (fallback == true) await c.capture(manual: true);
    }
    if (context.mounted &&
        c.draft?.pages.isNotEmpty == true &&
        GoRouterState.of(context).uri.path != '/review')
      context.push('/review');
  });
}

class LibraryShell extends ConsumerStatefulWidget {
  const LibraryShell({super.key});
  @override
  ConsumerState<LibraryShell> createState() => _LibraryShellState();
}

class _LibraryShellState extends ConsumerState<LibraryShell>
    with WidgetsBindingObserver {
  int tab = 0;
  bool grid = true;
  String query = '';
  String sort = 'newest';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _welcome());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.read(scannerProvider).refresh();
  }

  Future<void> _welcome() async {
    final c = ref.read(scannerProvider);
    if (c.onboarded) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.document_scanner_outlined,
          color: Theme.of(ctx).colorScheme.primary,
          size: 40,
        ),
        title: const Text('Paper, without the paperwork.'),
        content: const Text(
          'Scan pages into a clean PDF. Your documents and page images are processed on this device.\n\nChoose a local folder in Settings to keep files somewhere you can find. App-owned storage can be removed when you uninstall.\n\nAutomatic scanning may need a first-use download. Diagnostics and usage reporting are off until you opt in.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Get started'),
          ),
        ],
      ),
    );
    await c.preference('onboarded', true);
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(scannerProvider);
    final scheme = Theme.of(context).colorScheme;
    final docs = c.documents
        .where((d) => d.title.toLowerCase().contains(query.toLowerCase()))
        .toList();
    if (sort == 'name')
      docs.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
    if (sort == 'size') docs.sort((a, b) => b.bytes.compareTo(a.bytes));
    return Scaffold(
      appBar: AppBar(
        title: Text(['PDF Scanner', 'Your documents', 'Settings'][tab]),
        actions: [
          if (tab == 1)
            IconButton(
              tooltip: 'Refresh documents',
              onPressed: () => report(context, c.refresh),
              icon: const Icon(Icons.refresh),
            ),
          if (tab == 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Chip(
                avatar: Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: scheme.primary,
                ),
                label: const Text('On device'),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          if (tab == 0)
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text(
                  'A little less paper.\nA lot more organised.',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Scan, tidy up, and keep it all in one place.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Icon(
                          Icons.document_scanner_outlined,
                          size: 44,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'From paper to PDF',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Invoices, notes, certificates. One page or a whole stack.',
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: c.busy
                            ? null
                            : () => captureMenu(context, c),
                        icon: const Icon(Icons.add),
                        label: const Text('Scan document'),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: c.busy
                            ? null
                            : () => report(context, () async {
                                await c.capture(gallery: true);
                                if (context.mounted &&
                                    c.draft?.pages.isNotEmpty == true)
                                  context.push('/review');
                              }),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Import photos'),
                      ),
                    ],
                  ),
                ),
                if (c.draft != null && c.draft!.pages.isNotEmpty) ...[
                  const SectionLabel('Pick up where you left off'),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(
                        '${c.draft!.pages.length} pages in your draft',
                      ),
                      subtitle: const Text(
                        'Your edits are saved on this device',
                      ),
                      trailing: const Icon(Icons.arrow_forward),
                      onTap: () => context.push('/review'),
                    ),
                  ),
                ],
                Row(
                  children: [
                    const Expanded(child: SectionLabel('Recent documents')),
                    TextButton(
                      onPressed: () => setState(() => tab = 1),
                      child: const Text('See all'),
                    ),
                  ],
                ),
                if (c.documents.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      border: Border.all(color: scheme.outlineVariant),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.folder_open_outlined, size: 32),
                        SizedBox(height: 12),
                        Text('Your next scan starts here.'),
                        SizedBox(height: 6),
                        Text(
                          'Saved PDFs and page images will live in your library.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  ...c.documents
                      .take(5)
                      .map((d) => DocumentTile(d, grid: false)),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.folder_outlined,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        c.location,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          if (tab == 1)
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: TextField(
                    onChanged: (v) => setState(() => query = v),
                    decoration: const InputDecoration(
                      hintText: 'Search documents',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${docs.length} documents',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      DropdownButton<String>(
                        value: sort,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(
                            value: 'newest',
                            child: Text('Newest first'),
                          ),
                          DropdownMenuItem(value: 'name', child: Text('Name')),
                          DropdownMenuItem(
                            value: 'size',
                            child: Text('Largest first'),
                          ),
                        ],
                        onChanged: (v) => setState(() => sort = v!),
                      ),
                      IconButton(
                        tooltip: grid ? 'Switch to list' : 'Switch to grid',
                        onPressed: () => setState(() => grid = !grid),
                        icon: Icon(
                          grid
                              ? Icons.view_list_outlined
                              : Icons.grid_view_outlined,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: docs.isEmpty
                      ? EmptyPanel(
                          icon: Icons.folder_open_outlined,
                          title: query.isEmpty
                              ? 'No PDFs yet'
                              : 'No matching documents',
                          body: query.isEmpty
                              ? 'Scan your first document to build your local library.'
                              : 'Try a different name.',
                        )
                      : grid
                      ? LayoutBuilder(
                          builder: (context, size) => GridView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: (size.maxWidth / 190)
                                      .floor()
                                      .clamp(1, 4)
                                      .toInt(),
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  mainAxisExtent:
                                      MediaQuery.textScalerOf(
                                        context,
                                      ).scale(70) +
                                      190,
                                ),
                            itemCount: docs.length,
                            itemBuilder: (_, i) =>
                                DocumentTile(docs[i], grid: true),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                          children: docs
                              .map((d) => DocumentTile(d, grid: false))
                              .toList(),
                        ),
                ),
              ],
            ),
          if (tab == 2) const SettingsScreen(),
          if (c.busy)
            ColoredBox(
              color: scheme.scrim.withValues(alpha: 0.35),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Preparing your pages…'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: tab == 0
          ? null
          : FloatingActionButton.extended(
              onPressed: () => captureMenu(context, c),
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Scan'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_open_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Files',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class DocumentTile extends ConsumerWidget {
  const DocumentTile(this.doc, {super.key, required this.grid});
  final SavedDocument doc;
  final bool grid;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final image = doc.thumb.isEmpty
        ? const Icon(Icons.picture_as_pdf_outlined, size: 40)
        : Image.file(
            File(doc.thumb),
            cacheWidth: 256,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.picture_as_pdf_outlined, size: 40),
          );
    final menu = PopupMenuButton<String>(
      tooltip: 'Actions for ${doc.title}',
      onSelected: (choice) => _action(context, ref, choice),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'share', child: Text('Share')),
        PopupMenuItem(value: 'rename', child: Text('Rename')),
        PopupMenuItem(value: 'details', child: Text('Details')),
        PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
    void open() => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => PdfViewer(doc)));
    if (!grid)
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Card(
          color: scheme.surfaceContainerLow,
          child: ListTile(
            leading: SizedBox(width: 44, height: 56, child: image),
            title: Text(
              doc.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('${doc.pages} pages · ${formatSize(doc.bytes)}'),
            trailing: menu,
            onTap: open,
          ),
        ),
      );
    return Card(
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: open,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: image,
                    ),
                  ),
                  Positioned(top: 0, right: 0, child: menu),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${doc.pages} pages · ${formatSize(doc.bytes)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    shortDate(doc.date.toLocal()),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _action(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final c = ref.read(scannerProvider);
    if (action == 'share') {
      await report(context, () => c.open(doc, share: true));
      return;
    }
    if (action == 'details') {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Document details'),
          content: SelectableText(
            '${doc.title}.pdf\n\n${doc.pages} pages · ${formatSize(doc.bytes)}\n${shortDate(doc.date.toLocal())}\n\n${doc.location}\n\n${doc.images.length} saved image files',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      return;
    }
    if (action == 'rename') {
      final text = TextEditingController(text: doc.title);
      final name = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Rename PDF'),
          content: TextField(
            controller: text,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'File name',
              suffixText: '.pdf',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, text.text),
              child: const Text('Rename'),
            ),
          ],
        ),
      );
      // Disposal after the dialog route's exit animation avoids a live field
      // listening to a disposed controller.
      Future<void>.delayed(const Duration(milliseconds: 400), text.dispose);
      if (name != null && context.mounted)
        await report(context, () => c.rename(doc, name));
      return;
    }
    if (action == 'delete') {
      var images = true;
      final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, set) => AlertDialog(
            title: const Text('Delete this document?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '“${doc.title}” will be permanently deleted. This cannot be undone.',
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: images,
                  onChanged: (v) => set(() => images = v!),
                  title: const Text('Also delete saved page images'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Keep'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ),
      );
      if (yes == true && context.mounted)
        await report(context, () => c.delete(doc, images: images));
    }
  }
}
