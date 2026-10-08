/// On-disk session library.
///
/// A session is a directory under the configured library path containing the
/// exported transcript (`*.json`, written by the Rust exporter), optionally
/// the source/captured audio, and — new here — a [kMetaFilename] sidecar.
///
/// The sidecar exists because everything Meetily-parity needs beyond raw
/// segments has nowhere else to live: a summary, the template it was made
/// with, a user-chosen title independent of the folder name, and which model
/// produced the transcript. The transcript `*.json` is a bare segment array
/// and must stay that way — it is also an export artifact the user may hand
/// to other tools.
///
/// Sessions written before the sidecar existed load fine: every field falls
/// back to something derivable from the directory itself.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../state/models.dart';
import '../utils/atomic_file.dart';
import 'library_index.dart' show normaliseTags;

const String kMetaFilename = 'trareon-session.json';

/// Copy of the transcript taken immediately before "Transkrip Ulang"
/// replaces it. An hour of hand corrections used to be destroyed by one
/// button with no backup and no undo.
const String kTranscriptBackupFilename = 'trareon-transkrip-cadangan.json';

/// Audio container extensions recognised when locating a session's playable
/// source file.
const Set<String> kAudioExtensions = {
  'wav',
  'mp3',
  'm4a',
  'aac',
  'ogg',
  'flac',
  'opus',
  'mp4',
  'mov',
  'mkv',
};

/// Sidecar contents. Everything is optional — a missing sidecar yields
/// [SessionMeta.empty] and the library still renders.
class SessionMeta {
  /// User-facing title. Independent of the directory name so renaming never
  /// has to move files (which would break `audioPath` and the exported
  /// filenames inside the folder).
  final String? title;
  final String summary;
  final SummaryTemplate? summaryTemplate;

  /// Id of the user-authored template the summary came from (F8), when it was
  /// not a built-in. Recorded so "which template produced this?" has an
  /// answer six months later.
  final String? summaryCustomTemplateId;

  final DateTime? summaryGeneratedAt;

  /// Language and model the transcript was produced with, so "Transkrip
  /// Ulang" can show what it is replacing.
  final String? language;
  final String? model;

  /// Markers the notulis dropped during the meeting (F9). Kept here rather
  /// than in the transcript JSON because that file is a bare segment array
  /// and also an export artifact the user may hand to other tools.
  final List<Bookmark> bookmarks;

  /// The official-notulen form as last filled in (F2), so re-exporting a
  /// meeting months later reproduces the same document instead of an empty
  /// form.
  final NotulenFormData? notulen;

  /// Set once the background "perhalus transkrip" pass (F5) has finished for
  /// this session, so it is never queued twice.
  final bool autoRetranscribeDone;

  /// Captured tracks whose audio the transcript does not yet account for.
  ///
  /// Written at save time from the engine's coverage check and cleared one
  /// entry at a time as the completion pass finishes each. It is what makes
  /// "resume on next launch" work: the queue itself is in memory, but the
  /// fact that a session is unfinished is on disk, next to the session.
  ///
  /// A session with a non-empty list is **not finished** and must never be
  /// presented as such.
  final List<String> pendingCompletion;

  /// Fraction of the recording's *speech* the transcript covers, as last
  /// measured. Null for a session saved before this existed — unknown, not
  /// incomplete.
  final double? coverageFraction;

  /// Folders/tags the session is filed under (F20).
  ///
  /// Tags, not directories: a meeting is routinely both "Anggaran" and
  /// "Mingguan", and a folder on disk can only be in one place. Keeping
  /// them in the sidecar also means renaming a tag never moves a file.
  final List<String> tags;

  /// "Tindak Lanjut" rows (F6), as the user last left them.
  ///
  /// Stored rather than re-parsed from [summary] on every open: the
  /// checklist is editable — a status ticked to "selesai" or a corrected
  /// PJ is the user's work, and re-deriving it from the model's text
  /// would throw that away.
  final List<ActionItem> actionItems;

  const SessionMeta({
    this.title,
    this.summary = '',
    this.summaryTemplate,
    this.summaryCustomTemplateId,
    this.summaryGeneratedAt,
    this.language,
    this.model,
    this.bookmarks = const [],
    this.notulen,
    this.autoRetranscribeDone = false,
    this.pendingCompletion = const [],
    this.coverageFraction,
    this.actionItems = const [],
    this.tags = const [],
  });

