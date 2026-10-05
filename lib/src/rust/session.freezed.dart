// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$SessionEvent {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(Segment field0) transcript,
    required TResult Function(String source, double level) vu,
    required TResult Function(String source, String text) tentative,
    required TResult Function(NoticeLevel level, String source, String message)
    notice,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(Segment field0)? transcript,
    TResult? Function(String source, double level)? vu,
    TResult? Function(String source, String text)? tentative,
    TResult? Function(NoticeLevel level, String source, String message)? notice,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(Segment field0)? transcript,
    TResult Function(String source, double level)? vu,
    TResult Function(String source, String text)? tentative,
    TResult Function(NoticeLevel level, String source, String message)? notice,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SessionEvent_Transcript value) transcript,
    required TResult Function(SessionEvent_Vu value) vu,
    required TResult Function(SessionEvent_Tentative value) tentative,
    required TResult Function(SessionEvent_Notice value) notice,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SessionEvent_Transcript value)? transcript,
    TResult? Function(SessionEvent_Vu value)? vu,
    TResult? Function(SessionEvent_Tentative value)? tentative,
    TResult? Function(SessionEvent_Notice value)? notice,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SessionEvent_Transcript value)? transcript,
    TResult Function(SessionEvent_Vu value)? vu,
    TResult Function(SessionEvent_Tentative value)? tentative,
    TResult Function(SessionEvent_Notice value)? notice,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SessionEventCopyWith<$Res> {
  factory $SessionEventCopyWith(
    SessionEvent value,
    $Res Function(SessionEvent) then,
  ) = _$SessionEventCopyWithImpl<$Res, SessionEvent>;
}

/// @nodoc
class _$SessionEventCopyWithImpl<$Res, $Val extends SessionEvent>
    implements $SessionEventCopyWith<$Res> {
  _$SessionEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$SessionEvent_TranscriptImplCopyWith<$Res> {
  factory _$$SessionEvent_TranscriptImplCopyWith(
    _$SessionEvent_TranscriptImpl value,
    $Res Function(_$SessionEvent_TranscriptImpl) then,
  ) = __$$SessionEvent_TranscriptImplCopyWithImpl<$Res>;
  @useResult
  $Res call({Segment field0});
}

/// @nodoc
class __$$SessionEvent_TranscriptImplCopyWithImpl<$Res>
    extends _$SessionEventCopyWithImpl<$Res, _$SessionEvent_TranscriptImpl>
    implements _$$SessionEvent_TranscriptImplCopyWith<$Res> {
  __$$SessionEvent_TranscriptImplCopyWithImpl(
    _$SessionEvent_TranscriptImpl _value,
    $Res Function(_$SessionEvent_TranscriptImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$SessionEvent_TranscriptImpl(
        null == field0
            ? _value.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as Segment,
      ),
    );
  }
}

/// @nodoc

class _$SessionEvent_TranscriptImpl extends SessionEvent_Transcript {
  const _$SessionEvent_TranscriptImpl(this.field0) : super._();

  @override
  final Segment field0;

  @override
  String toString() {
    return 'SessionEvent.transcript(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SessionEvent_TranscriptImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SessionEvent_TranscriptImplCopyWith<_$SessionEvent_TranscriptImpl>
  get copyWith =>
      __$$SessionEvent_TranscriptImplCopyWithImpl<
        _$SessionEvent_TranscriptImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(Segment field0) transcript,
    required TResult Function(String source, double level) vu,
    required TResult Function(String source, String text) tentative,
    required TResult Function(NoticeLevel level, String source, String message)
    notice,
  }) {
    return transcript(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(Segment field0)? transcript,
    TResult? Function(String source, double level)? vu,
    TResult? Function(String source, String text)? tentative,
    TResult? Function(NoticeLevel level, String source, String message)? notice,
  }) {
    return transcript?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(Segment field0)? transcript,
    TResult Function(String source, double level)? vu,
    TResult Function(String source, String text)? tentative,
    TResult Function(NoticeLevel level, String source, String message)? notice,
    required TResult orElse(),
  }) {
    if (transcript != null) {
      return transcript(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SessionEvent_Transcript value) transcript,
    required TResult Function(SessionEvent_Vu value) vu,
    required TResult Function(SessionEvent_Tentative value) tentative,
    required TResult Function(SessionEvent_Notice value) notice,
  }) {
    return transcript(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SessionEvent_Transcript value)? transcript,
    TResult? Function(SessionEvent_Vu value)? vu,
    TResult? Function(SessionEvent_Tentative value)? tentative,
    TResult? Function(SessionEvent_Notice value)? notice,
  }) {
    return transcript?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SessionEvent_Transcript value)? transcript,
    TResult Function(SessionEvent_Vu value)? vu,
    TResult Function(SessionEvent_Tentative value)? tentative,
    TResult Function(SessionEvent_Notice value)? notice,
    required TResult orElse(),
  }) {
    if (transcript != null) {
      return transcript(this);
    }
    return orElse();
  }
}

