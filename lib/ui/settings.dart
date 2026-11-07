import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app.dart';
import '../core/models.dart';
import 'theme.dart';
import 'review.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(scannerProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      children: [
        const SectionLabel('Make it yours'),
        DropdownButtonFormField<int>(
          initialValue: c.theme.index,
          decoration: const InputDecoration(labelText: 'Appearance'),
          items: const [
            DropdownMenuItem(value: 0, child: Text('Follow device')),
            DropdownMenuItem(value: 1, child: Text('Light')),
            DropdownMenuItem(value: 2, child: Text('Dark')),
          ],
          onChanged: (v) => c.preference('theme', v!),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.drafts_outlined),
          title: const Text('Saved and recovered drafts'),
          subtitle: const Text(
            'Resume an older scan. Drafts are never automatically deleted.',
          ),
          onTap: c.busy || c.exporting || c.pendingCommit != null
              ? null
              : () => _drafts(context, ref),
        ),
        const SectionLabel('Scanning defaults'),
        DropdownButtonFormField<String>(
          initialValue: c.format,
          decoration: const InputDecoration(labelText: 'Page format'),
          items: const [
            DropdownMenuItem(value: 'a4', child: Text('A4')),
            DropdownMenuItem(value: 'letter', child: Text('Letter')),
            DropdownMenuItem(value: 'fit', child: Text('Image-fit')),
          ],
          onChanged: (v) => c.preference('format', v!),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          initialValue: c.quality,
          decoration: const InputDecoration(labelText: 'Quality'),
          items: [
            for (var i = 0; i < qualityLabels.length; i++)
              DropdownMenuItem(value: i, child: Text(qualityLabels[i])),
          ],
          onChanged: (v) => c.preference('quality', v!),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: c.defaultFilter,
          decoration: const InputDecoration(labelText: 'Filter'),
          items: [
            for (var i = 0; i < filters.length; i++)
              DropdownMenuItem(value: filters[i], child: Text(filterLabels[i])),
          ],
          onChanged: (v) => c.preference('filter', v!),
        ),
        const SectionLabel('Files stay with you'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(c.needsRecovery ? Icons.warning_amber : Icons.restore),
          title: const Text('Recover file operations'),
          subtitle: Text(
            c.needsRecovery
                ? 'Reconnect your selected storage, then retry. Your recovery records are kept.'
                : 'Check interrupted renames, deletions and export rollback.',
          ),
          trailing: const Icon(Icons.refresh),
          onTap: c.busy || c.exporting
              ? null
              : () => report(context, () async {
                  await c.retryRecovery();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          c.needsRecovery
                              ? 'Storage is still unavailable. Recovery records were kept.'
                              : 'File operations recovered.',
                        ),
                      ),
                    );
                  }
                }),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.folder_outlined),
          title: const Text('Library location'),
          subtitle: Text(c.location),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => report(context, () => c.chooseFolder()),
        ),
        if (Platform.isAndroid)
          TextButton(
            onPressed: () =>
                report(context, () => c.chooseFolder(private: true)),
            child: const Text('Use private app storage instead'),
          ),
        const Text(
          'Choose local device storage for on-device files. App-owned files, including iPhone Files documents, can be removed when you uninstall. Share/export a copy to keep it independently.',
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Save page images'),
          subtitle: const Text('Save edited JPEGs next to your PDFs.'),
          value: c.saveImages,
          onChanged: (v) => c.preference('images', v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Keep original images'),
          subtitle: const Text(
            'Save unedited sources after export. Uses more space.',
          ),
          value: c.keepOriginals,
          onChanged: (v) => c.preference('originals', v),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.storage_outlined),
          title: const Text('Storage and cleanup'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _storage(context, ref),
        ),
        const SectionLabel('Privacy & diagnostics'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Share crash diagnostics'),
          subtitle: Text(
            c.monitoring.available
                ? 'Optional technical reports through Firebase. Documents are not uploaded.'
                : 'Not connected in this build. Firebase setup is required.',
          ),
          value: c.diagnostics,
          onChanged: c.monitoring.available && !c.consentUpdating
              ? (v) => report(context, () => c.preference('diagnostics', v))
              : null,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Share usage events'),
          subtitle: const Text(
            'Optional usage counts. Firebase may use app identifiers; no document content.',
          ),
          value: c.analytics,
          onChanged: c.monitoring.available && !c.consentUpdating
              ? (v) => report(context, () => c.preference('analytics', v))
              : null,
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No account. No ads. No document uploads.\n\nAutomatic scanner components may be downloaded by platform services. App-owned data is excluded from automatic backup. Copies you share elsewhere follow the destination app’s privacy settings.',
            ),
          ),
        ),
        const SectionLabel('About'),
        const Text(
          'PDF Scanner · 0.1.0\nBuilt for paper, designed for your privacy.',
        ),
        TextButton(
          onPressed: () => showLicensePage(
            context: context,
            applicationName: 'PDF Scanner',
            applicationVersion: '0.1.0',
          ),
          child: const Text('Open-source licences'),
        ),
      ],
    );
  }

  Future<void> _drafts(BuildContext context, WidgetRef ref) async {
    final c = ref.read(scannerProvider);
    await report(context, () async {
      final drafts = await c.store.drafts();
      if (!context.mounted) return;
      final selected = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Saved drafts'),
          content: SizedBox(
            width: 400,
            child: drafts.isEmpty
                ? const Text('No unsaved scans.')
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final item in drafts)
                        ListTile(
                          title: Text(
                            '${item.pages.length} ${item.pages.length == 1 ? 'page' : 'pages'}',
                          ),
                          subtitle: Text(
                            '${shortDate(item.createdAt.toLocal())} · Tap to resume',
                          ),
                          selected: item.id == c.draft?.id,
                          onTap: () => Navigator.pop(ctx, item.id),
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      if (selected == null) return;
      await c.resumeDraft(selected);
      if (context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const ReviewScreen()),
        );
      }
    });
  }

  Future<void> _storage(BuildContext context, WidgetRef ref) async {
    final c = ref.read(scannerProvider);
    await report(context, () async {
      final usage = await c.platform.call<Map>('usage');
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Storage on this device'),
          content: Text(
            'Private drafts, receipts and previews: ${formatSize((usage!['privateBytes'] as num).toInt())}\n\n${Platform.isAndroid && c.location.startsWith('Selected') ? 'Selected folder usage is managed by your Files app.' : 'Library: ${formatSize((usage['libraryBytes'] as num).toInt())}'}\n\nClean cache removes previews and share copies only. Drafts, PDFs and saved page images are kept.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
            FilledButton(
              onPressed: () async {
                await c.platform.call<void>('cleanCache');
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Clean cache'),
            ),
          ],
        ),
      );
    });
  }
}