  static const SessionMeta empty = SessionMeta();

  bool get hasSummary => summary.trim().isNotEmpty;

  /// Whether audio recorded in this session is still untranscribed.
  bool get isIncomplete => pendingCompletion.isNotEmpty;

  SessionMeta copyWith({
    String? title,
    String? summary,
    SummaryTemplate? summaryTemplate,
    String? summaryCustomTemplateId,
    DateTime? summaryGeneratedAt,
    String? language,
    String? model,
    List<Bookmark>? bookmarks,
    NotulenFormData? notulen,
    bool? autoRetranscribeDone,
    List<String>? pendingCompletion,
    double? coverageFraction,
    List<ActionItem>? actionItems,
    List<String>? tags,
  }) {
    return SessionMeta(
      title: title ?? this.title,
      summary: summary ?? this.summary,
      summaryTemplate: summaryTemplate ?? this.summaryTemplate,
      summaryCustomTemplateId:
          summaryCustomTemplateId ?? this.summaryCustomTemplateId,
      summaryGeneratedAt: summaryGeneratedAt ?? this.summaryGeneratedAt,
      language: language ?? this.language,
      model: model ?? this.model,
      bookmarks: bookmarks ?? this.bookmarks,
      notulen: notulen ?? this.notulen,
      autoRetranscribeDone: autoRetranscribeDone ?? this.autoRetranscribeDone,
      pendingCompletion: pendingCompletion ?? this.pendingCompletion,
      coverageFraction: coverageFraction ?? this.coverageFraction,
      actionItems: actionItems ?? this.actionItems,
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    if (title != null) 'title': title,
    if (summary.isNotEmpty) 'summary': summary,
    if (summaryTemplate != null) 'summary_template': summaryTemplate!.name,
    if (summaryCustomTemplateId != null)
      'summary_custom_template': summaryCustomTemplateId,
    if (summaryGeneratedAt != null)
      'summary_generated_at': summaryGeneratedAt!.toIso8601String(),
    if (language != null) 'language': language,
    if (model != null) 'model': model,
    if (bookmarks.isNotEmpty)
      'bookmarks': [
        for (final bookmark in bookmarks)
          {'timestamp': bookmark.timestamp, 'note': bookmark.note},
      ],
    if (notulen != null) 'notulen': notulen!.toJson(),
    if (autoRetranscribeDone) 'auto_retranscribe_done': true,
    if (pendingCompletion.isNotEmpty) 'pending_completion': pendingCompletion,
    if (coverageFraction != null) 'coverage_fraction': coverageFraction,
    if (actionItems.isNotEmpty)
      'action_items': [for (final item in actionItems) _actionItemToJson(item)],
    if (tags.isNotEmpty) 'tags': tags,
  };

  /// Tolerant of every field being absent, of the wrong type, or naming a
  /// template this build doesn't know — a hand-edited or
  /// newer-version sidecar must not make a session unopenable.
  factory SessionMeta.fromJson(Map<String, dynamic> json) {
    final templateName = json['summary_template'];
    return SessionMeta(
      title: json['title'] is String ? json['title'] as String : null,
      summary: json['summary'] is String ? json['summary'] as String : '',
      summaryTemplate: templateName is String
          ? SummaryTemplate.values
                .where((t) => t.name == templateName)
                .firstOrNull
          : null,
      summaryCustomTemplateId: json['summary_custom_template'] is String
          ? json['summary_custom_template'] as String
          : null,
      summaryGeneratedAt: json['summary_generated_at'] is String
          ? DateTime.tryParse(json['summary_generated_at'] as String)
          : null,
      language: json['language'] is String ? json['language'] as String : null,
      model: json['model'] is String ? json['model'] as String : null,
      bookmarks: _bookmarksFromJson(json['bookmarks']),
      notulen: json['notulen'] is Map<String, dynamic>
          ? NotulenFormData.fromJson(json['notulen'] as Map<String, dynamic>)
          : null,
      autoRetranscribeDone: json['auto_retranscribe_done'] == true,
      pendingCompletion: json['pending_completion'] is List
          ? (json['pending_completion'] as List).whereType<String>().toList()
          : const [],
      coverageFraction: (json['coverage_fraction'] as num?)?.toDouble(),
      actionItems: _actionItemsFromJson(json['action_items']),
      tags: normaliseTags(json['tags']),
    );
  }
}

Map<String, dynamic> _actionItemToJson(ActionItem item) => {
  'id': item.id,
  'tugas': item.tugas,
  'pj': item.penanggungJawab,
  'tenggat': item.tenggat,
  'status': item.status.name,
  if (item.segmentIds.isNotEmpty) 'segments': item.segmentIds.toList(),
};

/// Action items from a sidecar, with nonsense dropped.
///
/// A row with no `tugas` is not a task, and an unknown status name (a
/// newer build's, or a hand edit) falls back to "belum" rather than
/// making the whole session unopenable.
List<ActionItem> _actionItemsFromJson(Object? raw) {
  if (raw is! List) return const [];
  final out = <ActionItem>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    final tugas = entry['tugas'];
    if (tugas is! String || tugas.trim().isEmpty) continue;
    final statusName = entry['status'];
    final segments = entry['segments'];
    out.add(
      ActionItem(
        id: entry['id'] is String && (entry['id'] as String).isNotEmpty
            ? entry['id'] as String
            : 'T${out.length + 1}',
        tugas: tugas,
        penanggungJawab: entry['pj'] is String ? entry['pj'] as String : '',
        tenggat: entry['tenggat'] is String ? entry['tenggat'] as String : '',
        status:
            ActionStatus.values
                .where((s) => s.name == statusName)
                .firstOrNull ??
            ActionStatus.belum,
        segmentIds: Uint32List.fromList(
          segments is List
              ? [
                  for (final id in segments)
                    if (id is int && id >= 0) id,
                ]
              : const [],
        ),
      ),
    );
  }
  return out;
}

