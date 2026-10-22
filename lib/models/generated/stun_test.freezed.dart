// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../stun_test.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$StunTestState {

 StunTestPhase get phase; double get progress; String get server; String get address; bool get direct; SpeedTestOutbound? get outbound;@JsonKey(name: 'nat-type') NatType get natType; String get mapping; String get filtering; bool get public;@JsonKey(name: 'rfc5780') bool get supported;@JsonKey(name: 'external-ip') String get externalIp;@JsonKey(name: 'external-port') int get externalPort;@JsonKey(name: 'local-ip') String get localIp;@JsonKey(name: 'local-port') int get localPort;@JsonKey(name: 'port-preserved') int get portPreserved;@JsonKey(name: 'other-address') String get otherAddress; String get software; double get latency; double get jitter;@JsonKey(name: 'packet-loss') double get packetLoss; String get error;
/// Create a copy of StunTestState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StunTestStateCopyWith<StunTestState> get copyWith => _$StunTestStateCopyWithImpl<StunTestState>(this as StunTestState, _$identity);

  /// Serializes this StunTestState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as StunTestState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StunTestState&&(identical(other.phase, _this.phase) || other.phase == _this.phase)&&(identical(other.progress, _this.progress) || other.progress == _this.progress)&&(identical(other.server, _this.server) || other.server == _this.server)&&(identical(other.address, _this.address) || other.address == _this.address)&&(identical(other.direct, _this.direct) || other.direct == _this.direct)&&(identical(other.outbound, _this.outbound) || other.outbound == _this.outbound)&&(identical(other.natType, _this.natType) || other.natType == _this.natType)&&(identical(other.mapping, _this.mapping) || other.mapping == _this.mapping)&&(identical(other.filtering, _this.filtering) || other.filtering == _this.filtering)&&(identical(other.public, _this.public) || other.public == _this.public)&&(identical(other.supported, _this.supported) || other.supported == _this.supported)&&(identical(other.externalIp, _this.externalIp) || other.externalIp == _this.externalIp)&&(identical(other.externalPort, _this.externalPort) || other.externalPort == _this.externalPort)&&(identical(other.localIp, _this.localIp) || other.localIp == _this.localIp)&&(identical(other.localPort, _this.localPort) || other.localPort == _this.localPort)&&(identical(other.portPreserved, _this.portPreserved) || other.portPreserved == _this.portPreserved)&&(identical(other.otherAddress, _this.otherAddress) || other.otherAddress == _this.otherAddress)&&(identical(other.software, _this.software) || other.software == _this.software)&&(identical(other.latency, _this.latency) || other.latency == _this.latency)&&(identical(other.jitter, _this.jitter) || other.jitter == _this.jitter)&&(identical(other.packetLoss, _this.packetLoss) || other.packetLoss == _this.packetLoss)&&(identical(other.error, _this.error) || other.error == _this.error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as StunTestState;
  return Object.hashAll([runtimeType,_this.phase,_this.progress,_this.server,_this.address,_this.direct,_this.outbound,_this.natType,_this.mapping,_this.filtering,_this.public,_this.supported,_this.externalIp,_this.externalPort,_this.localIp,_this.localPort,_this.portPreserved,_this.otherAddress,_this.software,_this.latency,_this.jitter,_this.packetLoss,_this.error]);
}

@override
String toString() {
  final _this = this as StunTestState;
  return 'StunTestState(phase: ${_this.phase}, progress: ${_this.progress}, server: ${_this.server}, address: ${_this.address}, direct: ${_this.direct}, outbound: ${_this.outbound}, natType: ${_this.natType}, mapping: ${_this.mapping}, filtering: ${_this.filtering}, public: ${_this.public}, supported: ${_this.supported}, externalIp: ${_this.externalIp}, externalPort: ${_this.externalPort}, localIp: ${_this.localIp}, localPort: ${_this.localPort}, portPreserved: ${_this.portPreserved}, otherAddress: ${_this.otherAddress}, software: ${_this.software}, latency: ${_this.latency}, jitter: ${_this.jitter}, packetLoss: ${_this.packetLoss}, error: ${_this.error})';
}


}

