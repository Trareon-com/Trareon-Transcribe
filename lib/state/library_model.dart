/// Session list, shared between the sidebar and the library screen.
///
/// The sidebar is the product's spine now (blueprint §4.1) — session
/// history used to be hidden behind an unlabelled folder icon — so the
/// list has to live somewhere both screens can read it, and has to be
/// refreshable from either.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/library_index.dart';
import 'models.dart';
import 'settings_model.dart';

class LibraryListState {
  final List<LibraryEntry> entries;
  final bool loading;

  /// Set when the directory could not be read at all. Distinct from an
  /// empty library, which is an ordinary first-run state.
  final String? error;

  const LibraryListState({
    this.entries = const [],
    this.loading = true,
    this.error,
  });

  LibraryListState copyWith({
    List<LibraryEntry>? entries,
    bool? loading,
    String? error,
    bool clearError = false,
  }) =>
      LibraryListState(
        entries: entries ?? this.entries,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
      );
}

class LibraryListNotifier extends StateNotifier<LibraryListState> {
  LibraryListNotifier(this._libraryPath) : super(const LibraryListState()) {
    refresh();
  }

  /// A list that never touches disk. Widget tests run inside a fake-async
  /// zone where real file I/O does not complete, so a disk-backed sidebar
  /// would leave every main-screen test spinning forever.
  LibraryListNotifier.seeded(List<LibraryEntry> entries)
      : _libraryPath = '',
        super(LibraryListState(entries: entries, loading: false));

  String _libraryPath;

  /// Points the list at a different directory — the user changed the
  /// output folder in Settings.
  void setLibraryPath(String path) {
    if (path == _libraryPath) return;
    _libraryPath = path;
    refresh();
  }

  Future<void> refresh() async {
    if (_libraryPath.isEmpty) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final load = await loadLibraryIndex(resolveTilde(_libraryPath));
      if (!mounted) return;
      state = LibraryListState(entries: load.entries, loading: false);
    } catch (e) {
      if (!mounted) return;
      state = LibraryListState(entries: const [], loading: false, error: '$e');
    }
  }

  /// Re-reads one session after the player may have changed it, instead of
  /// re-scanning the corpus (audit A.2-5).
  Future<void> refreshOne(String dirPath) async {
    final refreshed = await buildLibraryEntry(directoryFor(dirPath));
    if (!mounted || refreshed == null) return;
    final index = state.entries.indexWhere((e) => e.dirPath == dirPath);
    if (index < 0) {
      await refresh();
      return;
    }
    final updated = [...state.entries];
    updated[index] = refreshed;
    state = state.copyWith(entries: updated);
  }

  void removeEntry(String dirPath) {
    state = state.copyWith(
      entries: state.entries.where((e) => e.dirPath != dirPath).toList(),
    );
  }
}

final libraryListProvider =
    StateNotifierProvider<LibraryListNotifier, LibraryListState>((ref) {
  final notifier = LibraryListNotifier(ref.watch(settingsProvider).libraryPath);
  ref.listen<AppSettings>(settingsProvider, (previous, next) {
    if (previous?.libraryPath != next.libraryPath) {
      notifier.setLibraryPath(next.libraryPath);
    }
  });
  return notifier;
});