/// Bookmarks, sorted by timestamp and with nonsense dropped. A hand-edited
/// sidecar must not be able to put a marker at NaN or before the recording
/// started.
List<Bookmark> _bookmarksFromJson(Object? raw) {
  if (raw is! List) return const [];
  final out = <Bookmark>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    final timestamp = (entry['timestamp'] as num?)?.toDouble();
    if (timestamp == null || timestamp.isNaN || timestamp < 0) continue;
    out.add(
      Bookmark(
        timestamp: timestamp,
        note: entry['note'] is String ? entry['note'] as String : '',
      ),
    );
  }
  out.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return out;
}

/// The "Notulen Rapat" form as the user last filled it in.
///
/// A Dart-side mirror of the Rust `NotulenForm` rather than the generated
/// class itself: this one has to serialise to JSON for the sidecar, and the
/// FRB-generated class has neither `toJson` nor a `copyWith`. [toRust]
/// converts at the call boundary.
class NotulenFormData {
  const NotulenFormData({
    this.template = NotulenTemplate.dinas,
    this.instansi = '',
    this.unitKerja = '',
    this.nomor = '',
    this.judul = '',
    this.hari = '',
    this.tanggal = '',
    this.waktu = '',
    this.tempat = '',
    this.pimpinan = '',
    this.notulis = '',
    this.peserta = const [],
    this.agenda = const [],
    this.ringkasan = '',
    this.pembahasan = '',
    this.jalannyaRapat = const [],
    this.pihak = const [],
    this.keputusan = const [],
    this.tindakLanjut = const [],
    this.kopSuratPath = '',
    this.lampirkanTranskrip = false,
    this.sumberCatatan = '',
    this.panjang = NotulenLength.sedang,
    this.konteksDokumenPath = '',
    this.konteksDokumenNama = '',
  });

  final NotulenTemplate template;
  final String instansi;
  final String unitKerja;
  final String nomor;
  final String judul;
  final String hari;
  final String tanggal;
  final String waktu;
  final String tempat;
  final String pimpinan;
  final String notulis;
  final List<String> peserta;
  final List<String> agenda;
  final String ringkasan;
  final String pembahasan;

  /// Risalah Rapat only: the ordered record of interventions.
  final List<NotulenIntervention> jalannyaRapat;

