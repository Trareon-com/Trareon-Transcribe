// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SessionEvent {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SessionEvent()';
}


}

/// @nodoc
class $SessionEventCopyWith<$Res>  {
$SessionEventCopyWith(SessionEvent _, $Res Function(SessionEvent) __);
}


/// Adds pattern-matching-related methods to [SessionEvent].
extension SessionEventPatterns on SessionEvent {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( SessionEvent_Transcript value)?  transcript,TResult Function( SessionEvent_Vu value)?  vu,TResult Function( SessionEvent_Tentative value)?  tentative,TResult Function( SessionEvent_Notice value)?  notice,required TResult orElse(),}){
final _that = this;
switch (_that) {
case SessionEvent_Transcript() when transcript != null:
return transcript(_that);case SessionEvent_Vu() when vu != null:
return vu(_that);case SessionEvent_Tentative() when tentative != null:
return tentative(_that);case SessionEvent_Notice() when notice != null:
return notice(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( SessionEvent_Transcript value)  transcript,required TResult Function( SessionEvent_Vu value)  vu,required TResult Function( SessionEvent_Tentative value)  tentative,required TResult Function( SessionEvent_Notice value)  notice,}){
final _that = this;
switch (_that) {
case SessionEvent_Transcript():
return transcript(_that);case SessionEvent_Vu():
return vu(_that);case SessionEvent_Tentative():
return tentative(_that);case SessionEvent_Notice():
return notice(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( SessionEvent_Transcript value)?  transcript,TResult? Function( SessionEvent_Vu value)?  vu,TResult? Function( SessionEvent_Tentative value)?  tentative,TResult? Function( SessionEvent_Notice value)?  notice,}){
final _that = this;
switch (_that) {
case SessionEvent_Transcript() when transcript != null:
return transcript(_that);case SessionEvent_Vu() when vu != null:
return vu(_that);case SessionEvent_Tentative() when tentative != null:
return tentative(_that);case SessionEvent_Notice() when notice != null:
return notice(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( Segment field0)?  transcript,TResult Function( String source,  double level)?  vu,TResult Function( String source,  String text)?  tentative,TResult Function( NoticeLevel level,  String source,  String message)?  notice,required TResult orElse(),}) {final _that = this;
switch (_that) {
case SessionEvent_Transcript() when transcript != null:
return transcript(_that.field0);case SessionEvent_Vu() when vu != null:
return vu(_that.source,_that.level);case SessionEvent_Tentative() when tentative != null:
return tentative(_that.source,_that.text);case SessionEvent_Notice() when notice != null:
return notice(_that.level,_that.source,_that.message);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( Segment field0)  transcript,required TResult Function( String source,  double level)  vu,required TResult Function( String source,  String text)  tentative,required TResult Function( NoticeLevel level,  String source,  String message)  notice,}) {final _that = this;
switch (_that) {
case SessionEvent_Transcript():
return transcript(_that.field0);case SessionEvent_Vu():
return vu(_that.source,_that.level);case SessionEvent_Tentative():
return tentative(_that.source,_that.text);case SessionEvent_Notice():
return notice(_that.level,_that.source,_that.message);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( Segment field0)?  transcript,TResult? Function( String source,  double level)?  vu,TResult? Function( String source,  String text)?  tentative,TResult? Function( NoticeLevel level,  String source,  String message)?  notice,}) {final _that = this;
switch (_that) {
case SessionEvent_Transcript() when transcript != null:
return transcript(_that.field0);case SessionEvent_Vu() when vu != null:
return vu(_that.source,_that.level);case SessionEvent_Tentative() when tentative != null:
return tentative(_that.source,_that.text);case SessionEvent_Notice() when notice != null:
return notice(_that.level,_that.source,_that.message);case _:
  return null;

}
}

}

/// @nodoc


class SessionEvent_Transcript extends SessionEvent {
  const SessionEvent_Transcript(this.field0): super._();
  

 final  Segment field0;

/// Create a copy of SessionEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionEvent_TranscriptCopyWith<SessionEvent_Transcript> get copyWith => _$SessionEvent_TranscriptCopyWithImpl<SessionEvent_Transcript>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionEvent_Transcript&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode {
    return Object.hash(runtimeType,field0);
}

@override
String toString() {
    return 'SessionEvent.transcript(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $SessionEvent_TranscriptCopyWith<$Res> implements $SessionEventCopyWith<$Res> {
  factory $SessionEvent_TranscriptCopyWith(SessionEvent_Transcript value, $Res Function(SessionEvent_Transcript) _then) = _$SessionEvent_TranscriptCopyWithImpl;
@useResult
$Res call({
 Segment field0
});




}
/// @nodoc
class _$SessionEvent_TranscriptCopyWithImpl<$Res>
    implements $SessionEvent_TranscriptCopyWith<$Res> {
  _$SessionEvent_TranscriptCopyWithImpl(this._self, this._then);

  final SessionEvent_Transcript _self;
  final $Res Function(SessionEvent_Transcript) _then;

/// Create a copy of SessionEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(SessionEvent_Transcript(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as Segment,
  ));
}


}

