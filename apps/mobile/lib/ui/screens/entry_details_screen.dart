import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/search_suggestion.dart';
import '../theme/app_theme.dart';

class EntryDetailScreen extends StatefulWidget {
  final Future<DictionaryEntry> Function(String entryId) loadEntry;
  final String entryId;

  const EntryDetailScreen({
    super.key,
    required this.loadEntry,
    required this.entryId,
  });

  @override
  State<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends State<EntryDetailScreen>
    with SingleTickerProviderStateMixin {
  DictionaryEntry? _entry;
  bool _loading = true;
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _fetch();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final e = await widget.loadEntry(widget.entryId);
      if (!mounted) return;
      setState(() => _entry = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entry;

    return Scaffold(
      body: Column(
        children: [
          Container(
            color: KamusiColors.headerRed,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                          splashRadius: 22,
                        ),
                        const Expanded(
                          child: Text(
                            "Kelimeler",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: LinearProgressIndicator(minHeight: 3),
                      )
                    else if (entry != null) ...[
                      Text(
                        entry.lemma,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 28,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (entry.pronunciation != null)
                        Text(
                          entry.pronunciation!,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _ActionIcon(
                            icon: Icons.volume_up_outlined,
                            label: "Dinle",
                            onTap: () {
                              // Hook to your TTS/audio endpoint
                            },
                          ),
                          const SizedBox(width: 10),
                          _ActionIcon(
                            icon: Icons.star_border,
                            label: "Kaydet",
                            onTap: () {
                              // Hook to favorites
                            },
                          ),
                          const SizedBox(width: 10),
                          _ActionIcon(
                            icon: Icons.copy,
                            label: "Kopyala",
                            onTap: () async {
                              await Clipboard.setData(
                                  ClipboardData(text: entry.lemma));
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Kopyalandı")),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TabBar(
                        controller: _tab,
                        labelColor: KamusiColors.headerRed,
                        unselectedLabelColor: KamusiColors.textMuted,
                        indicatorColor: KamusiColors.headerRed,
                        indicatorWeight: 3,
                        labelStyle:
                            const TextStyle(fontWeight: FontWeight.w900),
                        tabs: const [
                          Tab(text: "Açıklama"),
                          Tab(text: "İlişkili Kelimeler"),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: entry == null
                ? Center(
                    child: _loading
                        ? const SizedBox.shrink()
                        : const Text("Girdi yüklenemedi."),
                  )
                : TabBarView(
                    controller: _tab,
                    children: [
                      _DefinitionsTab(entry: entry),
                      _RelatedTab(related: entry.related),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _DefinitionsTab extends StatelessWidget {
  final DictionaryEntry entry;
  const _DefinitionsTab({required this.entry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < entry.senses.length; i++) ...[
                  _SenseBlock(index: i + 1, sense: entry.senses[i]),
                  if (i != entry.senses.length - 1) const Divider(height: 22),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SenseBlock extends StatelessWidget {
  final int index;
  final EntrySense sense;

  const _SenseBlock({required this.index, required this.sense});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "$index.",
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: KamusiColors.headerRed,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: KamusiColors.cardBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                sense.pos,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: KamusiColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          sense.definition,
          style: const TextStyle(
            fontSize: 14.5,
            height: 1.3,
            fontWeight: FontWeight.w700,
            color: KamusiColors.textDark,
          ),
        ),
        if (sense.example != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: KamusiColors.cardBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              "“${sense.example!}”",
              style: const TextStyle(
                color: KamusiColors.textMuted,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.16),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.20)),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RelatedTab extends StatelessWidget {
  final List<String> related;
  const _RelatedTab({required this.related});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: related.isEmpty
                ? const Text(
                    "İlişkili kelime yok.",
                    style: TextStyle(color: KamusiColors.textMuted),
                  )
                : Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: related
                        .map(
                          (w) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: KamusiColors.cardBg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              w,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: KamusiColors.textDark,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ),
      ],
    );
  }
}
