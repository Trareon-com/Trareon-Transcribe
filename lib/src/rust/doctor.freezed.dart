// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'doctor.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CheckStatus {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CheckStatus);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'CheckStatus()';
}


}

/// @nodoc
class $CheckStatusCopyWith<$Res>  {
$CheckStatusCopyWith(CheckStatus _, $Res Function(CheckStatus) __);
}


/// Adds pattern-matching-related methods to [CheckStatus].
extension CheckStatusPatterns on CheckStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( CheckStatus_Ok value)?  ok,TResult Function( CheckStatus_Warn value)?  warn,TResult Function( CheckStatus_Fail value)?  fail,required TResult orElse(),}){
final _that = this;
switch (_that) {
case CheckStatus_Ok() when ok != null:
return ok(_that);case CheckStatus_Warn() when warn != null:
return warn(_that);case CheckStatus_Fail() when fail != null:
return fail(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( CheckStatus_Ok value)  ok,required TResult Function( CheckStatus_Warn value)  warn,required TResult Function( CheckStatus_Fail value)  fail,}){
final _that = this;
switch (_that) {
case CheckStatus_Ok():
return ok(_that);case CheckStatus_Warn():
return warn(_that);case CheckStatus_Fail():
return fail(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( CheckStatus_Ok value)?  ok,TResult? Function( CheckStatus_Warn value)?  warn,TResult? Function( CheckStatus_Fail value)?  fail,}){
final _that = this;
switch (_that) {
case CheckStatus_Ok() when ok != null:
return ok(_that);case CheckStatus_Warn() when warn != null:
return warn(_that);case CheckStatus_Fail() when fail != null:
return fail(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  ok,TResult Function( String field0)?  warn,TResult Function( String field0)?  fail,required TResult orElse(),}) {final _that = this;
switch (_that) {
case CheckStatus_Ok() when ok != null:
return ok();case CheckStatus_Warn() when warn != null:
return warn(_that.field0);case CheckStatus_Fail() when fail != null:
return fail(_that.field0);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  ok,required TResult Function( String field0)  warn,required TResult Function( String field0)  fail,}) {final _that = this;
switch (_that) {
case CheckStatus_Ok():
return ok();case CheckStatus_Warn():
return warn(_that.field0);case CheckStatus_Fail():
return fail(_that.field0);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  ok,TResult? Function( String field0)?  warn,TResult? Function( String field0)?  fail,}) {final _that = this;
switch (_that) {
case CheckStatus_Ok() when ok != null:
return ok();case CheckStatus_Warn() when warn != null:
return warn(_that.field0);case CheckStatus_Fail() when fail != null:
return fail(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class CheckStatus_Ok extends CheckStatus {
  const CheckStatus_Ok(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CheckStatus_Ok);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'CheckStatus.ok()';
}


}




/// @nodoc


class CheckStatus_Warn extends CheckStatus {
  const CheckStatus_Warn(this.field0): super._();
  

 final  String field0;

/// Create a copy of CheckStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CheckStatus_WarnCopyWith<CheckStatus_Warn> get copyWith => _$CheckStatus_WarnCopyWithImpl<CheckStatus_Warn>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CheckStatus_Warn&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode {
    return Object.hash(runtimeType,field0);
}

@override
String toString() {
    return 'CheckStatus.warn(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $CheckStatus_WarnCopyWith<$Res> implements $CheckStatusCopyWith<$Res> {
  factory $CheckStatus_WarnCopyWith(CheckStatus_Warn value, $Res Function(CheckStatus_Warn) _then) = _$CheckStatus_WarnCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$CheckStatus_WarnCopyWithImpl<$Res>
    implements $CheckStatus_WarnCopyWith<$Res> {
  _$CheckStatus_WarnCopyWithImpl(this._self, this._then);

  final CheckStatus_Warn _self;
  final $Res Function(CheckStatus_Warn) _then;

/// Create a copy of CheckStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(CheckStatus_Warn(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class CheckStatus_Fail extends CheckStatus {
  const CheckStatus_Fail(this.field0): super._();
  

 final  String field0;

/// Create a copy of CheckStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CheckStatus_FailCopyWith<CheckStatus_Fail> get copyWith => _$CheckStatus_FailCopyWithImpl<CheckStatus_Fail>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CheckStatus_Fail&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode {
    return Object.hash(runtimeType,field0);
}

@override
String toString() {
    return 'CheckStatus.fail(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $CheckStatus_FailCopyWith<$Res> implements $CheckStatusCopyWith<$Res> {
  factory $CheckStatus_FailCopyWith(CheckStatus_Fail value, $Res Function(CheckStatus_Fail) _then) = _$CheckStatus_FailCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$CheckStatus_FailCopyWithImpl<$Res>
    implements $CheckStatus_FailCopyWith<$Res> {
  _$CheckStatus_FailCopyWithImpl(this._self, this._then);

  final CheckStatus_Fail _self;
  final $Res Function(CheckStatus_Fail) _then;

/// Create a copy of CheckStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(CheckStatus_Fail(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
