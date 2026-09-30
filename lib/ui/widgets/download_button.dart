import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../services/apk_download.dart';

class InstallButton extends StatelessWidget {
  const InstallButton({super.key, required this.entry, this.compact = false});

  final AppEntry entry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final dl = state.downloads[entry.packageName];
    final installed = entry.installed != null;
    final updating = entry.hasUpdate;

    if (dl != null) {
      if (dl.error != null) {
        return _errorButton(context, state, dl.error!);
      }
      if (dl.installing) {
        return _busy(context, 'Installing');
      }
      return _progress(context, dl.progress);
    }

    final label =
        updating ? 'Update' : installed ? 'Installed' : 'Install';
    final onTap = installed && !updating
        ? () => state.device.openApp(entry.packageName)
        : () => state.installEntry(entry);

    if (compact) {
      return FilledButton.tonal(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        child: Text(installed && !updating ? 'Open' : label),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onTap,
        child: Text(installed && !updating ? 'Open' : label),
      ),
    );
  }

  Widget _progress(BuildContext context, DownloadProgress p) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: compact ? 36 : 44,
      width: compact ? null : double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: p.fraction > 0 ? p.fraction : null,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            p.fraction > 0
                ? '${(p.fraction * 100).toStringAsFixed(0)}%'
                : 'Downloading',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _busy(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: compact ? 36 : 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 8),
          Text(text,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _errorButton(BuildContext context, AppState state, String error) {
    return OutlinedButton.icon(
      onPressed: () {
        state.dismissDownloadError(entry.packageName);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error, maxLines: 2)),
        );
      },
      icon: const Icon(Icons.refresh, size: 18),
      label: const Text('Retry'),
    );
  }
}