abstract class SessionEvent_Transcript extends SessionEvent {
  const factory SessionEvent_Transcript(final Segment field0) =
      _$SessionEvent_TranscriptImpl;
  const SessionEvent_Transcript._() : super._();

  Segment get field0;

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SessionEvent_TranscriptImplCopyWith<_$SessionEvent_TranscriptImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$SessionEvent_VuImplCopyWith<$Res> {
  factory _$$SessionEvent_VuImplCopyWith(
    _$SessionEvent_VuImpl value,
    $Res Function(_$SessionEvent_VuImpl) then,
  ) = __$$SessionEvent_VuImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String source, double level});
}

/// @nodoc
class __$$SessionEvent_VuImplCopyWithImpl<$Res>
    extends _$SessionEventCopyWithImpl<$Res, _$SessionEvent_VuImpl>
    implements _$$SessionEvent_VuImplCopyWith<$Res> {
  __$$SessionEvent_VuImplCopyWithImpl(
    _$SessionEvent_VuImpl _value,
    $Res Function(_$SessionEvent_VuImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? source = null, Object? level = null}) {
    return _then(
      _$SessionEvent_VuImpl(
        source: null == source
            ? _value.source
            : source // ignore: cast_nullable_to_non_nullable
                  as String,
        level: null == level
            ? _value.level
            : level // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// @nodoc

class _$SessionEvent_VuImpl extends SessionEvent_Vu {
  const _$SessionEvent_VuImpl({required this.source, required this.level})
    : super._();

  @override
  final String source;
  @override
  final double level;

  @override
  String toString() {
    return 'SessionEvent.vu(source: $source, level: $level)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SessionEvent_VuImpl &&
            (identical(other.source, source) || other.source == source) &&
            (identical(other.level, level) || other.level == level));
  }

  @override
  int get hashCode => Object.hash(runtimeType, source, level);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SessionEvent_VuImplCopyWith<_$SessionEvent_VuImpl> get copyWith =>
      __$$SessionEvent_VuImplCopyWithImpl<_$SessionEvent_VuImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(Segment field0) transcript,
    required TResult Function(String source, double level) vu,
    required TResult Function(String source, String text) tentative,
    required TResult Function(NoticeLevel level, String source, String message)
    notice,
  }) {
    return vu(source, level);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(Segment field0)? transcript,
    TResult? Function(String source, double level)? vu,
    TResult? Function(String source, String text)? tentative,
    TResult? Function(NoticeLevel level, String source, String message)? notice,
  }) {
    return vu?.call(source, level);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(Segment field0)? transcript,
    TResult Function(String source, double level)? vu,
    TResult Function(String source, String text)? tentative,
    TResult Function(NoticeLevel level, String source, String message)? notice,
    required TResult orElse(),
  }) {
    if (vu != null) {
      return vu(source, level);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SessionEvent_Transcript value) transcript,
    required TResult Function(SessionEvent_Vu value) vu,
    required TResult Function(SessionEvent_Tentative value) tentative,
    required TResult Function(SessionEvent_Notice value) notice,
  }) {
    return vu(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SessionEvent_Transcript value)? transcript,
    TResult? Function(SessionEvent_Vu value)? vu,
    TResult? Function(SessionEvent_Tentative value)? tentative,
    TResult? Function(SessionEvent_Notice value)? notice,
  }) {
    return vu?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SessionEvent_Transcript value)? transcript,
    TResult Function(SessionEvent_Vu value)? vu,
    TResult Function(SessionEvent_Tentative value)? tentative,
    TResult Function(SessionEvent_Notice value)? notice,
    required TResult orElse(),
  }) {
    if (vu != null) {
      return vu(this);
    }
    return orElse();
  }
}