  /// Berita Acara only: "kami yang bertanda tangan di bawah ini".
  final List<String> pihak;
  final List<String> keputusan;
  final List<NotulenTask> tindakLanjut;
  final String kopSuratPath;
  final bool lampirkanTranskrip;

  /// Manual "poin catatan" notes typed/pasted by the user. Empty means the
  /// session transcript is the source instead.
  final String sumberCatatan;

  /// Target length the model is asked for.
  final NotulenLength panjang;

  /// Picked local document's path/filename, used as extra context.
  /// Display-only — the extracted text is cached in the dialog's state,
  /// not persisted, since re-reading the file on resume is cheap and
  /// keeps the sidecar free of document contents.
  final String konteksDokumenPath;
  final String konteksDokumenNama;

  NotulenFormData copyWith({
    NotulenTemplate? template,
    String? instansi,
    String? unitKerja,
    String? nomor,
    String? judul,
    String? hari,
    String? tanggal,
    String? waktu,
    String? tempat,
    String? pimpinan,
    String? notulis,
    List<String>? peserta,
    List<String>? agenda,
    String? ringkasan,
    String? pembahasan,
    List<NotulenIntervention>? jalannyaRapat,
    List<String>? pihak,
    List<String>? keputusan,
    List<NotulenTask>? tindakLanjut,
    String? kopSuratPath,
    bool? lampirkanTranskrip,
    String? sumberCatatan,
    NotulenLength? panjang,
    String? konteksDokumenPath,
    String? konteksDokumenNama,
  }) {
    return NotulenFormData(
      template: template ?? this.template,
      instansi: instansi ?? this.instansi,
      unitKerja: unitKerja ?? this.unitKerja,
      nomor: nomor ?? this.nomor,
      judul: judul ?? this.judul,
      hari: hari ?? this.hari,
      tanggal: tanggal ?? this.tanggal,
      waktu: waktu ?? this.waktu,
      tempat: tempat ?? this.tempat,
      pimpinan: pimpinan ?? this.pimpinan,
      notulis: notulis ?? this.notulis,
      peserta: peserta ?? this.peserta,
      agenda: agenda ?? this.agenda,
      ringkasan: ringkasan ?? this.ringkasan,
      pembahasan: pembahasan ?? this.pembahasan,
      jalannyaRapat: jalannyaRapat ?? this.jalannyaRapat,
      pihak: pihak ?? this.pihak,
      keputusan: keputusan ?? this.keputusan,
      tindakLanjut: tindakLanjut ?? this.tindakLanjut,
      kopSuratPath: kopSuratPath ?? this.kopSuratPath,
      lampirkanTranskrip: lampirkanTranskrip ?? this.lampirkanTranskrip,
      sumberCatatan: sumberCatatan ?? this.sumberCatatan,
      panjang: panjang ?? this.panjang,
      konteksDokumenPath: konteksDokumenPath ?? this.konteksDokumenPath,
      konteksDokumenNama: konteksDokumenNama ?? this.konteksDokumenNama,
    );
  }

  /// Converts to the engine's form. `poinPenting` is derived from the
  /// session's bookmarks at export time rather than stored, so editing a
  /// bookmark is reflected in the next export without re-saving the form.
  NotulenForm toRust({List<String> poinPenting = const []}) => NotulenForm(
    template: template,
    instansi: instansi,
    unitKerja: unitKerja,
    nomor: nomor,
    judul: judul,
    hari: hari,
    tanggal: tanggal,
    waktu: waktu,
    tempat: tempat,
    pimpinan: pimpinan,
    notulis: notulis,
    peserta: peserta,
    agenda: agenda,
    ringkasan: ringkasan,
    pembahasan: pembahasan,
    jalannyaRapat: [
      for (final entry in jalannyaRapat)
        RisalahEntry(pembicara: entry.pembicara, pokok: entry.pokok),
    ],
    pihak: pihak,
    keputusan: keputusan,
    tindakLanjut: [
      for (final task in tindakLanjut)
        TindakLanjut(
          tugas: task.tugas,
          penanggungJawab: task.penanggungJawab,
          tenggat: task.tenggat,
        ),
    ],
    poinPenting: poinPenting,
    kopSuratPath: kopSuratPath,
    lampirkanTranskrip: lampirkanTranskrip,
  );