/// @nodoc
abstract mixin class $StunTestStateCopyWith<$Res>  {
  factory $StunTestStateCopyWith(StunTestState value, $Res Function(StunTestState) _then) = _$StunTestStateCopyWithImpl;
@useResult
$Res call({
 StunTestPhase phase, double progress, String server, String address, bool direct, SpeedTestOutbound? outbound,@JsonKey(name: 'nat-type') NatType natType, String mapping, String filtering, bool public,@JsonKey(name: 'rfc5780') bool supported,@JsonKey(name: 'external-ip') String externalIp,@JsonKey(name: 'external-port') int externalPort,@JsonKey(name: 'local-ip') String localIp,@JsonKey(name: 'local-port') int localPort,@JsonKey(name: 'port-preserved') int portPreserved,@JsonKey(name: 'other-address') String otherAddress, String software, double latency, double jitter,@JsonKey(name: 'packet-loss') double packetLoss, String error
});


$SpeedTestOutboundCopyWith<$Res>? get outbound;

}
/// @nodoc
class _$StunTestStateCopyWithImpl<$Res>
    implements $StunTestStateCopyWith<$Res> {
  _$StunTestStateCopyWithImpl(this._self, this._then);

  final StunTestState _self;
  final $Res Function(StunTestState) _then;

/// Create a copy of StunTestState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? phase = null,Object? progress = null,Object? server = null,Object? address = null,Object? direct = null,Object? outbound = freezed,Object? natType = null,Object? mapping = null,Object? filtering = null,Object? public = null,Object? supported = null,Object? externalIp = null,Object? externalPort = null,Object? localIp = null,Object? localPort = null,Object? portPreserved = null,Object? otherAddress = null,Object? software = null,Object? latency = null,Object? jitter = null,Object? packetLoss = null,Object? error = null,}) {
  return _then(StunTestState(
phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as StunTestPhase,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,server: null == server ? _self.server : server // ignore: cast_nullable_to_non_nullable
as String,address: null == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String,direct: null == direct ? _self.direct : direct // ignore: cast_nullable_to_non_nullable
as bool,outbound: freezed == outbound ? _self.outbound : outbound // ignore: cast_nullable_to_non_nullable
as SpeedTestOutbound?,natType: null == natType ? _self.natType : natType // ignore: cast_nullable_to_non_nullable
as NatType,mapping: null == mapping ? _self.mapping : mapping // ignore: cast_nullable_to_non_nullable
as String,filtering: null == filtering ? _self.filtering : filtering // ignore: cast_nullable_to_non_nullable
as String,public: null == public ? _self.public : public // ignore: cast_nullable_to_non_nullable
as bool,supported: null == supported ? _self.supported : supported // ignore: cast_nullable_to_non_nullable
as bool,externalIp: null == externalIp ? _self.externalIp : externalIp // ignore: cast_nullable_to_non_nullable
as String,externalPort: null == externalPort ? _self.externalPort : externalPort // ignore: cast_nullable_to_non_nullable
as int,localIp: null == localIp ? _self.localIp : localIp // ignore: cast_nullable_to_non_nullable
as String,localPort: null == localPort ? _self.localPort : localPort // ignore: cast_nullable_to_non_nullable
as int,portPreserved: null == portPreserved ? _self.portPreserved : portPreserved // ignore: cast_nullable_to_non_nullable
as int,otherAddress: null == otherAddress ? _self.otherAddress : otherAddress // ignore: cast_nullable_to_non_nullable
as String,software: null == software ? _self.software : software // ignore: cast_nullable_to_non_nullable
as String,latency: null == latency ? _self.latency : latency // ignore: cast_nullable_to_non_nullable
as double,jitter: null == jitter ? _self.jitter : jitter // ignore: cast_nullable_to_non_nullable
as double,packetLoss: null == packetLoss ? _self.packetLoss : packetLoss // ignore: cast_nullable_to_non_nullable
as double,error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of StunTestState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SpeedTestOutboundCopyWith<$Res>? get outbound {
    if (_self.outbound == null) {
    return null;
  }

  return $SpeedTestOutboundCopyWith<$Res>(_self.outbound!, (value) {
    return _then(_self.copyWith(outbound: value));
  });
}
}


/// Adds pattern-matching-related methods to [StunTestState].
extension StunTestStatePatterns on StunTestState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StunTestState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StunTestState() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StunTestState value)  $default,){
final _that = this;
switch (_that) {
case _StunTestState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StunTestState value)?  $default,){
final _that = this;
switch (_that) {
case _StunTestState() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( StunTestPhase phase,  double progress,  String server,  String address,  bool direct,  SpeedTestOutbound? outbound, @JsonKey(name: 'nat-type')  NatType natType,  String mapping,  String filtering,  bool public, @JsonKey(name: 'rfc5780')  bool supported, @JsonKey(name: 'external-ip')  String externalIp, @JsonKey(name: 'external-port')  int externalPort, @JsonKey(name: 'local-ip')  String localIp, @JsonKey(name: 'local-port')  int localPort, @JsonKey(name: 'port-preserved')  int portPreserved, @JsonKey(name: 'other-address')  String otherAddress,  String software,  double latency,  double jitter, @JsonKey(name: 'packet-loss')  double packetLoss,  String error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StunTestState() when $default != null:
return $default(_that.phase,_that.progress,_that.server,_that.address,_that.direct,_that.outbound,_that.natType,_that.mapping,_that.filtering,_that.public,_that.supported,_that.externalIp,_that.externalPort,_that.localIp,_that.localPort,_that.portPreserved,_that.otherAddress,_that.software,_that.latency,_that.jitter,_that.packetLoss,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( StunTestPhase phase,  double progress,  String server,  String address,  bool direct,  SpeedTestOutbound? outbound, @JsonKey(name: 'nat-type')  NatType natType,  String mapping,  String filtering,  bool public, @JsonKey(name: 'rfc5780')  bool supported, @JsonKey(name: 'external-ip')  String externalIp, @JsonKey(name: 'external-port')  int externalPort, @JsonKey(name: 'local-ip')  String localIp, @JsonKey(name: 'local-port')  int localPort, @JsonKey(name: 'port-preserved')  int portPreserved, @JsonKey(name: 'other-address')  String otherAddress,  String software,  double latency,  double jitter, @JsonKey(name: 'packet-loss')  double packetLoss,  String error)  $default,) {final _that = this;
switch (_that) {
case _StunTestState():
return $default(_that.phase,_that.progress,_that.server,_that.address,_that.direct,_that.outbound,_that.natType,_that.mapping,_that.filtering,_that.public,_that.supported,_that.externalIp,_that.externalPort,_that.localIp,_that.localPort,_that.portPreserved,_that.otherAddress,_that.software,_that.latency,_that.jitter,_that.packetLoss,_that.error);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( StunTestPhase phase,  double progress,  String server,  String address,  bool direct,  SpeedTestOutbound? outbound, @JsonKey(name: 'nat-type')  NatType natType,  String mapping,  String filtering,  bool public, @JsonKey(name: 'rfc5780')  bool supported, @JsonKey(name: 'external-ip')  String externalIp, @JsonKey(name: 'external-port')  int externalPort, @JsonKey(name: 'local-ip')  String localIp, @JsonKey(name: 'local-port')  int localPort, @JsonKey(name: 'port-preserved')  int portPreserved, @JsonKey(name: 'other-address')  String otherAddress,  String software,  double latency,  double jitter, @JsonKey(name: 'packet-loss')  double packetLoss,  String error)?  $default,) {final _that = this;
switch (_that) {
case _StunTestState() when $default != null:
return $default(_that.phase,_that.progress,_that.server,_that.address,_that.direct,_that.outbound,_that.natType,_that.mapping,_that.filtering,_that.public,_that.supported,_that.externalIp,_that.externalPort,_that.localIp,_that.localPort,_that.portPreserved,_that.otherAddress,_that.software,_that.latency,_that.jitter,_that.packetLoss,_that.error);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _StunTestState implements StunTestState {
  const _StunTestState({this.phase = StunTestPhase.connecting, this.progress = 0, this.server = '', this.address = '', this.direct = false, this.outbound, @JsonKey(name: 'nat-type') this.natType = NatType.unknown, this.mapping = '', this.filtering = '', this.public = false, @JsonKey(name: 'rfc5780') this.supported = false, @JsonKey(name: 'external-ip') this.externalIp = '', @JsonKey(name: 'external-port') this.externalPort = 0, @JsonKey(name: 'local-ip') this.localIp = '', @JsonKey(name: 'local-port') this.localPort = 0, @JsonKey(name: 'port-preserved') this.portPreserved = -1, @JsonKey(name: 'other-address') this.otherAddress = '', this.software = '', this.latency = -1, this.jitter = 0, @JsonKey(name: 'packet-loss') this.packetLoss = -1, this.error = ''});
  factory _StunTestState.fromJson(Map<String, dynamic> json) => _$StunTestStateFromJson(json);

@override@JsonKey() final  StunTestPhase phase;
@override@JsonKey() final  double progress;
@override@JsonKey() final  String server;
@override@JsonKey() final  String address;
@override@JsonKey() final  bool direct;
@override final  SpeedTestOutbound? outbound;
@override@JsonKey(name: 'nat-type') final  NatType natType;
@override@JsonKey() final  String mapping;
@override@JsonKey() final  String filtering;
@override@JsonKey() final  bool public;
@override@JsonKey(name: 'rfc5780') final  bool supported;
@override@JsonKey(name: 'external-ip') final  String externalIp;
@override@JsonKey(name: 'external-port') final  int externalPort;
@override@JsonKey(name: 'local-ip') final  String localIp;
@override@JsonKey(name: 'local-port') final  int localPort;
@override@JsonKey(name: 'port-preserved') final  int portPreserved;
@override@JsonKey(name: 'other-address') final  String otherAddress;
@override@JsonKey() final  String software;
@override@JsonKey() final  double latency;
@override@JsonKey() final  double jitter;
@override@JsonKey(name: 'packet-loss') final  double packetLoss;
@override@JsonKey() final  String error;

/// Create a copy of StunTestState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StunTestStateCopyWith<_StunTestState> get copyWith => __$StunTestStateCopyWithImpl<_StunTestState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StunTestStateToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StunTestState&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.server, server) || other.server == server)&&(identical(other.address, address) || other.address == address)&&(identical(other.direct, direct) || other.direct == direct)&&(identical(other.outbound, outbound) || other.outbound == outbound)&&(identical(other.natType, natType) || other.natType == natType)&&(identical(other.mapping, mapping) || other.mapping == mapping)&&(identical(other.filtering, filtering) || other.filtering == filtering)&&(identical(other.public, public) || other.public == public)&&(identical(other.supported, supported) || other.supported == supported)&&(identical(other.externalIp, externalIp) || other.externalIp == externalIp)&&(identical(other.externalPort, externalPort) || other.externalPort == externalPort)&&(identical(other.localIp, localIp) || other.localIp == localIp)&&(identical(other.localPort, localPort) || other.localPort == localPort)&&(identical(other.portPreserved, portPreserved) || other.portPreserved == portPreserved)&&(identical(other.otherAddress, otherAddress) || other.otherAddress == otherAddress)&&(identical(other.software, software) || other.software == software)&&(identical(other.latency, latency) || other.latency == latency)&&(identical(other.jitter, jitter) || other.jitter == jitter)&&(identical(other.packetLoss, packetLoss) || other.packetLoss == packetLoss)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,phase,progress,server,address,direct,outbound,natType,mapping,filtering,public,supported,externalIp,externalPort,localIp,localPort,portPreserved,otherAddress,software,latency,jitter,packetLoss,error]);
}

@override
String toString() {
    return 'StunTestState(phase: $phase, progress: $progress, server: $server, address: $address, direct: $direct, outbound: $outbound, natType: $natType, mapping: $mapping, filtering: $filtering, public: $public, supported: $supported, externalIp: $externalIp, externalPort: $externalPort, localIp: $localIp, localPort: $localPort, portPreserved: $portPreserved, otherAddress: $otherAddress, software: $software, latency: $latency, jitter: $jitter, packetLoss: $packetLoss, error: $error)';
}


}

/// @nodoc
abstract mixin class _$StunTestStateCopyWith<$Res> implements $StunTestStateCopyWith<$Res> {
  factory _$StunTestStateCopyWith(_StunTestState value, $Res Function(_StunTestState) _then) = __$StunTestStateCopyWithImpl;
@override @useResult
$Res call({
 StunTestPhase phase, double progress, String server, String address, bool direct, SpeedTestOutbound? outbound,@JsonKey(name: 'nat-type') NatType natType, String mapping, String filtering, bool public,@JsonKey(name: 'rfc5780') bool supported,@JsonKey(name: 'external-ip') String externalIp,@JsonKey(name: 'external-port') int externalPort,@JsonKey(name: 'local-ip') String localIp,@JsonKey(name: 'local-port') int localPort,@JsonKey(name: 'port-preserved') int portPreserved,@JsonKey(name: 'other-address') String otherAddress, String software, double latency, double jitter,@JsonKey(name: 'packet-loss') double packetLoss, String error
});


@override $SpeedTestOutboundCopyWith<$Res>? get outbound;

}
/// @nodoc
class __$StunTestStateCopyWithImpl<$Res>
    implements _$StunTestStateCopyWith<$Res> {
  __$StunTestStateCopyWithImpl(this._self, this._then);

  final _StunTestState _self;
  final $Res Function(_StunTestState) _then;

/// Create a copy of StunTestState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? phase = null,Object? progress = null,Object? server = null,Object? address = null,Object? direct = null,Object? outbound = freezed,Object? natType = null,Object? mapping = null,Object? filtering = null,Object? public = null,Object? supported = null,Object? externalIp = null,Object? externalPort = null,Object? localIp = null,Object? localPort = null,Object? portPreserved = null,Object? otherAddress = null,Object? software = null,Object? latency = null,Object? jitter = null,Object? packetLoss = null,Object? error = null,}) {
  return _then(_StunTestState(
phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as StunTestPhase,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,server: null == server ? _self.server : server // ignore: cast_nullable_to_non_nullable
as String,address: null == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String,direct: null == direct ? _self.direct : direct // ignore: cast_nullable_to_non_nullable
as bool,outbound: freezed == outbound ? _self.outbound : outbound // ignore: cast_nullable_to_non_nullable
as SpeedTestOutbound?,natType: null == natType ? _self.natType : natType // ignore: cast_nullable_to_non_nullable
as NatType,mapping: null == mapping ? _self.mapping : mapping // ignore: cast_nullable_to_non_nullable
as String,filtering: null == filtering ? _self.filtering : filtering // ignore: cast_nullable_to_non_nullable
as String,public: null == public ? _self.public : public // ignore: cast_nullable_to_non_nullable
as bool,supported: null == supported ? _self.supported : supported // ignore: cast_nullable_to_non_nullable
as bool,externalIp: null == externalIp ? _self.externalIp : externalIp // ignore: cast_nullable_to_non_nullable
as String,externalPort: null == externalPort ? _self.externalPort : externalPort // ignore: cast_nullable_to_non_nullable
as int,localIp: null == localIp ? _self.localIp : localIp // ignore: cast_nullable_to_non_nullable
as String,localPort: null == localPort ? _self.localPort : localPort // ignore: cast_nullable_to_non_nullable
as int,portPreserved: null == portPreserved ? _self.portPreserved : portPreserved // ignore: cast_nullable_to_non_nullable
as int,otherAddress: null == otherAddress ? _self.otherAddress : otherAddress // ignore: cast_nullable_to_non_nullable
as String,software: null == software ? _self.software : software // ignore: cast_nullable_to_non_nullable
as String,latency: null == latency ? _self.latency : latency // ignore: cast_nullable_to_non_nullable
as double,jitter: null == jitter ? _self.jitter : jitter // ignore: cast_nullable_to_non_nullable
as double,packetLoss: null == packetLoss ? _self.packetLoss : packetLoss // ignore: cast_nullable_to_non_nullable
as double,error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of StunTestState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SpeedTestOutboundCopyWith<$Res>? get outbound {
    if (_self.outbound == null) {
    return null;
  }

  return $SpeedTestOutboundCopyWith<$Res>(_self.outbound!, (value) {
    return _then(_self.copyWith(outbound: value));
  });
}
}

// dart format on
