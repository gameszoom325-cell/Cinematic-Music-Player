import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'jamendo_service.dart';

class JamendoPage extends StatefulWidget {
  const JamendoPage({super.key});
  @override
  State<JamendoPage> createState() => _JamendoPageState();
}

class _JamendoPageState extends State<JamendoPage> {
  final _player = AudioPlayer();
  final _searchCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  JamendoService? _service;
  List<JamendoTrack> _tracks = [];
  JamendoTrack? _current;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('jamendo_client_id');
    if (id == null || id.isEmpty) {
      // Default fallback client ID provided for this project
      const defaultId = 'fd914c0b';
      id = defaultId;
      await prefs.setString('jamendo_client_id', id);
    }
    if (id.isNotEmpty) {
      _idCtrl.text = id;
      _service = JamendoService(id);
      await _load(() => _service!.popular());
    }
    if (mounted) setState(() {});
  }

  Future<void> _saveId() async {
    final id = _idCtrl.text.trim();
    if (id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jamendo_client_id', id);
    setState(() => _service = JamendoService(id));
    await _load(() => _service!.popular());
  }

  Future<void> _load(Future<List<JamendoTrack>> Function() job) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final t = await job();
      if (mounted) setState(() => _tracks = t);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not load songs. Check your internet and client ID.\n$e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _play(JamendoTrack t) async {
    setState(() => _current = t);
    try {
      await _player.setUrl(t.audioUrl);
      await _player.play();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Cannot play this track: $e')));
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _searchCtrl.dispose();
    _idCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_service == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Online Music (Jamendo)')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Paste your free Jamendo Client ID to enable online music.'),
              const SizedBox(height: 12),
              TextField(
                controller: _idCtrl,
                decoration: const InputDecoration(labelText: 'Client ID'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _saveId, child: const Text('Save')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchCtrl,
          decoration: const InputDecoration(hintText: 'Search songs or artists'),
          onSubmitted: (q) => q.trim().isEmpty
              ? _load(() => _service!.popular())
              : _load(() => _service!.search(q.trim())),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.vpn_key_outlined),
            tooltip: 'Change Client ID',
            onPressed: () => setState(() => _service = null),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!)))
              : _tracks.isEmpty
                  ? const Center(child: Text('No tracks found.'))
                  : ListView.builder(
                  itemCount: _tracks.length,
                  itemBuilder: (_, i) {
                    final t = _tracks[i];
                    return ListTile(
                      selected: t.id == _current?.id,
                      leading: t.imageUrl.isEmpty
                          ? const Icon(Icons.music_note)
                          : Image.network(t.imageUrl, width: 48, height: 48, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.music_note)),
                      title: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => _play(t),
                    );
                  },
                ),
      bottomNavigationBar: _current == null
          ? null
          : StreamBuilder<PlayerState>(
              stream: _player.playerStateStream,
              builder: (_, snap) {
                final playing = snap.data?.playing ?? false;
                return ListTile(
                  title: Text(_current!.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${_current!.artist} · via Jamendo (Creative Commons)'),
                  trailing: IconButton(
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                    onPressed: () => playing ? _player.pause() : _player.play(),
                  ),
                );
              },
            ),
    );
  }
}