  Map<String, dynamic> toJson() => {
    'template': template.name,
    'instansi': instansi,
    'unit_kerja': unitKerja,
    'nomor': nomor,
    'judul': judul,
    'hari': hari,
    'tanggal': tanggal,
    'waktu': waktu,
    'tempat': tempat,
    'pimpinan': pimpinan,
    'notulis': notulis,
    'peserta': peserta,
    'agenda': agenda,
    'ringkasan': ringkasan,
    'pembahasan': pembahasan,
    'jalannya_rapat': [for (final entry in jalannyaRapat) entry.toJson()],
    'pihak': pihak,
    'keputusan': keputusan,
    'tindak_lanjut': [for (final task in tindakLanjut) task.toJson()],
    'kop_surat_path': kopSuratPath,
    'lampirkan_transkrip': lampirkanTranskrip,
    'sumber_catatan': sumberCatatan,
    'panjang': panjang.name,
    'konteks_dokumen_path': konteksDokumenPath,
    'konteks_dokumen_nama': konteksDokumenNama,
  };

  factory NotulenFormData.fromJson(Map<String, dynamic> json) {
    List<String> strings(Object? raw) =>
        raw is List ? raw.whereType<String>().toList() : const <String>[];
    String text(String key) => json[key] is String ? json[key] as String : '';
    return NotulenFormData(
      // `variant` is what sessions saved before Sprint 7 wrote, when
      // there were only two layouts. Both of its values are still
      // `NotulenTemplate` names, so an old session opens unchanged.
      template:
          NotulenTemplate.values
              .where((v) => v.name == (json['template'] ?? json['variant']))
              .firstOrNull ??
          NotulenTemplate.dinas,
      instansi: text('instansi'),
      unitKerja: text('unit_kerja'),
      nomor: text('nomor'),
      judul: text('judul'),
      hari: text('hari'),
      tanggal: text('tanggal'),
      waktu: text('waktu'),
      tempat: text('tempat'),
      pimpinan: text('pimpinan'),
      notulis: text('notulis'),
      peserta: strings(json['peserta']),
      agenda: strings(json['agenda']),
      ringkasan: text('ringkasan'),
      pembahasan: text('pembahasan'),
      jalannyaRapat: json['jalannya_rapat'] is List
          ? (json['jalannya_rapat'] as List)
                .whereType<Map>()
                .map(NotulenIntervention.fromJson)
                .toList()
          : const [],
      pihak: strings(json['pihak']),
      keputusan: strings(json['keputusan']),
      tindakLanjut: json['tindak_lanjut'] is List
          ? (json['tindak_lanjut'] as List)
                .whereType<Map>()
                .map(NotulenTask.fromJson)
                .toList()
          : const [],
      kopSuratPath: text('kop_surat_path'),
      lampirkanTranskrip: json['lampirkan_transkrip'] == true,
      sumberCatatan: text('sumber_catatan'),
      panjang:
          NotulenLength.values
              .where((v) => v.name == json['panjang'])
              .firstOrNull ??
          NotulenLength.sedang,
      konteksDokumenPath: text('konteks_dokumen_path'),
      konteksDokumenNama: text('konteks_dokumen_nama'),
    );
  }
}

/// One tugas / penanggung jawab / tenggat row, JSON-serialisable.
/// One intervention in a Risalah Rapat: who said what, in order.
///
/// Carries no segment ids: the document shows none, and the form the user
/// edits should not hold fields the document cannot display. Provenance
/// lives in the fact-check report instead.
class NotulenIntervention {
  const NotulenIntervention({this.pembicara = '', this.pokok = ''});

  final String pembicara;
  final String pokok;

  NotulenIntervention copyWith({String? pembicara, String? pokok}) =>
      NotulenIntervention(
        pembicara: pembicara ?? this.pembicara,
        pokok: pokok ?? this.pokok,
      );

  Map<String, dynamic> toJson() => {
    'pembicara': pembicara,
    'pokok': pokok,
  };

  factory NotulenIntervention.fromJson(Map<dynamic, dynamic> json) =>
      NotulenIntervention(
        pembicara: json['pembicara'] is String
            ? json['pembicara'] as String
            : '',
        pokok: json['pokok'] is String ? json['pokok'] as String : '',
      );

