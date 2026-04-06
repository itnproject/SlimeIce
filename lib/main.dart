import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.slimeice.channel.audio',
    androidNotificationChannelName: 'SlimeIce Audio',
    androidNotificationOngoing: true,
  );
  runApp(const SlimeIce());
}

class SlimeIce extends StatefulWidget {
  const SlimeIce({super.key});

  @override
  State<SlimeIce> createState() => _SlimeIceState();
}

class _SlimeIceState extends State<SlimeIce> {
  Color seedColor = Colors.blue;
  bool useDynamicColor = false;
  bool useEnglish = false;

  String text(String chinese, String english) {
    return useEnglish ? english : chinese;
  }

  void updateLanguage(bool value) {
    setState(() {
      useEnglish = value;
    });
  }

  void toggleDynamicColor(bool value) {
    setState(() {
      useDynamicColor = value;
    });
  }

  void updateSeedColor(Color color) {
    setState(() {
      seedColor = color;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '史莱姆冰',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
      ),
      home: MusicPlayerHomePage(
        useEnglish: useEnglish,
        useDynamicColor: useDynamicColor,
        onLanguageChanged: updateLanguage,
        onDynamicColorChanged: toggleDynamicColor,
        onSeedColorChanged: updateSeedColor,
      ),
    );
  }
}

class MusicPlayerHomePage extends StatefulWidget {
  final bool useEnglish;
  final bool useDynamicColor;
  final Function(bool) onLanguageChanged;
  final Function(bool) onDynamicColorChanged;
  final Function(Color) onSeedColorChanged;

  const MusicPlayerHomePage({
    super.key,
    required this.useEnglish,
    required this.useDynamicColor,
    required this.onLanguageChanged,
    required this.onDynamicColorChanged,
    required this.onSeedColorChanged,
  });

  @override
  State<MusicPlayerHomePage> createState() => _MusicPlayerHomePageState();
}

class _MusicPlayerHomePageState extends State<MusicPlayerHomePage> {
  final AudioPlayer audioPlayer = AudioPlayer();
  final List<MusicFile> songs = [
    MusicFile(
      path: '/sdcard/Music/song1.mp3',
      name: '欢迎使用史莱姆冰 / Welcome to SlimeIce',
    ),
  ];
  final List<Playlist> playlists = [Playlist(name: 'SlimeIce')];
  final Set<String> favorites = <String>{};
  int currentSongIndex = 0;
  bool isPlaying = false;
  double progress = 0.0;
  int tabIndex = 0;
  int playMode = 0;

  String text(String chinese, String english) {
    return widget.useEnglish ? english : chinese;
  }

  String getPlayModeText() {
    if (playMode == 0) {
      return widget.useEnglish ? 'List' : '列表';
    } else if (playMode == 1) {
      return widget.useEnglish ? 'Loop' : '单曲';
    } else {
      return widget.useEnglish ? 'Shuffle' : '随机';
    }
  }

  @override
  void initState() {
    super.initState();
    audioPlayer.positionStream.listen((position) {
      if (audioPlayer.duration != null) {
        setState(() {
          progress =
              position.inMilliseconds / audioPlayer.duration!.inMilliseconds;
        });
      }
    });
    audioPlayer.playerStateStream.listen((state) {
      setState(() {
        isPlaying = state.playing;
      });
      if (state.processingState == ProcessingState.completed) {
        if (playMode == 1) {
          _playSong(currentSongIndex);
        } else if (playMode == 2) {
          final random =
              (currentSongIndex + 1 + DateTime.now().microsecond) %
              songs.length;
          _playSong(random);
        } else {
          if (songs.isNotEmpty) {
            final next = (currentSongIndex + 1) % songs.length;
            _playSong(next);
          }
        }
      }
    });
  }

  Future<void> _addMusic() async {
    final input = html.FileUploadInputElement();
    input.accept = 'audio/*';
    input.multiple = true;
    input.click();
    await input.onChange.first;
    final files = input.files;
    if (files == null) return;
    for (final file in files) {
      final url = html.Url.createObjectUrl(file);
      final newSong = MusicFile(path: url, name: file.name);
      if (songs.every((song) => song.path != newSong.path)) {
        setState(() {
          songs.add(newSong);
        });
      }
    }
  }