abstract class SessionEvent_Vu extends SessionEvent {
  const factory SessionEvent_Vu({
    required final String source,
    required final double level,
  }) = _$SessionEvent_VuImpl;
  const SessionEvent_Vu._() : super._();

  String get source;
  double get level;

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SessionEvent_VuImplCopyWith<_$SessionEvent_VuImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$SessionEvent_TentativeImplCopyWith<$Res> {
  factory _$$SessionEvent_TentativeImplCopyWith(
    _$SessionEvent_TentativeImpl value,
    $Res Function(_$SessionEvent_TentativeImpl) then,
  ) = __$$SessionEvent_TentativeImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String source, String text});
}

/// @nodoc
class __$$SessionEvent_TentativeImplCopyWithImpl<$Res>
    extends _$SessionEventCopyWithImpl<$Res, _$SessionEvent_TentativeImpl>
    implements _$$SessionEvent_TentativeImplCopyWith<$Res> {
  __$$SessionEvent_TentativeImplCopyWithImpl(
    _$SessionEvent_TentativeImpl _value,
    $Res Function(_$SessionEvent_TentativeImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? source = null, Object? text = null}) {
    return _then(
      _$SessionEvent_TentativeImpl(
        source: null == source
            ? _value.source
            : source // ignore: cast_nullable_to_non_nullable
                  as String,
        text: null == text
            ? _value.text
            : text // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$SessionEvent_TentativeImpl extends SessionEvent_Tentative {
  const _$SessionEvent_TentativeImpl({required this.source, required this.text})
    : super._();

  @override
  final String source;
  @override
  final String text;

  @override
  String toString() {
    return 'SessionEvent.tentative(source: $source, text: $text)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SessionEvent_TentativeImpl &&
            (identical(other.source, source) || other.source == source) &&
            (identical(other.text, text) || other.text == text));
  }

  @override
  int get hashCode => Object.hash(runtimeType, source, text);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SessionEvent_TentativeImplCopyWith<_$SessionEvent_TentativeImpl>
  get copyWith =>
      __$$SessionEvent_TentativeImplCopyWithImpl<_$SessionEvent_TentativeImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(Segment field0) transcript,
    required TResult Function(String source, double level) vu,
    required TResult Function(String source, String text) tentative,
    required TResult Function(NoticeLevel level, String source, String message)
    notice,
  }) {
    return tentative(source, text);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(Segment field0)? transcript,
    TResult? Function(String source, double level)? vu,
    TResult? Function(String source, String text)? tentative,
    TResult? Function(NoticeLevel level, String source, String message)? notice,
  }) {
    return tentative?.call(source, text);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(Segment field0)? transcript,
    TResult Function(String source, double level)? vu,
    TResult Function(String source, String text)? tentative,
    TResult Function(NoticeLevel level, String source, String message)? notice,
    required TResult orElse(),
  }) {
    if (tentative != null) {
      return tentative(source, text);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SessionEvent_Transcript value) transcript,
    required TResult Function(SessionEvent_Vu value) vu,
    required TResult Function(SessionEvent_Tentative value) tentative,
    required TResult Function(SessionEvent_Notice value) notice,
  }) {
    return tentative(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SessionEvent_Transcript value)? transcript,
    TResult? Function(SessionEvent_Vu value)? vu,
    TResult? Function(SessionEvent_Tentative value)? tentative,
    TResult? Function(SessionEvent_Notice value)? notice,
  }) {
    return tentative?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SessionEvent_Transcript value)? transcript,
    TResult Function(SessionEvent_Vu value)? vu,
    TResult Function(SessionEvent_Tentative value)? tentative,
    TResult Function(SessionEvent_Notice value)? notice,
    required TResult orElse(),
  }) {
    if (tentative != null) {
      return tentative(this);
    }
    return orElse();
  }
}

abstract class SessionEvent_Tentative extends SessionEvent {
  const factory SessionEvent_Tentative({
    required final String source,
    required final String text,
  }) = _$SessionEvent_TentativeImpl;
  const SessionEvent_Tentative._() : super._();