  @override
  bool operator ==(Object other) =>
      other is NotulenIntervention &&
      other.pembicara == pembicara &&
      other.pokok == pokok;

  @override
  int get hashCode => Object.hash(pembicara, pokok);
}

class NotulenTask {
  const NotulenTask({
    this.tugas = '',
    this.penanggungJawab = '',
    this.tenggat = '',
  });

  final String tugas;
  final String penanggungJawab;
  final String tenggat;

  NotulenTask copyWith({
    String? tugas,
    String? penanggungJawab,
    String? tenggat,
  }) => NotulenTask(
    tugas: tugas ?? this.tugas,
    penanggungJawab: penanggungJawab ?? this.penanggungJawab,
    tenggat: tenggat ?? this.tenggat,
  );

  Map<String, dynamic> toJson() => {
    'tugas': tugas,
    'penanggung_jawab': penanggungJawab,
    'tenggat': tenggat,
  };

  factory NotulenTask.fromJson(Map<dynamic, dynamic> json) => NotulenTask(
    tugas: json['tugas'] is String ? json['tugas'] as String : '',
    penanggungJawab: json['penanggung_jawab'] is String
        ? json['penanggung_jawab'] as String
        : '',
    tenggat: json['tenggat'] is String ? json['tenggat'] as String : '',
  );
}

/// One session as the library screen sees it: transcript plus sidecar.
class SessionRecord {
  /// Absolute path of the session directory. Doubles as the stable id.
  final String dirPath;
  final String title;
  final String date;
  final List<TranscriptSegment> segments;
  final double durationSeconds;
  final String? audioPath;
  final SessionMeta meta;

  /// Segment count shown on the card. Defaults to `segments.length`, which is
  /// always right for a disk-loaded session; kept overridable so a caller that
  /// seeds the library with a count but only a sample of segments (tests,
  /// previews) still renders the real number.
  final int? seededSegmentsCount;

  const SessionRecord({
    required this.dirPath,
    required this.title,
    required this.date,
    required this.segments,
    required this.durationSeconds,
    required this.meta,
    this.audioPath,
    this.seededSegmentsCount,
  });

  int get segmentsCount => seededSegmentsCount ?? segments.length;

  SessionSummary toSummary() => SessionSummary(
    id: dirPath,
    title: title,
    date: date,
    segmentsCount: segmentsCount,
    segments: segments,
    durationSeconds: durationSeconds,
    audioPath: audioPath,
  );

  SessionRecord copyWith({String? title, SessionMeta? meta}) => SessionRecord(
    dirPath: dirPath,
    title: title ?? this.title,
    date: date,
    segments: segments,
    durationSeconds: durationSeconds,
    audioPath: audioPath,
    meta: meta ?? this.meta,
    seededSegmentsCount: seededSegmentsCount,
  );
}

/// Strips the `YYYYMMDD-` prefix the exporter prepends to session folders, so
/// the library shows "Rapat Tim" rather than "20260930-Rapat Tim".
String titleFromDirName(String dirName) {
  final match = RegExp(r'^\d{8}-(.+)$').firstMatch(dirName);
  return match?.group(1) ?? dirName;
}

/// Reads the sidecar in [dirPath]. Returns [SessionMeta.empty] when it is
/// missing or unreadable — a corrupt sidecar must never hide a transcript.
Future<SessionMeta> readSessionMeta(String dirPath) async {
  try {
    final file = File('$dirPath${Platform.pathSeparator}$kMetaFilename');
    if (!await file.exists()) return SessionMeta.empty;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) return SessionMeta.empty;
    return SessionMeta.fromJson(decoded);
  } catch (_) {
    return SessionMeta.empty;
  }
}

/// Writes the sidecar for [dirPath], creating the directory if needed.
/// Throws on failure so callers can tell the user their edit wasn't saved.
///
/// Atomic: the sidecar holds the only copy of the summary, so a write
/// interrupted halfway used to destroy it outright.
Future<void> writeSessionMeta(String dirPath, SessionMeta meta) async {
  final dir = Directory(dirPath);
  if (!await dir.exists()) await dir.create(recursive: true);
  final file = File('$dirPath${Platform.pathSeparator}$kMetaFilename');
  await writeStringAtomic(
    file,
    const JsonEncoder.withIndent('  ').convert(meta.toJson()),
  );
}