/// @nodoc


class SessionEvent_Vu extends SessionEvent {
  const SessionEvent_Vu({required this.source, required this.level}): super._();
  

 final  String source;
 final  double level;

/// Create a copy of SessionEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionEvent_VuCopyWith<SessionEvent_Vu> get copyWith => _$SessionEvent_VuCopyWithImpl<SessionEvent_Vu>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionEvent_Vu&&(identical(other.source, source) || other.source == source)&&(identical(other.level, level) || other.level == level));
}


@override
int get hashCode {
    return Object.hash(runtimeType,source,level);
}

@override
String toString() {
    return 'SessionEvent.vu(source: $source, level: $level)';
}


}

/// @nodoc
abstract mixin class $SessionEvent_VuCopyWith<$Res> implements $SessionEventCopyWith<$Res> {
  factory $SessionEvent_VuCopyWith(SessionEvent_Vu value, $Res Function(SessionEvent_Vu) _then) = _$SessionEvent_VuCopyWithImpl;
@useResult
$Res call({
 String source, double level
});




}
/// @nodoc
class _$SessionEvent_VuCopyWithImpl<$Res>
    implements $SessionEvent_VuCopyWith<$Res> {
  _$SessionEvent_VuCopyWithImpl(this._self, this._then);

  final SessionEvent_Vu _self;
  final $Res Function(SessionEvent_Vu) _then;

/// Create a copy of SessionEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? source = null,Object? level = null,}) {
  return _then(SessionEvent_Vu(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class SessionEvent_Tentative extends SessionEvent {
  const SessionEvent_Tentative({required this.source, required this.text}): super._();
  

 final  String source;
 final  String text;

/// Create a copy of SessionEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionEvent_TentativeCopyWith<SessionEvent_Tentative> get copyWith => _$SessionEvent_TentativeCopyWithImpl<SessionEvent_Tentative>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionEvent_Tentative&&(identical(other.source, source) || other.source == source)&&(identical(other.text, text) || other.text == text));
}


@override
int get hashCode {
    return Object.hash(runtimeType,source,text);
}

@override
String toString() {
    return 'SessionEvent.tentative(source: $source, text: $text)';
}


}

/// @nodoc
abstract mixin class $SessionEvent_TentativeCopyWith<$Res> implements $SessionEventCopyWith<$Res> {
  factory $SessionEvent_TentativeCopyWith(SessionEvent_Tentative value, $Res Function(SessionEvent_Tentative) _then) = _$SessionEvent_TentativeCopyWithImpl;
@useResult
$Res call({
 String source, String text
});




}
/// @nodoc
class _$SessionEvent_TentativeCopyWithImpl<$Res>
    implements $SessionEvent_TentativeCopyWith<$Res> {
  _$SessionEvent_TentativeCopyWithImpl(this._self, this._then);

  final SessionEvent_Tentative _self;
  final $Res Function(SessionEvent_Tentative) _then;

/// Create a copy of SessionEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? source = null,Object? text = null,}) {
  return _then(SessionEvent_Tentative(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class SessionEvent_Notice extends SessionEvent {
  const SessionEvent_Notice({required this.level, required this.source, required this.message}): super._();
  

 final  NoticeLevel level;
 final  String source;
 final  String message;

/// Create a copy of SessionEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionEvent_NoticeCopyWith<SessionEvent_Notice> get copyWith => _$SessionEvent_NoticeCopyWithImpl<SessionEvent_Notice>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionEvent_Notice&&(identical(other.level, level) || other.level == level)&&(identical(other.source, source) || other.source == source)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode {
    return Object.hash(runtimeType,level,source,message);
}

@override
String toString() {
    return 'SessionEvent.notice(level: $level, source: $source, message: $message)';
}


}

/// @nodoc
abstract mixin class $SessionEvent_NoticeCopyWith<$Res> implements $SessionEventCopyWith<$Res> {
  factory $SessionEvent_NoticeCopyWith(SessionEvent_Notice value, $Res Function(SessionEvent_Notice) _then) = _$SessionEvent_NoticeCopyWithImpl;
@useResult
$Res call({
 NoticeLevel level, String source, String message
});




}
/// @nodoc
class _$SessionEvent_NoticeCopyWithImpl<$Res>
    implements $SessionEvent_NoticeCopyWith<$Res> {
  _$SessionEvent_NoticeCopyWithImpl(this._self, this._then);

  final SessionEvent_Notice _self;
  final $Res Function(SessionEvent_Notice) _then;

/// Create a copy of SessionEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? level = null,Object? source = null,Object? message = null,}) {
  return _then(SessionEvent_Notice(
level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as NoticeLevel,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