  String get source;
  String get text;

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SessionEvent_TentativeImplCopyWith<_$SessionEvent_TentativeImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$SessionEvent_NoticeImplCopyWith<$Res> {
  factory _$$SessionEvent_NoticeImplCopyWith(
    _$SessionEvent_NoticeImpl value,
    $Res Function(_$SessionEvent_NoticeImpl) then,
  ) = __$$SessionEvent_NoticeImplCopyWithImpl<$Res>;
  @useResult
  $Res call({NoticeLevel level, String source, String message});
}

/// @nodoc
class __$$SessionEvent_NoticeImplCopyWithImpl<$Res>
    extends _$SessionEventCopyWithImpl<$Res, _$SessionEvent_NoticeImpl>
    implements _$$SessionEvent_NoticeImplCopyWith<$Res> {
  __$$SessionEvent_NoticeImplCopyWithImpl(
    _$SessionEvent_NoticeImpl _value,
    $Res Function(_$SessionEvent_NoticeImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? level = null,
    Object? source = null,
    Object? message = null,
  }) {
    return _then(
      _$SessionEvent_NoticeImpl(
        level: null == level
            ? _value.level
            : level // ignore: cast_nullable_to_non_nullable
                  as NoticeLevel,
        source: null == source
            ? _value.source
            : source // ignore: cast_nullable_to_non_nullable
                  as String,
        message: null == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$SessionEvent_NoticeImpl extends SessionEvent_Notice {
  const _$SessionEvent_NoticeImpl({
    required this.level,
    required this.source,
    required this.message,
  }) : super._();

  @override
  final NoticeLevel level;
  @override
  final String source;
  @override
  final String message;

  @override
  String toString() {
    return 'SessionEvent.notice(level: $level, source: $source, message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SessionEvent_NoticeImpl &&
            (identical(other.level, level) || other.level == level) &&
            (identical(other.source, source) || other.source == source) &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, level, source, message);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SessionEvent_NoticeImplCopyWith<_$SessionEvent_NoticeImpl> get copyWith =>
      __$$SessionEvent_NoticeImplCopyWithImpl<_$SessionEvent_NoticeImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(Segment field0) transcript,
    required TResult Function(String source, double level) vu,
    required TResult Function(String source, String text) tentative,
    required TResult Function(NoticeLevel level, String source, String message)
    notice,
  }) {
    return notice(level, source, message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(Segment field0)? transcript,
    TResult? Function(String source, double level)? vu,
    TResult? Function(String source, String text)? tentative,
    TResult? Function(NoticeLevel level, String source, String message)? notice,
  }) {
    return notice?.call(level, source, message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(Segment field0)? transcript,
    TResult Function(String source, double level)? vu,
    TResult Function(String source, String text)? tentative,
    TResult Function(NoticeLevel level, String source, String message)? notice,
    required TResult orElse(),
  }) {
    if (notice != null) {
      return notice(level, source, message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SessionEvent_Transcript value) transcript,
    required TResult Function(SessionEvent_Vu value) vu,
    required TResult Function(SessionEvent_Tentative value) tentative,
    required TResult Function(SessionEvent_Notice value) notice,
  }) {
    return notice(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SessionEvent_Transcript value)? transcript,
    TResult? Function(SessionEvent_Vu value)? vu,
    TResult? Function(SessionEvent_Tentative value)? tentative,
    TResult? Function(SessionEvent_Notice value)? notice,
  }) {
    return notice?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SessionEvent_Transcript value)? transcript,
    TResult Function(SessionEvent_Vu value)? vu,
    TResult Function(SessionEvent_Tentative value)? tentative,
    TResult Function(SessionEvent_Notice value)? notice,
    required TResult orElse(),
  }) {
    if (notice != null) {
      return notice(this);
    }
    return orElse();
  }
}

abstract class SessionEvent_Notice extends SessionEvent {
  const factory SessionEvent_Notice({
    required final NoticeLevel level,
    required final String source,
    required final String message,
  }) = _$SessionEvent_NoticeImpl;
  const SessionEvent_Notice._() : super._();

  NoticeLevel get level;
  String get source;
  String get message;

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SessionEvent_NoticeImplCopyWith<_$SessionEvent_NoticeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
