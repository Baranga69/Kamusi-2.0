import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../data/server_store.dart';
import '../../providers/app_providers.dart';
import '../theme/kamusi_learn_colors.dart';

/// Where the app looks for its data.
///
/// The address used to be fixed at build time, which is correct for a release
/// and useless on a home network: a laptop's IP moves whenever the router
/// decides it should, and every move meant a rebuild. This is ten seconds
/// instead.
///
/// It tests the address for real before saving rather than validating the
/// text and hoping, because "looks like a URL" and "answers" are different
/// questions and only the second one matters.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

enum _TestState { idle, running, ok, failed }

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _controller =
      TextEditingController(text: ref.read(apiBaseUrlProvider));

  _TestState _test = _TestState.idle;
  String? _detail;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<bool> _check(String url) async {
    setState(() {
      _test = _TestState.running;
      _detail = null;
    });
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
      ));
      final response = await dio.get('${ServerStore.normalise(url)}/health');
      final ok = response.statusCode == 200;
      if (mounted) {
        setState(() {
          _test = ok ? _TestState.ok : _TestState.failed;
          _detail = ok ? null : 'HTTP ${response.statusCode}';
        });
      }
      return ok;
    } catch (error) {
      if (mounted) {
        setState(() {
          _test = _TestState.failed;
          // The reason matters: "connection refused" and "no route to host"
          // send someone to different places.
          _detail = error is DioException
              ? (error.message ?? error.type.name)
              : error.toString();
        });
      }
      return false;
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final typed = _controller.text;
    if (!ServerStore.looksUsable(typed)) {
      setState(() {
        _test = _TestState.failed;
        _detail = l10n.settingsServerInvalid;
      });
      return;
    }
    final url = ServerStore.normalise(typed);
    await ref.read(serverStoreProvider).save(url);
    // Writing the provider rebuilds the Dio client and everything that reads
    // it, so the next request goes to the new address with no restart.
    ref.read(apiBaseUrlProvider.notifier).state = url;
    if (!mounted) {
      return;
    }
    _controller.text = url;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.settingsSaved)));
  }

  Future<void> _reset() async {
    await ref.read(serverStoreProvider).clear();
    ref.read(apiBaseUrlProvider.notifier).state = buildTimeApiBaseUrl;
    if (!mounted) {
      return;
    }
    setState(() {
      _controller.text = buildTimeApiBaseUrl;
      _test = _TestState.idle;
      _detail = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final learnColors = theme.extension<KamusiLearnColors>();
    final current = ref.watch(apiBaseUrlProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            l10n.settingsServerTitle,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.settingsServerBody,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.settingsServerLabel,
              hintText: l10n.settingsServerHint,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.dns_outlined),
            ),
            onChanged: (_) => setState(() {
              _test = _TestState.idle;
              _detail = null;
            }),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _test == _TestState.running
                    ? null
                    : () => _check(_controller.text),
                icon: _test == _TestState.running
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering, size: 18),
                label: Text(
                  _test == _TestState.running
                      ? l10n.settingsTesting
                      : l10n.settingsTest,
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(onPressed: _save, child: Text(l10n.settingsSave)),
            ],
          ),
          if (_test == _TestState.ok || _test == _TestState.failed) ...[
            const SizedBox(height: 12),
            _Result(
              ok: _test == _TestState.ok,
              label: _test == _TestState.ok
                  ? l10n.settingsTestOk
                  : l10n.settingsTestFailed,
              detail: _detail,
              learnColors: learnColors,
            ),
          ],
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          Text(
            l10n.settingsDefaultIs(buildTimeApiBaseUrl),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: current == buildTimeApiBaseUrl ? null : _reset,
              icon: const Icon(Icons.restart_alt, size: 18),
              label: Text(l10n.settingsReset),
            ),
          ),
        ],
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.ok,
    required this.label,
    required this.detail,
    required this.learnColors,
  });

  final bool ok;
  final String label;
  final String? detail;
  final KamusiLearnColors? learnColors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = ok
        ? (learnColors?.correctContainer ?? theme.colorScheme.secondaryContainer)
        : (learnColors?.incorrectContainer ?? theme.colorScheme.errorContainer);
    final foreground = ok
        ? (learnColors?.onCorrectContainer ??
            theme.colorScheme.onSecondaryContainer)
        : (learnColors?.onIncorrectContainer ??
            theme.colorScheme.onErrorContainer);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            size: 18,
            color: foreground,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
                if (detail != null && detail!.isNotEmpty)
                  Text(
                    detail!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: foreground.withValues(alpha: 0.85)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
