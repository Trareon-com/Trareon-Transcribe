// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'error.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TranscribeError {

 String get field0;
/// Create a copy of TranscribeError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TranscribeErrorCopyWith<TranscribeError> get copyWith => _$TranscribeErrorCopyWithImpl<TranscribeError>(this as TranscribeError, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as TranscribeError;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TranscribeError&&(identical(other.field0, _this.field0) || other.field0 == _this.field0));
}


@override
int get hashCode {
  final _this = this as TranscribeError;
  return Object.hash(runtimeType,_this.field0);
}

@override
String toString() {
  final _this = this as TranscribeError;
  return 'TranscribeError(field0: ${_this.field0})';
}


}

/// @nodoc
abstract mixin class $TranscribeErrorCopyWith<$Res>  {
  factory $TranscribeErrorCopyWith(TranscribeError value, $Res Function(TranscribeError) _then) = _$TranscribeErrorCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$TranscribeErrorCopyWithImpl<$Res>
    implements $TranscribeErrorCopyWith<$Res> {
  _$TranscribeErrorCopyWithImpl(this._self, this._then);

  final TranscribeError _self;
  final $Res Function(TranscribeError) _then;

/// Create a copy of TranscribeError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? field0 = null,}) {
  return _then(_self.copyWith(
field0: null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TranscribeError].
extension TranscribeErrorPatterns on TranscribeError {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( TranscribeError_AudioDevice value)?  audioDevice,TResult Function( TranscribeError_AudioDecode value)?  audioDecode,TResult Function( TranscribeError_Model value)?  model,TResult Function( TranscribeError_Transcription value)?  transcription,TResult Function( TranscribeError_Export value)?  export_,TResult Function( TranscribeError_Io value)?  io,TResult Function( TranscribeError_InvalidInput value)?  invalidInput,TResult Function( TranscribeError_SessionNotFound value)?  sessionNotFound,TResult Function( TranscribeError_Summary value)?  summary,required TResult orElse(),}){
final _that = this;
switch (_that) {
case TranscribeError_AudioDevice() when audioDevice != null:
return audioDevice(_that);case TranscribeError_AudioDecode() when audioDecode != null:
return audioDecode(_that);case TranscribeError_Model() when model != null:
return model(_that);case TranscribeError_Transcription() when transcription != null:
return transcription(_that);case TranscribeError_Export() when export_ != null:
return export_(_that);case TranscribeError_Io() when io != null:
return io(_that);case TranscribeError_InvalidInput() when invalidInput != null:
return invalidInput(_that);case TranscribeError_SessionNotFound() when sessionNotFound != null:
return sessionNotFound(_that);case TranscribeError_Summary() when summary != null:
return summary(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( TranscribeError_AudioDevice value)  audioDevice,required TResult Function( TranscribeError_AudioDecode value)  audioDecode,required TResult Function( TranscribeError_Model value)  model,required TResult Function( TranscribeError_Transcription value)  transcription,required TResult Function( TranscribeError_Export value)  export_,required TResult Function( TranscribeError_Io value)  io,required TResult Function( TranscribeError_InvalidInput value)  invalidInput,required TResult Function( TranscribeError_SessionNotFound value)  sessionNotFound,required TResult Function( TranscribeError_Summary value)  summary,}){
final _that = this;
switch (_that) {
case TranscribeError_AudioDevice():
return audioDevice(_that);case TranscribeError_AudioDecode():
return audioDecode(_that);case TranscribeError_Model():
return model(_that);case TranscribeError_Transcription():
return transcription(_that);case TranscribeError_Export():
return export_(_that);case TranscribeError_Io():
return io(_that);case TranscribeError_InvalidInput():
return invalidInput(_that);case TranscribeError_SessionNotFound():
return sessionNotFound(_that);case TranscribeError_Summary():
return summary(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( TranscribeError_AudioDevice value)?  audioDevice,TResult? Function( TranscribeError_AudioDecode value)?  audioDecode,TResult? Function( TranscribeError_Model value)?  model,TResult? Function( TranscribeError_Transcription value)?  transcription,TResult? Function( TranscribeError_Export value)?  export_,TResult? Function( TranscribeError_Io value)?  io,TResult? Function( TranscribeError_InvalidInput value)?  invalidInput,TResult? Function( TranscribeError_SessionNotFound value)?  sessionNotFound,TResult? Function( TranscribeError_Summary value)?  summary,}){
final _that = this;
switch (_that) {
case TranscribeError_AudioDevice() when audioDevice != null:
return audioDevice(_that);case TranscribeError_AudioDecode() when audioDecode != null:
return audioDecode(_that);case TranscribeError_Model() when model != null:
return model(_that);case TranscribeError_Transcription() when transcription != null:
return transcription(_that);case TranscribeError_Export() when export_ != null:
return export_(_that);case TranscribeError_Io() when io != null:
return io(_that);case TranscribeError_InvalidInput() when invalidInput != null:
return invalidInput(_that);case TranscribeError_SessionNotFound() when sessionNotFound != null:
return sessionNotFound(_that);case TranscribeError_Summary() when summary != null:
return summary(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String field0)?  audioDevice,TResult Function( String field0)?  audioDecode,TResult Function( String field0)?  model,TResult Function( String field0)?  transcription,TResult Function( String field0)?  export_,TResult Function( String field0)?  io,TResult Function( String field0)?  invalidInput,TResult Function( String field0)?  sessionNotFound,TResult Function( String field0)?  summary,required TResult orElse(),}) {final _that = this;
switch (_that) {
case TranscribeError_AudioDevice() when audioDevice != null:
return audioDevice(_that.field0);case TranscribeError_AudioDecode() when audioDecode != null:
return audioDecode(_that.field0);case TranscribeError_Model() when model != null:
return model(_that.field0);case TranscribeError_Transcription() when transcription != null:
return transcription(_that.field0);case TranscribeError_Export() when export_ != null:
return export_(_that.field0);case TranscribeError_Io() when io != null:
return io(_that.field0);case TranscribeError_InvalidInput() when invalidInput != null:
return invalidInput(_that.field0);case TranscribeError_SessionNotFound() when sessionNotFound != null:
return sessionNotFound(_that.field0);case TranscribeError_Summary() when summary != null:
return summary(_that.field0);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String field0)  audioDevice,required TResult Function( String field0)  audioDecode,required TResult Function( String field0)  model,required TResult Function( String field0)  transcription,required TResult Function( String field0)  export_,required TResult Function( String field0)  io,required TResult Function( String field0)  invalidInput,required TResult Function( String field0)  sessionNotFound,required TResult Function( String field0)  summary,}) {final _that = this;
switch (_that) {
case TranscribeError_AudioDevice():
return audioDevice(_that.field0);case TranscribeError_AudioDecode():
return audioDecode(_that.field0);case TranscribeError_Model():
return model(_that.field0);case TranscribeError_Transcription():
return transcription(_that.field0);case TranscribeError_Export():
return export_(_that.field0);case TranscribeError_Io():
return io(_that.field0);case TranscribeError_InvalidInput():
return invalidInput(_that.field0);case TranscribeError_SessionNotFound():
return sessionNotFound(_that.field0);case TranscribeError_Summary():
return summary(_that.field0);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String field0)?  audioDevice,TResult? Function( String field0)?  audioDecode,TResult? Function( String field0)?  model,TResult? Function( String field0)?  transcription,TResult? Function( String field0)?  export_,TResult? Function( String field0)?  io,TResult? Function( String field0)?  invalidInput,TResult? Function( String field0)?  sessionNotFound,TResult? Function( String field0)?  summary,}) {final _that = this;
switch (_that) {
case TranscribeError_AudioDevice() when audioDevice != null:
return audioDevice(_that.field0);case TranscribeError_AudioDecode() when audioDecode != null:
return audioDecode(_that.field0);case TranscribeError_Model() when model != null:
return model(_that.field0);case TranscribeError_Transcription() when transcription != null:
return transcription(_that.field0);case TranscribeError_Export() when export_ != null:
return export_(_that.field0);case TranscribeError_Io() when io != null:
return io(_that.field0);case TranscribeError_InvalidInput() when invalidInput != null:
return invalidInput(_that.field0);case TranscribeError_SessionNotFound() when sessionNotFound != null:
return sessionNotFound(_that.field0);case TranscribeError_Summary() when summary != null:
return summary(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class TranscribeError_AudioDevice extends TranscribeError {
  const TranscribeError_AudioDevice(this.field0): super._();
  

@override final  String field0;

/// Create a copy of TranscribeError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TranscribeError_AudioDeviceCopyWith<TranscribeError_AudioDevice> get copyWith => _$TranscribeError_AudioDeviceCopyWithImpl<TranscribeError_AudioDevice>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TranscribeError_AudioDevice&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode {
    return Object.hash(runtimeType,field0);
}

@override
String toString() {
    return 'TranscribeError.audioDevice(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $TranscribeError_AudioDeviceCopyWith<$Res> implements $TranscribeErrorCopyWith<$Res> {
  factory $TranscribeError_AudioDeviceCopyWith(TranscribeError_AudioDevice value, $Res Function(TranscribeError_AudioDevice) _then) = _$TranscribeError_AudioDeviceCopyWithImpl;
@override @useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$TranscribeError_AudioDeviceCopyWithImpl<$Res>
    implements $TranscribeError_AudioDeviceCopyWith<$Res> {
  _$TranscribeError_AudioDeviceCopyWithImpl(this._self, this._then);

  final TranscribeError_AudioDevice _self;
  final $Res Function(TranscribeError_AudioDevice) _then;

/// Create a copy of TranscribeError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(TranscribeError_AudioDevice(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class TranscribeError_AudioDecode extends TranscribeError {
  const TranscribeError_AudioDecode(this.field0): super._();
  

@override final  String field0;

/// Create a copy of TranscribeError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TranscribeError_AudioDecodeCopyWith<TranscribeError_AudioDecode> get copyWith => _$TranscribeError_AudioDecodeCopyWithImpl<TranscribeError_AudioDecode>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TranscribeError_AudioDecode&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode {
    return Object.hash(runtimeType,field0);
}

@override
String toString() {
    return 'TranscribeError.audioDecode(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $TranscribeError_AudioDecodeCopyWith<$Res> implements $TranscribeErrorCopyWith<$Res> {
  factory $TranscribeError_AudioDecodeCopyWith(TranscribeError_AudioDecode value, $Res Function(TranscribeError_AudioDecode) _then) = _$TranscribeError_AudioDecodeCopyWithImpl;
@override @useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$TranscribeError_AudioDecodeCopyWithImpl<$Res>
    implements $TranscribeError_AudioDecodeCopyWith<$Res> {
  _$TranscribeError_AudioDecodeCopyWithImpl(this._self, this._then);

  final TranscribeError_AudioDecode _self;
  final $Res Function(TranscribeError_AudioDecode) _then;

/// Create a copy of TranscribeError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(TranscribeError_AudioDecode(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class TranscribeError_Model extends TranscribeError {
  const TranscribeError_Model(this.field0): super._();
  

@override final  String field0;

/// Create a copy of TranscribeError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TranscribeError_ModelCopyWith<TranscribeError_Model> get copyWith => _$TranscribeError_ModelCopyWithImpl<TranscribeError_Model>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TranscribeError_Model&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode {
    return Object.hash(runtimeType,field0);
}

@override
String toString() {
    return 'TranscribeError.model(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $TranscribeError_ModelCopyWith<$Res> implements $TranscribeErrorCopyWith<$Res> {
  factory $TranscribeError_ModelCopyWith(TranscribeError_Model value, $Res Function(TranscribeError_Model) _then) = _$TranscribeError_ModelCopyWithImpl;
@override @useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$TranscribeError_ModelCopyWithImpl<$Res>
    implements $TranscribeError_ModelCopyWith<$Res> {
  _$TranscribeError_ModelCopyWithImpl(this._self, this._then);

  final TranscribeError_Model _self;
  final $Res Function(TranscribeError_Model) _then;

/// Create a copy of TranscribeError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(TranscribeError_Model(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class TranscribeError_Transcription extends TranscribeError {
  const TranscribeError_Transcription(this.field0): super._();
  

@override final  String field0;

/// Create a copy of TranscribeError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TranscribeError_TranscriptionCopyWith<TranscribeError_Transcription> get copyWith => _$TranscribeError_TranscriptionCopyWithImpl<TranscribeError_Transcription>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TranscribeError_Transcription&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode {
    return Object.hash(runtimeType,field0);
}

@override
String toString() {
    return 'TranscribeError.transcription(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $TranscribeError_TranscriptionCopyWith<$Res> implements $TranscribeErrorCopyWith<$Res> {
  factory $TranscribeError_TranscriptionCopyWith(TranscribeError_Transcription value, $Res Function(TranscribeError_Transcription) _then) = _$TranscribeError_TranscriptionCopyWithImpl;
@override @useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$TranscribeError_TranscriptionCopyWithImpl<$Res>
    implements $TranscribeError_TranscriptionCopyWith<$Res> {
  _$TranscribeError_TranscriptionCopyWithImpl(this._self, this._then);

  final TranscribeError_Transcription _self;
  final $Res Function(TranscribeError_Transcription) _then;

/// Create a copy of TranscribeError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(TranscribeError_Transcription(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class TranscribeError_Export extends TranscribeError {
  const TranscribeError_Export(this.field0): super._();
  

@override final  String field0;

/// Create a copy of TranscribeError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TranscribeError_ExportCopyWith<TranscribeError_Export> get copyWith => _$TranscribeError_ExportCopyWithImpl<TranscribeError_Export>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TranscribeError_Export&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode {
    return Object.hash(runtimeType,field0);
}

@override
String toString() {
    return 'TranscribeError.export_(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $TranscribeError_ExportCopyWith<$Res> implements $TranscribeErrorCopyWith<$Res> {
  factory $TranscribeError_ExportCopyWith(TranscribeError_Export value, $Res Function(TranscribeError_Export) _then) = _$TranscribeError_ExportCopyWithImpl;
@override @useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$TranscribeError_ExportCopyWithImpl<$Res>
    implements $TranscribeError_ExportCopyWith<$Res> {
  _$TranscribeError_ExportCopyWithImpl(this._self, this._then);

  final TranscribeError_Export _self;
  final $Res Function(TranscribeError_Export) _then;

/// Create a copy of TranscribeError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(TranscribeError_Export(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class TranscribeError_Io extends TranscribeError {
  const TranscribeError_Io(this.field0): super._();
  

@override final  String field0;

/// Create a copy of TranscribeError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TranscribeError_IoCopyWith<TranscribeError_Io> get copyWith => _$TranscribeError_IoCopyWithImpl<TranscribeError_Io>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TranscribeError_Io&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode {
    return Object.hash(runtimeType,field0);
}

@override
String toString() {
    return 'TranscribeError.io(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $TranscribeError_IoCopyWith<$Res> implements $TranscribeErrorCopyWith<$Res> {
  factory $TranscribeError_IoCopyWith(TranscribeError_Io value, $Res Function(TranscribeError_Io) _then) = _$TranscribeError_IoCopyWithImpl;
@override @useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$TranscribeError_IoCopyWithImpl<$Res>
    implements $TranscribeError_IoCopyWith<$Res> {
  _$TranscribeError_IoCopyWithImpl(this._self, this._then);

  final TranscribeError_Io _self;
  final $Res Function(TranscribeError_Io) _then;

/// Create a copy of TranscribeError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(TranscribeError_Io(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class TranscribeError_InvalidInput extends TranscribeError {
  const TranscribeError_InvalidInput(this.field0): super._();
  

@override final  String field0;

/// Create a copy of TranscribeError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TranscribeError_InvalidInputCopyWith<TranscribeError_InvalidInput> get copyWith => _$TranscribeError_InvalidInputCopyWithImpl<TranscribeError_InvalidInput>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TranscribeError_InvalidInput&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode {
    return Object.hash(runtimeType,field0);
}

@override
String toString() {
    return 'TranscribeError.invalidInput(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $TranscribeError_InvalidInputCopyWith<$Res> implements $TranscribeErrorCopyWith<$Res> {
  factory $TranscribeError_InvalidInputCopyWith(TranscribeError_InvalidInput value, $Res Function(TranscribeError_InvalidInput) _then) = _$TranscribeError_InvalidInputCopyWithImpl;
@override @useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$TranscribeError_InvalidInputCopyWithImpl<$Res>
    implements $TranscribeError_InvalidInputCopyWith<$Res> {
  _$TranscribeError_InvalidInputCopyWithImpl(this._self, this._then);

  final TranscribeError_InvalidInput _self;
  final $Res Function(TranscribeError_InvalidInput) _then;

/// Create a copy of TranscribeError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(TranscribeError_InvalidInput(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class TranscribeError_SessionNotFound extends TranscribeError {
  const TranscribeError_SessionNotFound(this.field0): super._();
  

@override final  String field0;

/// Create a copy of TranscribeError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TranscribeError_SessionNotFoundCopyWith<TranscribeError_SessionNotFound> get copyWith => _$TranscribeError_SessionNotFoundCopyWithImpl<TranscribeError_SessionNotFound>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TranscribeError_SessionNotFound&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode {
    return Object.hash(runtimeType,field0);
}

@override
String toString() {
    return 'TranscribeError.sessionNotFound(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $TranscribeError_SessionNotFoundCopyWith<$Res> implements $TranscribeErrorCopyWith<$Res> {
  factory $TranscribeError_SessionNotFoundCopyWith(TranscribeError_SessionNotFound value, $Res Function(TranscribeError_SessionNotFound) _then) = _$TranscribeError_SessionNotFoundCopyWithImpl;
@override @useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$TranscribeError_SessionNotFoundCopyWithImpl<$Res>
    implements $TranscribeError_SessionNotFoundCopyWith<$Res> {
  _$TranscribeError_SessionNotFoundCopyWithImpl(this._self, this._then);

  final TranscribeError_SessionNotFound _self;
  final $Res Function(TranscribeError_SessionNotFound) _then;

/// Create a copy of TranscribeError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(TranscribeError_SessionNotFound(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class TranscribeError_Summary extends TranscribeError {
  const TranscribeError_Summary(this.field0): super._();
  

@override final  String field0;

/// Create a copy of TranscribeError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TranscribeError_SummaryCopyWith<TranscribeError_Summary> get copyWith => _$TranscribeError_SummaryCopyWithImpl<TranscribeError_Summary>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TranscribeError_Summary&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode {
    return Object.hash(runtimeType,field0);
}

@override
String toString() {
    return 'TranscribeError.summary(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $TranscribeError_SummaryCopyWith<$Res> implements $TranscribeErrorCopyWith<$Res> {
  factory $TranscribeError_SummaryCopyWith(TranscribeError_Summary value, $Res Function(TranscribeError_Summary) _then) = _$TranscribeError_SummaryCopyWithImpl;
@override @useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$TranscribeError_SummaryCopyWithImpl<$Res>
    implements $TranscribeError_SummaryCopyWith<$Res> {
  _$TranscribeError_SummaryCopyWithImpl(this._self, this._then);

  final TranscribeError_Summary _self;
  final $Res Function(TranscribeError_Summary) _then;

/// Create a copy of TranscribeError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(TranscribeError_Summary(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
