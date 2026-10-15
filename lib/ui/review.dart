import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app.dart';
import '../core/models.dart';
import 'editor.dart';
import 'export.dart';
import 'theme.dart';

class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(scannerProvider),
        draft = ref.watch(scannerProvider).draft;
    final pages = draft?.pages ?? <PageAsset>[];
    return Scaffold(
      appBar: AppBar(
        title: Text('${pages.length} ${pages.length == 1 ? 'page' : 'pages'}'),
        actions: [
          IconButton(
            tooltip: 'Discard draft',
            onPressed: () => _discard(context, ref),
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
          TextButton.icon(
            onPressed: c.busy ? null : () => captureMenu(context, c),
            icon: const Icon(Icons.add),
            label: const Text('Add pages'),
          ),
        ],
      ),
      body: pages.isEmpty
          ? const EmptyPanel(
              icon: Icons.description_outlined,
              title: 'No pages in this draft',
              body: 'Add a page or go back. Your library is safe.',
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.touch_app_outlined,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Tap a page to edit. Use its menu to move or retake.',
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, size) => GridView.builder(
                      padding: const EdgeInsets.all(20),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: (size.maxWidth / 180)
                            .floor()
                            .clamp(1, 4)
                            .toInt(),
                        mainAxisExtent:
                            MediaQuery.textScalerOf(context).scale(36) + 240,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                      ),
                      itemCount: pages.length,
                      itemBuilder: (context, index) {
                        final p = pages[index];
                        return Card(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLow,
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => _edit(context, ref, index),
                                  child: Semantics(
                                    label:
                                        'Edit page ${index + 1} of ${pages.length}',
                                    button: true,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Image.file(
                                        File(p.thumb),
                                        cacheWidth: 512,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, _, _) => const Icon(
                                          Icons.broken_image_outlined,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Page ${index + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    tooltip: 'Actions for page ${index + 1}',
                                    onSelected: (value) => report(
                                      context,
                                      () async {
                                        if (value == 'edit') {
                                          await _edit(context, ref, index);
                                          return;
                                        }
                                        if (value == 'up' || value == 'down')
                                          await c.updatePages(
                                            moved(
                                              pages,
                                              index,
                                              value == 'up'
                                                  ? index - 1
                                                  : index + 1,
                                            ),
                                          );
                                        if (value == 'remove') {
                                          await c.updatePages(
                                            [...pages]..removeAt(index),
                                          );
                                          if (context.mounted)
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: const Text(
                                                  'Page removed',
                                                ),
                                                duration: const Duration(
                                                  seconds: 8,
                                                ),
                                                action: SnackBarAction(
                                                  label: 'Undo',
                                                  onPressed: () => report(
                                                    context,
                                                    () async {
                                                      final now =
                                                          List<PageAsset>.of(
                                                            c.draft?.pages ??
                                                                [],
                                                          );
                                                      if (now.any(
                                                        (e) => e.id == p.id,
                                                      ))
                                                        return;
                                                      now.insert(
                                                        index
                                                            .clamp(
                                                              0,
                                                              now.length,
                                                            )
                                                            .toInt(),
                                                        p,
                                                      );
                                                      await c.updatePages(now);
                                                    },
                                                  ),
                                                ),
                                              ),
                                            );
                                        }
                                        if (value == 'retake') {
                                          final before = List<PageAsset>.of(
                                            c.draft!.pages,
                                          );
                                          await c.capture(manual: true);
                                          final after = c.draft!.pages;
                                          if (after.length > before.length) {
                                            final replacement = after.last;
                                            final next = [...before];
                                            next[index] = replacement;
                                            await c.updatePages(next);
                                          }
                                        }
                                      },
                                    ),
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Edit page'),
                                      ),
                                      PopupMenuItem(
                                        value: 'up',
                                        enabled: index > 0,
                                        child: const Text('Move earlier'),
                                      ),
                                      PopupMenuItem(
                                        value: 'down',
                                        enabled: index < pages.length - 1,
                                        child: const Text('Move later'),
                                      ),
                                      PopupMenuItem(
                                        value: 'retake',
                                        enabled: pages.length < maxPages,
                                        child: const Text('Retake with camera'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'remove',
                                        child: Text('Remove page'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 12,
                                  right: 12,
                                  bottom: 12,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    filterLabels[filters.indexOf(p.filter)],
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FilledButton.icon(
            onPressed: pages.isEmpty || c.busy
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const ExportScreen(),
                    ),
                  ),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Save PDF'),
          ),
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, int index) async {
    final c = ref.read(scannerProvider);
    final page = c.draft!.pages[index];
    final edited = await Navigator.push<PageAsset>(
      context,
      MaterialPageRoute(builder: (_) => PageEditor(page)),
    );
    if (edited != null) {
      final pages = List<PageAsset>.of(c.draft!.pages);
      final current = pages.indexWhere((p) => p.id == page.id);
      if (current >= 0) {
        pages[current] = edited;
        await c.updatePages(pages);
      }
    }
  }

  Future<void> _discard(BuildContext context, WidgetRef ref) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard this draft?'),
        content: const Text(
          'The unsaved pages and edits will be removed. Saved PDFs will not be changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep draft'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (yes == true && context.mounted)
      await report(context, () async {
        await ref.read(scannerProvider).discard();
        if (context.mounted) Navigator.pop(context);
      });
  }
}
