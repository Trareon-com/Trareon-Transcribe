import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/utils/file_dialogs.dart';

/// Stands in for the native dialogs: answers what a desktop platform would
/// and records what `saveFile()` was asked to write.
class _FakeFilePicker extends FilePickerPlatform {
  _FakeFilePicker({this.directory, this.saveUri});

  final String? directory;
  final Uri? saveUri;
  Uint8List? savedBytes;

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    String? initialDirectory,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => directory;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    String mimeType = 'application/octet-stream',
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    savedBytes = bytes;
    return saveUri;
  }
}

void main() {
  late FilePickerPlatform realPicker;
  setUp(() => realPicker = FilePickerPlatform.instance);
  tearDown(() => FilePickerPlatform.instance = realPicker);

  test(
    'a picked folder comes back as a path without a trailing slash',
    () async {
      FilePickerPlatform.instance = _FakeFilePicker(directory: '/tmp/rekaman');
      // pickDirectory() turns the path into a directory URI, which ends in a
      // separator; a saved library path never does.
      expect(await pickDirectoryPath(), '/tmp/rekaman');
    },
  );

  test('cancelling the folder dialog returns null', () async {
    FilePickerPlatform.instance = _FakeFilePicker();
    expect(await pickDirectoryPath(), isNull);
  });

  test('the save dialog is opened with no bytes and yields a path', () async {
    final picker = _FakeFilePicker(saveUri: Uri.file('/tmp/arsip.zip'));
    FilePickerPlatform.instance = picker;
    final path = await pickSaveLocation(
      dialogTitle: 'Simpan',
      fileName: 'arsip.zip',
    );
    expect(path, '/tmp/arsip.zip');
    // The real content is written by Rust; the plugin must not be handed a
    // copy of a possibly multi-GB archive.
    expect(picker.savedBytes, isEmpty);
  });

  test('a non-file URI is treated as a cancel', () async {
    FilePickerPlatform.instance = _FakeFilePicker(
      saveUri: Uri.parse('content://downloads/1'),
    );
    expect(
      await pickSaveLocation(dialogTitle: 'Simpan', fileName: 'a.zip'),
      isNull,
    );
  });

  test('a failed export removes only an empty placeholder', () async {
    final dir = await Directory.systemTemp.createTemp('file_dialogs_test');
    addTearDown(() => dir.delete(recursive: true));
    final empty = File('${dir.path}/kosong.zip')..writeAsBytesSync([]);
    final full = File('${dir.path}/isi.zip')..writeAsBytesSync([1, 2, 3]);

    await discardEmptyPlaceholder(empty.path);
    await discardEmptyPlaceholder(full.path);
    await discardEmptyPlaceholder('${dir.path}/tidak-ada.zip');

    expect(empty.existsSync(), isFalse);
    expect(full.existsSync(), isTrue);
  });
}