  Future<void> _playSong(int index) async {
    if (index < 0 || index >= songs.length) return;
    final song = songs[index];
    setState(() {
      currentSongIndex = index;
      progress = 0.0;
    });
    final uri = song.path.startsWith('blob:')
        ? Uri.parse(song.path)
        : Uri.file(song.path);
    try {
      await audioPlayer.stop();
      await audioPlayer.setAudioSource(
        AudioSource.uri(
          uri,
          tag: MediaItem(
            id: song.path,
            album: song.displayName,
            title: song.displayName,
          ),
        ),
      );
      await audioPlayer.play();
      if (widget.useDynamicColor) {
        final color = Colors.primaries[index % Colors.primaries.length];
        widget.onSeedColorChanged(color);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text('无法播放该歌曲', 'Cannot play song'))),
      );
    }
  }

  void _toggleFavorite(MusicFile song) {
    setState(() {
      if (favorites.contains(song.path)) {
        favorites.remove(song.path);
      } else {
        favorites.add(song.path);
      }
    });
  }

  void _deleteSong(int index) {
    final removed = songs[index];
    setState(() {
      songs.removeAt(index);
      favorites.remove(removed.path);
      for (final playlist in playlists) {
        playlist.songPaths.remove(removed.path);
      }
      if (currentSongIndex >= songs.length) {
        currentSongIndex = songs.length - 1;
      }
    });
  }

  Future<void> _renameSong(int index) async {
    final controller = TextEditingController(text: songs[index].displayName);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(text('重命名', 'Rename')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: text('输入新名称', 'Enter new name'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(text('取消', 'Cancel')),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                songs[index].displayName = controller.text;
              });
              Navigator.pop(context);
            },
            child: Text(text('确认', 'OK')),
          ),
        ],
      ),
    );
  }

  void _createPlaylist() async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(text('新建歌单', 'New Playlist')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: text('歌单名称', 'Playlist name')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(text('取消', 'Cancel')),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  playlists.add(Playlist(name: name));
                });
              }
              Navigator.pop(context);
            },
            child: Text(text('创建', 'Create')),
          ),
        ],
      ),
    );
  }

  void _addSongToPlaylist(MusicFile song, Playlist playlist) {
    if (!playlist.songPaths.contains(song.path)) {
      setState(() {
        playlist.songPaths.add(song.path);
      });
    }
  }

  void _openPlaylist(Playlist playlist) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => PlaylistPage(
          playlist: playlist,
          songs: songs,
          onPlay: _playSong,
          onRemove: (path) {
            setState(() {
              playlist.songPaths.remove(path);
            });
          },
          useEnglish: widget.useEnglish,
        ),
      ),
    );
  }

  void _openSettings() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => SettingsPage(
          useEnglish: widget.useEnglish,
          useDynamicColor: widget.useDynamicColor,
          onLanguageChanged: widget.onLanguageChanged,
          onDynamicColorChanged: widget.onDynamicColorChanged,
        ),
      ),
    );
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayedSongs = tabIndex == 2
        ? songs.where((song) => favorites.contains(song.path)).toList()
        : songs;
    final isTabEmpty = tabIndex == 1
        ? playlists.isEmpty
        : displayedSongs.isEmpty;
    final emptyMessage = tabIndex == 1
        ? text('请先创建歌单', 'Create a playlist first')
        : text('收藏夹空空如也', 'No favorites yet');
    return Scaffold(
      appBar: AppBar(
        title: Text(text('史莱姆冰', 'SlimeIce')),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: tabIndex == 1
                ? isTabEmpty
                      ? Center(child: Text(emptyMessage))
                      : ListView.builder(
                          itemCount: playlists.length,
                          itemBuilder: (context, index) {
                            final playlist = playlists[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(
                                  playlist.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  text('歌曲数', 'Songs') +
                                      ': ${playlist.songPaths.length}',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _openPlaylist(playlist),
                              ),
                            );
                          },
                        )
                : isTabEmpty
                ? Center(child: Text(emptyMessage))
                : ListView.builder(
                    itemCount: displayedSongs.length,
                    itemBuilder: (context, index) {
                      final song = displayedSongs[index];
                      final actualIndex = songs.indexWhere(
                        (element) => element.path == song.path,
                      );
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: favorites.contains(song.path)
                                ? Theme.of(context).colorScheme.secondary
                                : Theme.of(context).colorScheme.primary,
                            child: Icon(
                              favorites.contains(song.path)
                                  ? Icons.favorite
                                  : Icons.music_note,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            song.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(song.name),
                          selected: actualIndex == currentSongIndex,
                          onTap: () => _playSong(actualIndex),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'favorite') {
                                _toggleFavorite(song);
                              }
                              if (value == 'rename') {
                                _renameSong(actualIndex);
                              }
                              if (value == 'delete') {
                                _deleteSong(actualIndex);
                              }
                              if (value == 'playlist') {
                                showModalBottomSheet<void>(
                                  context: context,
                                  builder: (context) => SafeArea(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: playlists
                                          .map(
                                            (playlist) => ListTile(
                                              leading: const Icon(
                                                Icons.queue_music,
                                              ),
                                              title: Text(playlist.name),
                                              onTap: () {
                                                _addSongToPlaylist(
                                                  song,
                                                  playlist,
                                                );
                                                Navigator.pop(context);
                                              },
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'favorite',
                                child: Text(
                                  favorites.contains(song.path)
                                      ? text('取消收藏', 'Unfavorite')
                                      : text('收藏', 'Favorite'),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'playlist',
                                child: Text(text('加入歌单', 'Add to playlist')),
                              ),
                              PopupMenuItem(
                                value: 'rename',
                                child: Text(text('重命名', 'Rename')),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(text('删除', 'Delete')),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Column(
              children: [
                Text(
                  songs.isNotEmpty
                      ? songs[currentSongIndex].displayName
                      : text('无歌曲', 'No songs'),
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Slider(
                  value: progress,
                  onChanged: (value) {
                    if (audioPlayer.duration != null) {
                      audioPlayer.seek(
                        Duration(
                          milliseconds:
                              (value * audioPlayer.duration!.inMilliseconds)
                                  .toInt(),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous),
                      onPressed: songs.isNotEmpty
                          ? () {
                              final next =
                                  (currentSongIndex - 1 + songs.length) %
                                  songs.length;
                              _playSong(next);
                            }
                          : null,
                    ),
                    IconButton(
                      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                      onPressed: songs.isNotEmpty
                          ? () {
                              if (isPlaying) {
                                audioPlayer.pause();
                              } else {
                                audioPlayer.play();
                              }
                            }
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next),
                      onPressed: songs.isNotEmpty
                          ? () {
                              final next =
                                  (currentSongIndex + 1) % songs.length;
                              _playSong(next);
                            }
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      icon: Icon(
                        playMode == 0
                            ? Icons.repeat
                            : playMode == 1
                            ? Icons.repeat_one
                            : Icons.shuffle,
                      ),
                      label: Text(
                        getPlayModeText(),
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () {
                        setState(() {
                          playMode = (playMode + 1) % 3;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: tabIndex == 1 ? _createPlaylist : _addMusic,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: tabIndex,
        onTap: (value) {
          setState(() {
            tabIndex = value;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.music_note),
            label: text('音乐', 'Music'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.playlist_play),
            label: text('歌单', 'Playlists'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.favorite),
            label: text('收藏', 'Favorites'),
          ),
        ],
      ),
    );
  }
}

class PlaylistPage extends StatelessWidget {
  final Playlist playlist;
  final List<MusicFile> songs;
  final Function(int) onPlay;
  final Function(String) onRemove;
  final bool useEnglish;

  const PlaylistPage({
    super.key,
    required this.playlist,
    required this.songs,
    required this.onPlay,
    required this.onRemove,
    required this.useEnglish,
  });

  String text(String chinese, String english) {
    return useEnglish ? english : chinese;
  }

  @override
  Widget build(BuildContext context) {
    final playlistSongs = songs
        .where((song) => playlist.songPaths.contains(song.path))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playlist.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  text('包含', 'Contains') +
                      ' ${playlistSongs.length} ' +
                      text('首歌曲', 'songs'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: Text(text('全部播放', 'Play All')),
                      onPressed: playlistSongs.isEmpty
                          ? null
                          : () {
                              final firstIndex = songs.indexWhere(
                                (song) => song.path == playlistSongs.first.path,
                              );
                              if (firstIndex >= 0) {
                                onPlay(firstIndex);
                              }
                            },
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.clear_all),
                      label: Text(text('清空歌单', 'Clear Playlist')),
                      onPressed: playlistSongs.isEmpty
                          ? null
                          : () {
                              for (final path in playlistSongs.map(
                                (e) => e.path,
                              )) {
                                onRemove(path);
                              }
                            },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: playlistSongs.isEmpty
                ? Center(
                    child: Text(
                      text('该歌单暂无歌曲', 'This playlist is empty'),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                : ListView.builder(
                    itemCount: playlistSongs.length,
                    itemBuilder: (context, index) {
                      final song = playlistSongs[index];
                      final realIndex = songs.indexWhere(
                        (s) => s.path == song.path,
                      );
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.secondary,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            song.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(song.name),
                          onTap: () => onPlay(realIndex),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => onRemove(song.path),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  final bool useEnglish;
  final bool useDynamicColor;
  final Function(bool) onLanguageChanged;
  final Function(bool) onDynamicColorChanged;

  const SettingsPage({
    super.key,
    required this.useEnglish,
    required this.useDynamicColor,
    required this.onLanguageChanged,
    required this.onDynamicColorChanged,
  });

  String text(String chinese, String english) {
    return useEnglish ? english : chinese;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(text('设置', 'Settings')),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchListTile(
              title: Text(text('English', 'English')),
              subtitle: Text(text('切换英语', 'Toggle English')),
              value: useEnglish,
              onChanged: onLanguageChanged,
            ),
            SwitchListTile(
              title: Text(
                text('根据音乐动态取色', 'Pick colors based on music dynamics'),
              ),
              subtitle: Text(
                text('根据播放改变主题色', 'Change theme color by playback'),
              ),
              value: useDynamicColor,
              onChanged: onDynamicColorChanged,
            ),
            const SizedBox(height: 24),
            ListTile(
              title: Text(text('作者', 'Author')),
              subtitle: const Text('itnproject'),
            ),
          ],
        ),
      ),
    );
  }
}

class MusicFile {
  String path;
  String name;
  String displayName;

  MusicFile({required this.path, required this.name}) : displayName = name;
}

class Playlist {
  String name;
  List<String> songPaths;

  Playlist({required this.name, List<String>? songPaths})
    : songPaths = songPaths ?? <String>[];
}