/// Parses the exported transcript JSON (a bare segment array) into segments.
/// Exposed for tests and for the re-transcribe flow.
List<TranscriptSegment> parseTranscriptJson(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! List) return const [];
  return decoded.whereType<Map<String, dynamic>>().map((m) {
    return TranscriptSegment(
      source: m['source'] as String? ?? '',
      speaker: m['speaker'] as String? ?? '',
      text: m['text'] as String? ?? '',
      timestamp: (m['timestamp'] as num?)?.toDouble() ?? 0,
      duration: (m['duration'] as num?)?.toDouble() ?? 0,
      language: m['language'] as String? ?? '',
      confidence: (m['confidence'] as num?)?.toDouble() ?? 1.0,
      isPartial: m['is_partial'] as bool? ?? false,
      lowConfidence: m['low_confidence'] as bool? ?? false,
      avgLogProb: (m['avg_log_prob'] as num?)?.toDouble() ?? 0.0,
      // Absent from every transcript written before Sprint 4b, which is
      // why it degrades to an empty list rather than throwing: the player
      // falls back to seeking by segment.
      words: _parseWords(m['words']),
    );
  }).toList();
}

List<TranscriptWord> _parseWords(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .map(TranscriptWord.fromJson)
      .whereType<TranscriptWord>()
      .toList(growable: false);
}

/// Serialises segments back into the exporter's JSON shape, so an edited or
/// re-transcribed session round-trips through the same file the library reads.
String encodeTranscriptJson(List<TranscriptSegment> segments) {
  return jsonEncode([
    for (final s in segments)
      {
        'source': s.source,
        'speaker': s.speaker,
        'text': s.text,
        'timestamp': s.timestamp,
        'duration': s.duration,
        'language': s.language,
        'confidence': s.confidence,
        'avg_log_prob': s.avgLogProb,
        'is_partial': s.isPartial,
        'low_confidence': s.lowConfidence,
        if (s.words.isNotEmpty) 'words': [for (final w in s.words) w.toJson()],
      },
  ]);
}

/// Every JSON file in a session directory that is not the transcript: the
/// sidecar (which carries the only copy of the summary) and the
/// re-transcribe backup. Picking either as "the transcript" would make a
/// session look empty, or silently restore stale text.
const Set<String> _nonTranscriptJson = {
  kMetaFilename,
  kTranscriptBackupFilename,
};

/// The transcript JSON file inside a session directory, or `null` if absent.
File? transcriptFileIn(Directory sessionDir) {
  try {
    return sessionDir
        .listSync()
        .whereType<File>()
        .where(
          (f) =>
              f.path.endsWith('.json') &&
              !_nonTranscriptJson.contains(f.uri.pathSegments.last),
        )
        .firstOrNull;
  } catch (_) {
    return null;
  }
}

/// The re-transcribe backup for [dirPath], or `null` when there is none.
File? transcriptBackupIn(String dirPath) {
  final file = File(
    '$dirPath${Platform.pathSeparator}$kTranscriptBackupFilename',
  );
  return file.existsSync() ? file : null;
}

/// Copies the current transcript aside before something destructive
/// replaces it. Throws if the backup cannot be written — a "Transkrip
/// Ulang" that silently skipped its backup would be the original bug with
/// extra steps.
Future<void> backupTranscript(
  String dirPath,
  List<TranscriptSegment> segments,
) {
  return writeStringAtomic(
    File('$dirPath${Platform.pathSeparator}$kTranscriptBackupFilename'),
    encodeTranscriptJson(segments),
  );
}

/// Reads back a [backupTranscript] copy. Returns `null` when there is no
/// backup or it cannot be parsed.
Future<List<TranscriptSegment>?> readTranscriptBackup(String dirPath) async {
  final file = transcriptBackupIn(dirPath);
  if (file == null) return null;
  try {
    final segments = parseTranscriptJson(await file.readAsString());
    return segments.isEmpty ? null : segments;
  } catch (_) {
    return null;
  }
}
