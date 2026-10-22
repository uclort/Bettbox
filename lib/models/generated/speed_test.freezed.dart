// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../speed_test.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SpeedTestOutbound {

 List<String> get chains; String get rule;@JsonKey(name: 'rule-payload') String get rulePayload;
/// Create a copy of SpeedTestOutbound
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SpeedTestOutboundCopyWith<SpeedTestOutbound> get copyWith => _$SpeedTestOutboundCopyWithImpl<SpeedTestOutbound>(this as SpeedTestOutbound, _$identity);

  /// Serializes this SpeedTestOutbound to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SpeedTestOutbound;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SpeedTestOutbound&&const DeepCollectionEquality().equals(other.chains, _this.chains)&&(identical(other.rule, _this.rule) || other.rule == _this.rule)&&(identical(other.rulePayload, _this.rulePayload) || other.rulePayload == _this.rulePayload));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SpeedTestOutbound;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.chains),_this.rule,_this.rulePayload);
}

@override
String toString() {
  final _this = this as SpeedTestOutbound;
  return 'SpeedTestOutbound(chains: ${_this.chains}, rule: ${_this.rule}, rulePayload: ${_this.rulePayload})';
}


}

/// @nodoc
abstract mixin class $SpeedTestOutboundCopyWith<$Res>  {
  factory $SpeedTestOutboundCopyWith(SpeedTestOutbound value, $Res Function(SpeedTestOutbound) _then) = _$SpeedTestOutboundCopyWithImpl;
@useResult
$Res call({
 List<String> chains, String rule,@JsonKey(name: 'rule-payload') String rulePayload
});




}
/// @nodoc
class _$SpeedTestOutboundCopyWithImpl<$Res>
    implements $SpeedTestOutboundCopyWith<$Res> {
  _$SpeedTestOutboundCopyWithImpl(this._self, this._then);

  final SpeedTestOutbound _self;
  final $Res Function(SpeedTestOutbound) _then;

/// Create a copy of SpeedTestOutbound
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? chains = null,Object? rule = null,Object? rulePayload = null,}) {
  return _then(SpeedTestOutbound(
chains: null == chains ? _self.chains : chains // ignore: cast_nullable_to_non_nullable
as List<String>,rule: null == rule ? _self.rule : rule // ignore: cast_nullable_to_non_nullable
as String,rulePayload: null == rulePayload ? _self.rulePayload : rulePayload // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [SpeedTestOutbound].
extension SpeedTestOutboundPatterns on SpeedTestOutbound {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SpeedTestOutbound value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SpeedTestOutbound() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SpeedTestOutbound value)  $default,){
final _that = this;
switch (_that) {
case _SpeedTestOutbound():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SpeedTestOutbound value)?  $default,){
final _that = this;
switch (_that) {
case _SpeedTestOutbound() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<String> chains,  String rule, @JsonKey(name: 'rule-payload')  String rulePayload)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SpeedTestOutbound() when $default != null:
return $default(_that.chains,_that.rule,_that.rulePayload);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<String> chains,  String rule, @JsonKey(name: 'rule-payload')  String rulePayload)  $default,) {final _that = this;
switch (_that) {
case _SpeedTestOutbound():
return $default(_that.chains,_that.rule,_that.rulePayload);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<String> chains,  String rule, @JsonKey(name: 'rule-payload')  String rulePayload)?  $default,) {final _that = this;
switch (_that) {
case _SpeedTestOutbound() when $default != null:
return $default(_that.chains,_that.rule,_that.rulePayload);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SpeedTestOutbound implements SpeedTestOutbound {
  const _SpeedTestOutbound({ List<String> chains = const [], this.rule = '', @JsonKey(name: 'rule-payload') this.rulePayload = ''}): _chains = chains;
  factory _SpeedTestOutbound.fromJson(Map<String, dynamic> json) => _$SpeedTestOutboundFromJson(json);

 final  List<String> _chains;
@override@JsonKey() List<String> get chains {
  if (_chains is EqualUnmodifiableListView) return _chains;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_chains);
}

@override@JsonKey() final  String rule;
@override@JsonKey(name: 'rule-payload') final  String rulePayload;

/// Create a copy of SpeedTestOutbound
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SpeedTestOutboundCopyWith<_SpeedTestOutbound> get copyWith => __$SpeedTestOutboundCopyWithImpl<_SpeedTestOutbound>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SpeedTestOutboundToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SpeedTestOutbound&&const DeepCollectionEquality().equals(other.chains, _chains)&&(identical(other.rule, rule) || other.rule == rule)&&(identical(other.rulePayload, rulePayload) || other.rulePayload == rulePayload));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_chains),rule,rulePayload);
}

@override
String toString() {
    return 'SpeedTestOutbound(chains: $chains, rule: $rule, rulePayload: $rulePayload)';
}


}

/// @nodoc
abstract mixin class _$SpeedTestOutboundCopyWith<$Res> implements $SpeedTestOutboundCopyWith<$Res> {
  factory _$SpeedTestOutboundCopyWith(_SpeedTestOutbound value, $Res Function(_SpeedTestOutbound) _then) = __$SpeedTestOutboundCopyWithImpl;
@override @useResult
$Res call({
 List<String> chains, String rule,@JsonKey(name: 'rule-payload') String rulePayload
});




}
/// @nodoc
class __$SpeedTestOutboundCopyWithImpl<$Res>
    implements _$SpeedTestOutboundCopyWith<$Res> {
  __$SpeedTestOutboundCopyWithImpl(this._self, this._then);

  final _SpeedTestOutbound _self;
  final $Res Function(_SpeedTestOutbound) _then;

/// Create a copy of SpeedTestOutbound
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? chains = null,Object? rule = null,Object? rulePayload = null,}) {
  return _then(_SpeedTestOutbound(
chains: null == chains ? _self._chains : chains // ignore: cast_nullable_to_non_nullable
as List<String>,rule: null == rule ? _self.rule : rule // ignore: cast_nullable_to_non_nullable
as String,rulePayload: null == rulePayload ? _self.rulePayload : rulePayload // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$SpeedTestServer {

 String get ip; String get country; String get city; String get colo; String get host; String get sponsor;
/// Create a copy of SpeedTestServer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SpeedTestServerCopyWith<SpeedTestServer> get copyWith => _$SpeedTestServerCopyWithImpl<SpeedTestServer>(this as SpeedTestServer, _$identity);

  /// Serializes this SpeedTestServer to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SpeedTestServer;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SpeedTestServer&&(identical(other.ip, _this.ip) || other.ip == _this.ip)&&(identical(other.country, _this.country) || other.country == _this.country)&&(identical(other.city, _this.city) || other.city == _this.city)&&(identical(other.colo, _this.colo) || other.colo == _this.colo)&&(identical(other.host, _this.host) || other.host == _this.host)&&(identical(other.sponsor, _this.sponsor) || other.sponsor == _this.sponsor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SpeedTestServer;
  return Object.hash(runtimeType,_this.ip,_this.country,_this.city,_this.colo,_this.host,_this.sponsor);
}

@override
String toString() {
  final _this = this as SpeedTestServer;
  return 'SpeedTestServer(ip: ${_this.ip}, country: ${_this.country}, city: ${_this.city}, colo: ${_this.colo}, host: ${_this.host}, sponsor: ${_this.sponsor})';
}


}

/// @nodoc
abstract mixin class $SpeedTestServerCopyWith<$Res>  {
  factory $SpeedTestServerCopyWith(SpeedTestServer value, $Res Function(SpeedTestServer) _then) = _$SpeedTestServerCopyWithImpl;
@useResult
$Res call({
 String ip, String country, String city, String colo, String host, String sponsor
});




}
/// @nodoc
class _$SpeedTestServerCopyWithImpl<$Res>
    implements $SpeedTestServerCopyWith<$Res> {
  _$SpeedTestServerCopyWithImpl(this._self, this._then);

  final SpeedTestServer _self;
  final $Res Function(SpeedTestServer) _then;

/// Create a copy of SpeedTestServer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ip = null,Object? country = null,Object? city = null,Object? colo = null,Object? host = null,Object? sponsor = null,}) {
  return _then(SpeedTestServer(
ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,country: null == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String,city: null == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String,colo: null == colo ? _self.colo : colo // ignore: cast_nullable_to_non_nullable
as String,host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,sponsor: null == sponsor ? _self.sponsor : sponsor // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [SpeedTestServer].
extension SpeedTestServerPatterns on SpeedTestServer {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SpeedTestServer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SpeedTestServer() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SpeedTestServer value)  $default,){
final _that = this;
switch (_that) {
case _SpeedTestServer():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SpeedTestServer value)?  $default,){
final _that = this;
switch (_that) {
case _SpeedTestServer() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String ip,  String country,  String city,  String colo,  String host,  String sponsor)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SpeedTestServer() when $default != null:
return $default(_that.ip,_that.country,_that.city,_that.colo,_that.host,_that.sponsor);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String ip,  String country,  String city,  String colo,  String host,  String sponsor)  $default,) {final _that = this;
switch (_that) {
case _SpeedTestServer():
return $default(_that.ip,_that.country,_that.city,_that.colo,_that.host,_that.sponsor);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String ip,  String country,  String city,  String colo,  String host,  String sponsor)?  $default,) {final _that = this;
switch (_that) {
case _SpeedTestServer() when $default != null:
return $default(_that.ip,_that.country,_that.city,_that.colo,_that.host,_that.sponsor);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SpeedTestServer implements SpeedTestServer {
  const _SpeedTestServer({this.ip = '', this.country = '', this.city = '', this.colo = '', this.host = '', this.sponsor = ''});
  factory _SpeedTestServer.fromJson(Map<String, dynamic> json) => _$SpeedTestServerFromJson(json);

@override@JsonKey() final  String ip;
@override@JsonKey() final  String country;
@override@JsonKey() final  String city;
@override@JsonKey() final  String colo;
@override@JsonKey() final  String host;
@override@JsonKey() final  String sponsor;

/// Create a copy of SpeedTestServer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SpeedTestServerCopyWith<_SpeedTestServer> get copyWith => __$SpeedTestServerCopyWithImpl<_SpeedTestServer>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SpeedTestServerToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SpeedTestServer&&(identical(other.ip, ip) || other.ip == ip)&&(identical(other.country, country) || other.country == country)&&(identical(other.city, city) || other.city == city)&&(identical(other.colo, colo) || other.colo == colo)&&(identical(other.host, host) || other.host == host)&&(identical(other.sponsor, sponsor) || other.sponsor == sponsor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,ip,country,city,colo,host,sponsor);
}

@override
String toString() {
    return 'SpeedTestServer(ip: $ip, country: $country, city: $city, colo: $colo, host: $host, sponsor: $sponsor)';
}


}

/// @nodoc
abstract mixin class _$SpeedTestServerCopyWith<$Res> implements $SpeedTestServerCopyWith<$Res> {
  factory _$SpeedTestServerCopyWith(_SpeedTestServer value, $Res Function(_SpeedTestServer) _then) = __$SpeedTestServerCopyWithImpl;
@override @useResult
$Res call({
 String ip, String country, String city, String colo, String host, String sponsor
});




}
/// @nodoc
class __$SpeedTestServerCopyWithImpl<$Res>
    implements _$SpeedTestServerCopyWith<$Res> {
  __$SpeedTestServerCopyWithImpl(this._self, this._then);

  final _SpeedTestServer _self;
  final $Res Function(_SpeedTestServer) _then;

/// Create a copy of SpeedTestServer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ip = null,Object? country = null,Object? city = null,Object? colo = null,Object? host = null,Object? sponsor = null,}) {
  return _then(_SpeedTestServer(
ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,country: null == country ? _self.country : country // ignore: cast_nullable_to_non_nullable
as String,city: null == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String,colo: null == colo ? _self.colo : colo // ignore: cast_nullable_to_non_nullable
as String,host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,sponsor: null == sponsor ? _self.sponsor : sponsor // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$SpeedTestState {

 SpeedTestProvider get provider; String get protocol; bool get fallback;@JsonKey(name: 'exit-info') Map<String, dynamic>? get exitInfo; int get streams; int get duration; SpeedTestPhase get phase; double get progress; double get speed; bool get direct; SpeedTestOutbound? get outbound; SpeedTestServer? get server; double get latency; double get jitter; double get download; double get upload;@JsonKey(name: 'download-latency') double get downloadLatency;@JsonKey(name: 'upload-latency') double get uploadLatency; int get rpm; int get bytes; String get error;
/// Create a copy of SpeedTestState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SpeedTestStateCopyWith<SpeedTestState> get copyWith => _$SpeedTestStateCopyWithImpl<SpeedTestState>(this as SpeedTestState, _$identity);

  /// Serializes this SpeedTestState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SpeedTestState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SpeedTestState&&(identical(other.provider, _this.provider) || other.provider == _this.provider)&&(identical(other.protocol, _this.protocol) || other.protocol == _this.protocol)&&(identical(other.fallback, _this.fallback) || other.fallback == _this.fallback)&&const DeepCollectionEquality().equals(other.exitInfo, _this.exitInfo)&&(identical(other.streams, _this.streams) || other.streams == _this.streams)&&(identical(other.duration, _this.duration) || other.duration == _this.duration)&&(identical(other.phase, _this.phase) || other.phase == _this.phase)&&(identical(other.progress, _this.progress) || other.progress == _this.progress)&&(identical(other.speed, _this.speed) || other.speed == _this.speed)&&(identical(other.direct, _this.direct) || other.direct == _this.direct)&&(identical(other.outbound, _this.outbound) || other.outbound == _this.outbound)&&(identical(other.server, _this.server) || other.server == _this.server)&&(identical(other.latency, _this.latency) || other.latency == _this.latency)&&(identical(other.jitter, _this.jitter) || other.jitter == _this.jitter)&&(identical(other.download, _this.download) || other.download == _this.download)&&(identical(other.upload, _this.upload) || other.upload == _this.upload)&&(identical(other.downloadLatency, _this.downloadLatency) || other.downloadLatency == _this.downloadLatency)&&(identical(other.uploadLatency, _this.uploadLatency) || other.uploadLatency == _this.uploadLatency)&&(identical(other.rpm, _this.rpm) || other.rpm == _this.rpm)&&(identical(other.bytes, _this.bytes) || other.bytes == _this.bytes)&&(identical(other.error, _this.error) || other.error == _this.error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SpeedTestState;
  return Object.hashAll([runtimeType,_this.provider,_this.protocol,_this.fallback,const DeepCollectionEquality().hash(_this.exitInfo),_this.streams,_this.duration,_this.phase,_this.progress,_this.speed,_this.direct,_this.outbound,_this.server,_this.latency,_this.jitter,_this.download,_this.upload,_this.downloadLatency,_this.uploadLatency,_this.rpm,_this.bytes,_this.error]);
}

@override
String toString() {
  final _this = this as SpeedTestState;
  return 'SpeedTestState(provider: ${_this.provider}, protocol: ${_this.protocol}, fallback: ${_this.fallback}, exitInfo: ${_this.exitInfo}, streams: ${_this.streams}, duration: ${_this.duration}, phase: ${_this.phase}, progress: ${_this.progress}, speed: ${_this.speed}, direct: ${_this.direct}, outbound: ${_this.outbound}, server: ${_this.server}, latency: ${_this.latency}, jitter: ${_this.jitter}, download: ${_this.download}, upload: ${_this.upload}, downloadLatency: ${_this.downloadLatency}, uploadLatency: ${_this.uploadLatency}, rpm: ${_this.rpm}, bytes: ${_this.bytes}, error: ${_this.error})';
}


}

/// @nodoc
abstract mixin class $SpeedTestStateCopyWith<$Res>  {
  factory $SpeedTestStateCopyWith(SpeedTestState value, $Res Function(SpeedTestState) _then) = _$SpeedTestStateCopyWithImpl;
@useResult
$Res call({
 SpeedTestProvider provider, String protocol, bool fallback,@JsonKey(name: 'exit-info') Map<String, dynamic>? exitInfo, int streams, int duration, SpeedTestPhase phase, double progress, double speed, bool direct, SpeedTestOutbound? outbound, SpeedTestServer? server, double latency, double jitter, double download, double upload,@JsonKey(name: 'download-latency') double downloadLatency,@JsonKey(name: 'upload-latency') double uploadLatency, int rpm, int bytes, String error
});


$SpeedTestOutboundCopyWith<$Res>? get outbound;$SpeedTestServerCopyWith<$Res>? get server;

}
/// @nodoc
class _$SpeedTestStateCopyWithImpl<$Res>
    implements $SpeedTestStateCopyWith<$Res> {
  _$SpeedTestStateCopyWithImpl(this._self, this._then);

  final SpeedTestState _self;
  final $Res Function(SpeedTestState) _then;

/// Create a copy of SpeedTestState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? provider = null,Object? protocol = null,Object? fallback = null,Object? exitInfo = freezed,Object? streams = null,Object? duration = null,Object? phase = null,Object? progress = null,Object? speed = null,Object? direct = null,Object? outbound = freezed,Object? server = freezed,Object? latency = null,Object? jitter = null,Object? download = null,Object? upload = null,Object? downloadLatency = null,Object? uploadLatency = null,Object? rpm = null,Object? bytes = null,Object? error = null,}) {
  return _then(SpeedTestState(
provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as SpeedTestProvider,protocol: null == protocol ? _self.protocol : protocol // ignore: cast_nullable_to_non_nullable
as String,fallback: null == fallback ? _self.fallback : fallback // ignore: cast_nullable_to_non_nullable
as bool,exitInfo: freezed == exitInfo ? _self.exitInfo : exitInfo // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,streams: null == streams ? _self.streams : streams // ignore: cast_nullable_to_non_nullable
as int,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as int,phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as SpeedTestPhase,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,speed: null == speed ? _self.speed : speed // ignore: cast_nullable_to_non_nullable
as double,direct: null == direct ? _self.direct : direct // ignore: cast_nullable_to_non_nullable
as bool,outbound: freezed == outbound ? _self.outbound : outbound // ignore: cast_nullable_to_non_nullable
as SpeedTestOutbound?,server: freezed == server ? _self.server : server // ignore: cast_nullable_to_non_nullable
as SpeedTestServer?,latency: null == latency ? _self.latency : latency // ignore: cast_nullable_to_non_nullable
as double,jitter: null == jitter ? _self.jitter : jitter // ignore: cast_nullable_to_non_nullable
as double,download: null == download ? _self.download : download // ignore: cast_nullable_to_non_nullable
as double,upload: null == upload ? _self.upload : upload // ignore: cast_nullable_to_non_nullable
as double,downloadLatency: null == downloadLatency ? _self.downloadLatency : downloadLatency // ignore: cast_nullable_to_non_nullable
as double,uploadLatency: null == uploadLatency ? _self.uploadLatency : uploadLatency // ignore: cast_nullable_to_non_nullable
as double,rpm: null == rpm ? _self.rpm : rpm // ignore: cast_nullable_to_non_nullable
as int,bytes: null == bytes ? _self.bytes : bytes // ignore: cast_nullable_to_non_nullable
as int,error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of SpeedTestState
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
}/// Create a copy of SpeedTestState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SpeedTestServerCopyWith<$Res>? get server {
    if (_self.server == null) {
    return null;
  }

  return $SpeedTestServerCopyWith<$Res>(_self.server!, (value) {
    return _then(_self.copyWith(server: value));
  });
}
}


/// Adds pattern-matching-related methods to [SpeedTestState].
extension SpeedTestStatePatterns on SpeedTestState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SpeedTestState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SpeedTestState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SpeedTestState value)  $default,){
final _that = this;
switch (_that) {
case _SpeedTestState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SpeedTestState value)?  $default,){
final _that = this;
switch (_that) {
case _SpeedTestState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SpeedTestProvider provider,  String protocol,  bool fallback, @JsonKey(name: 'exit-info')  Map<String, dynamic>? exitInfo,  int streams,  int duration,  SpeedTestPhase phase,  double progress,  double speed,  bool direct,  SpeedTestOutbound? outbound,  SpeedTestServer? server,  double latency,  double jitter,  double download,  double upload, @JsonKey(name: 'download-latency')  double downloadLatency, @JsonKey(name: 'upload-latency')  double uploadLatency,  int rpm,  int bytes,  String error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SpeedTestState() when $default != null:
return $default(_that.provider,_that.protocol,_that.fallback,_that.exitInfo,_that.streams,_that.duration,_that.phase,_that.progress,_that.speed,_that.direct,_that.outbound,_that.server,_that.latency,_that.jitter,_that.download,_that.upload,_that.downloadLatency,_that.uploadLatency,_that.rpm,_that.bytes,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SpeedTestProvider provider,  String protocol,  bool fallback, @JsonKey(name: 'exit-info')  Map<String, dynamic>? exitInfo,  int streams,  int duration,  SpeedTestPhase phase,  double progress,  double speed,  bool direct,  SpeedTestOutbound? outbound,  SpeedTestServer? server,  double latency,  double jitter,  double download,  double upload, @JsonKey(name: 'download-latency')  double downloadLatency, @JsonKey(name: 'upload-latency')  double uploadLatency,  int rpm,  int bytes,  String error)  $default,) {final _that = this;
switch (_that) {
case _SpeedTestState():
return $default(_that.provider,_that.protocol,_that.fallback,_that.exitInfo,_that.streams,_that.duration,_that.phase,_that.progress,_that.speed,_that.direct,_that.outbound,_that.server,_that.latency,_that.jitter,_that.download,_that.upload,_that.downloadLatency,_that.uploadLatency,_that.rpm,_that.bytes,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SpeedTestProvider provider,  String protocol,  bool fallback, @JsonKey(name: 'exit-info')  Map<String, dynamic>? exitInfo,  int streams,  int duration,  SpeedTestPhase phase,  double progress,  double speed,  bool direct,  SpeedTestOutbound? outbound,  SpeedTestServer? server,  double latency,  double jitter,  double download,  double upload, @JsonKey(name: 'download-latency')  double downloadLatency, @JsonKey(name: 'upload-latency')  double uploadLatency,  int rpm,  int bytes,  String error)?  $default,) {final _that = this;
switch (_that) {
case _SpeedTestState() when $default != null:
return $default(_that.provider,_that.protocol,_that.fallback,_that.exitInfo,_that.streams,_that.duration,_that.phase,_that.progress,_that.speed,_that.direct,_that.outbound,_that.server,_that.latency,_that.jitter,_that.download,_that.upload,_that.downloadLatency,_that.uploadLatency,_that.rpm,_that.bytes,_that.error);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SpeedTestState implements SpeedTestState {
  const _SpeedTestState({this.provider = SpeedTestProvider.apple, this.protocol = 'h1', this.fallback = false, @JsonKey(name: 'exit-info')  Map<String, dynamic>? exitInfo, this.streams = 6, this.duration = 10, this.phase = SpeedTestPhase.connecting, this.progress = 0, this.speed = 0, this.direct = false, this.outbound, this.server, this.latency = 0, this.jitter = 0, this.download = 0, this.upload = 0, @JsonKey(name: 'download-latency') this.downloadLatency = 0, @JsonKey(name: 'upload-latency') this.uploadLatency = 0, this.rpm = 0, this.bytes = 0, this.error = ''}): _exitInfo = exitInfo;
  factory _SpeedTestState.fromJson(Map<String, dynamic> json) => _$SpeedTestStateFromJson(json);

@override@JsonKey() final  SpeedTestProvider provider;
@override@JsonKey() final  String protocol;
@override@JsonKey() final  bool fallback;
 final  Map<String, dynamic>? _exitInfo;
@override@JsonKey(name: 'exit-info') Map<String, dynamic>? get exitInfo {
  final value = _exitInfo;
  if (value == null) return null;
  if (_exitInfo is EqualUnmodifiableMapView) return _exitInfo;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override@JsonKey() final  int streams;
@override@JsonKey() final  int duration;
@override@JsonKey() final  SpeedTestPhase phase;
@override@JsonKey() final  double progress;
@override@JsonKey() final  double speed;
@override@JsonKey() final  bool direct;
@override final  SpeedTestOutbound? outbound;
@override final  SpeedTestServer? server;
@override@JsonKey() final  double latency;
@override@JsonKey() final  double jitter;
@override@JsonKey() final  double download;
@override@JsonKey() final  double upload;
@override@JsonKey(name: 'download-latency') final  double downloadLatency;
@override@JsonKey(name: 'upload-latency') final  double uploadLatency;
@override@JsonKey() final  int rpm;
@override@JsonKey() final  int bytes;
@override@JsonKey() final  String error;

/// Create a copy of SpeedTestState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SpeedTestStateCopyWith<_SpeedTestState> get copyWith => __$SpeedTestStateCopyWithImpl<_SpeedTestState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SpeedTestStateToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SpeedTestState&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.protocol, protocol) || other.protocol == protocol)&&(identical(other.fallback, fallback) || other.fallback == fallback)&&const DeepCollectionEquality().equals(other.exitInfo, _exitInfo)&&(identical(other.streams, streams) || other.streams == streams)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.speed, speed) || other.speed == speed)&&(identical(other.direct, direct) || other.direct == direct)&&(identical(other.outbound, outbound) || other.outbound == outbound)&&(identical(other.server, server) || other.server == server)&&(identical(other.latency, latency) || other.latency == latency)&&(identical(other.jitter, jitter) || other.jitter == jitter)&&(identical(other.download, download) || other.download == download)&&(identical(other.upload, upload) || other.upload == upload)&&(identical(other.downloadLatency, downloadLatency) || other.downloadLatency == downloadLatency)&&(identical(other.uploadLatency, uploadLatency) || other.uploadLatency == uploadLatency)&&(identical(other.rpm, rpm) || other.rpm == rpm)&&(identical(other.bytes, bytes) || other.bytes == bytes)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,provider,protocol,fallback,const DeepCollectionEquality().hash(_exitInfo),streams,duration,phase,progress,speed,direct,outbound,server,latency,jitter,download,upload,downloadLatency,uploadLatency,rpm,bytes,error]);
}

@override
String toString() {
    return 'SpeedTestState(provider: $provider, protocol: $protocol, fallback: $fallback, exitInfo: $exitInfo, streams: $streams, duration: $duration, phase: $phase, progress: $progress, speed: $speed, direct: $direct, outbound: $outbound, server: $server, latency: $latency, jitter: $jitter, download: $download, upload: $upload, downloadLatency: $downloadLatency, uploadLatency: $uploadLatency, rpm: $rpm, bytes: $bytes, error: $error)';
}


}

/// @nodoc
abstract mixin class _$SpeedTestStateCopyWith<$Res> implements $SpeedTestStateCopyWith<$Res> {
  factory _$SpeedTestStateCopyWith(_SpeedTestState value, $Res Function(_SpeedTestState) _then) = __$SpeedTestStateCopyWithImpl;
@override @useResult
$Res call({
 SpeedTestProvider provider, String protocol, bool fallback,@JsonKey(name: 'exit-info') Map<String, dynamic>? exitInfo, int streams, int duration, SpeedTestPhase phase, double progress, double speed, bool direct, SpeedTestOutbound? outbound, SpeedTestServer? server, double latency, double jitter, double download, double upload,@JsonKey(name: 'download-latency') double downloadLatency,@JsonKey(name: 'upload-latency') double uploadLatency, int rpm, int bytes, String error
});


@override $SpeedTestOutboundCopyWith<$Res>? get outbound;@override $SpeedTestServerCopyWith<$Res>? get server;

}
/// @nodoc
class __$SpeedTestStateCopyWithImpl<$Res>
    implements _$SpeedTestStateCopyWith<$Res> {
  __$SpeedTestStateCopyWithImpl(this._self, this._then);

  final _SpeedTestState _self;
  final $Res Function(_SpeedTestState) _then;

/// Create a copy of SpeedTestState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? provider = null,Object? protocol = null,Object? fallback = null,Object? exitInfo = freezed,Object? streams = null,Object? duration = null,Object? phase = null,Object? progress = null,Object? speed = null,Object? direct = null,Object? outbound = freezed,Object? server = freezed,Object? latency = null,Object? jitter = null,Object? download = null,Object? upload = null,Object? downloadLatency = null,Object? uploadLatency = null,Object? rpm = null,Object? bytes = null,Object? error = null,}) {
  return _then(_SpeedTestState(
provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as SpeedTestProvider,protocol: null == protocol ? _self.protocol : protocol // ignore: cast_nullable_to_non_nullable
as String,fallback: null == fallback ? _self.fallback : fallback // ignore: cast_nullable_to_non_nullable
as bool,exitInfo: freezed == exitInfo ? _self._exitInfo : exitInfo // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,streams: null == streams ? _self.streams : streams // ignore: cast_nullable_to_non_nullable
as int,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as int,phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as SpeedTestPhase,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,speed: null == speed ? _self.speed : speed // ignore: cast_nullable_to_non_nullable
as double,direct: null == direct ? _self.direct : direct // ignore: cast_nullable_to_non_nullable
as bool,outbound: freezed == outbound ? _self.outbound : outbound // ignore: cast_nullable_to_non_nullable
as SpeedTestOutbound?,server: freezed == server ? _self.server : server // ignore: cast_nullable_to_non_nullable
as SpeedTestServer?,latency: null == latency ? _self.latency : latency // ignore: cast_nullable_to_non_nullable
as double,jitter: null == jitter ? _self.jitter : jitter // ignore: cast_nullable_to_non_nullable
as double,download: null == download ? _self.download : download // ignore: cast_nullable_to_non_nullable
as double,upload: null == upload ? _self.upload : upload // ignore: cast_nullable_to_non_nullable
as double,downloadLatency: null == downloadLatency ? _self.downloadLatency : downloadLatency // ignore: cast_nullable_to_non_nullable
as double,uploadLatency: null == uploadLatency ? _self.uploadLatency : uploadLatency // ignore: cast_nullable_to_non_nullable
as double,rpm: null == rpm ? _self.rpm : rpm // ignore: cast_nullable_to_non_nullable
as int,bytes: null == bytes ? _self.bytes : bytes // ignore: cast_nullable_to_non_nullable
as int,error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of SpeedTestState
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
}/// Create a copy of SpeedTestState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SpeedTestServerCopyWith<$Res>? get server {
    if (_self.server == null) {
    return null;
  }

  return $SpeedTestServerCopyWith<$Res>(_self.server!, (value) {
    return _then(_self.copyWith(server: value));
  });
}
}


/// @nodoc
mixin _$SpeedTestRecord {

 int get time; String get proxy; SpeedTestState get result;
/// Create a copy of SpeedTestRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SpeedTestRecordCopyWith<SpeedTestRecord> get copyWith => _$SpeedTestRecordCopyWithImpl<SpeedTestRecord>(this as SpeedTestRecord, _$identity);

  /// Serializes this SpeedTestRecord to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SpeedTestRecord;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SpeedTestRecord&&(identical(other.time, _this.time) || other.time == _this.time)&&(identical(other.proxy, _this.proxy) || other.proxy == _this.proxy)&&(identical(other.result, _this.result) || other.result == _this.result));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SpeedTestRecord;
  return Object.hash(runtimeType,_this.time,_this.proxy,_this.result);
}

@override
String toString() {
  final _this = this as SpeedTestRecord;
  return 'SpeedTestRecord(time: ${_this.time}, proxy: ${_this.proxy}, result: ${_this.result})';
}


}

/// @nodoc
abstract mixin class $SpeedTestRecordCopyWith<$Res>  {
  factory $SpeedTestRecordCopyWith(SpeedTestRecord value, $Res Function(SpeedTestRecord) _then) = _$SpeedTestRecordCopyWithImpl;
@useResult
$Res call({
 int time, String proxy, SpeedTestState result
});


$SpeedTestStateCopyWith<$Res> get result;

}
/// @nodoc
class _$SpeedTestRecordCopyWithImpl<$Res>
    implements $SpeedTestRecordCopyWith<$Res> {
  _$SpeedTestRecordCopyWithImpl(this._self, this._then);

  final SpeedTestRecord _self;
  final $Res Function(SpeedTestRecord) _then;

/// Create a copy of SpeedTestRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? time = null,Object? proxy = null,Object? result = null,}) {
  return _then(SpeedTestRecord(
time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as int,proxy: null == proxy ? _self.proxy : proxy // ignore: cast_nullable_to_non_nullable
as String,result: null == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as SpeedTestState,
  ));
}
/// Create a copy of SpeedTestRecord
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SpeedTestStateCopyWith<$Res> get result {
  
  return $SpeedTestStateCopyWith<$Res>(_self.result, (value) {
    return _then(_self.copyWith(result: value));
  });
}
}


/// Adds pattern-matching-related methods to [SpeedTestRecord].
extension SpeedTestRecordPatterns on SpeedTestRecord {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SpeedTestRecord value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SpeedTestRecord() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SpeedTestRecord value)  $default,){
final _that = this;
switch (_that) {
case _SpeedTestRecord():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SpeedTestRecord value)?  $default,){
final _that = this;
switch (_that) {
case _SpeedTestRecord() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int time,  String proxy,  SpeedTestState result)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SpeedTestRecord() when $default != null:
return $default(_that.time,_that.proxy,_that.result);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int time,  String proxy,  SpeedTestState result)  $default,) {final _that = this;
switch (_that) {
case _SpeedTestRecord():
return $default(_that.time,_that.proxy,_that.result);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int time,  String proxy,  SpeedTestState result)?  $default,) {final _that = this;
switch (_that) {
case _SpeedTestRecord() when $default != null:
return $default(_that.time,_that.proxy,_that.result);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SpeedTestRecord implements SpeedTestRecord {
  const _SpeedTestRecord({required this.time, this.proxy = '', required this.result});
  factory _SpeedTestRecord.fromJson(Map<String, dynamic> json) => _$SpeedTestRecordFromJson(json);

@override final  int time;
@override@JsonKey() final  String proxy;
@override final  SpeedTestState result;

/// Create a copy of SpeedTestRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SpeedTestRecordCopyWith<_SpeedTestRecord> get copyWith => __$SpeedTestRecordCopyWithImpl<_SpeedTestRecord>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SpeedTestRecordToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SpeedTestRecord&&(identical(other.time, time) || other.time == time)&&(identical(other.proxy, proxy) || other.proxy == proxy)&&(identical(other.result, result) || other.result == result));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,time,proxy,result);
}

@override
String toString() {
    return 'SpeedTestRecord(time: $time, proxy: $proxy, result: $result)';
}


}

/// @nodoc
abstract mixin class _$SpeedTestRecordCopyWith<$Res> implements $SpeedTestRecordCopyWith<$Res> {
  factory _$SpeedTestRecordCopyWith(_SpeedTestRecord value, $Res Function(_SpeedTestRecord) _then) = __$SpeedTestRecordCopyWithImpl;
@override @useResult
$Res call({
 int time, String proxy, SpeedTestState result
});


@override $SpeedTestStateCopyWith<$Res> get result;

}
/// @nodoc
class __$SpeedTestRecordCopyWithImpl<$Res>
    implements _$SpeedTestRecordCopyWith<$Res> {
  __$SpeedTestRecordCopyWithImpl(this._self, this._then);

  final _SpeedTestRecord _self;
  final $Res Function(_SpeedTestRecord) _then;

/// Create a copy of SpeedTestRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? time = null,Object? proxy = null,Object? result = null,}) {
  return _then(_SpeedTestRecord(
time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as int,proxy: null == proxy ? _self.proxy : proxy // ignore: cast_nullable_to_non_nullable
as String,result: null == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as SpeedTestState,
  ));
}

/// Create a copy of SpeedTestRecord
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SpeedTestStateCopyWith<$Res> get result {
  
  return $SpeedTestStateCopyWith<$Res>(_self.result, (value) {
    return _then(_self.copyWith(result: value));
  });
}
}


/// @nodoc
mixin _$SpeedTestNode {

 String get host; String get name; String get cc; String get sponsor; double get latency;
/// Create a copy of SpeedTestNode
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SpeedTestNodeCopyWith<SpeedTestNode> get copyWith => _$SpeedTestNodeCopyWithImpl<SpeedTestNode>(this as SpeedTestNode, _$identity);

  /// Serializes this SpeedTestNode to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SpeedTestNode;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SpeedTestNode&&(identical(other.host, _this.host) || other.host == _this.host)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.cc, _this.cc) || other.cc == _this.cc)&&(identical(other.sponsor, _this.sponsor) || other.sponsor == _this.sponsor)&&(identical(other.latency, _this.latency) || other.latency == _this.latency));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SpeedTestNode;
  return Object.hash(runtimeType,_this.host,_this.name,_this.cc,_this.sponsor,_this.latency);
}

@override
String toString() {
  final _this = this as SpeedTestNode;
  return 'SpeedTestNode(host: ${_this.host}, name: ${_this.name}, cc: ${_this.cc}, sponsor: ${_this.sponsor}, latency: ${_this.latency})';
}


}

/// @nodoc
abstract mixin class $SpeedTestNodeCopyWith<$Res>  {
  factory $SpeedTestNodeCopyWith(SpeedTestNode value, $Res Function(SpeedTestNode) _then) = _$SpeedTestNodeCopyWithImpl;
@useResult
$Res call({
 String host, String name, String cc, String sponsor, double latency
});




}
/// @nodoc
class _$SpeedTestNodeCopyWithImpl<$Res>
    implements $SpeedTestNodeCopyWith<$Res> {
  _$SpeedTestNodeCopyWithImpl(this._self, this._then);

  final SpeedTestNode _self;
  final $Res Function(SpeedTestNode) _then;

/// Create a copy of SpeedTestNode
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? host = null,Object? name = null,Object? cc = null,Object? sponsor = null,Object? latency = null,}) {
  return _then(SpeedTestNode(
host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,cc: null == cc ? _self.cc : cc // ignore: cast_nullable_to_non_nullable
as String,sponsor: null == sponsor ? _self.sponsor : sponsor // ignore: cast_nullable_to_non_nullable
as String,latency: null == latency ? _self.latency : latency // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [SpeedTestNode].
extension SpeedTestNodePatterns on SpeedTestNode {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SpeedTestNode value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SpeedTestNode() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SpeedTestNode value)  $default,){
final _that = this;
switch (_that) {
case _SpeedTestNode():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SpeedTestNode value)?  $default,){
final _that = this;
switch (_that) {
case _SpeedTestNode() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String host,  String name,  String cc,  String sponsor,  double latency)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SpeedTestNode() when $default != null:
return $default(_that.host,_that.name,_that.cc,_that.sponsor,_that.latency);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String host,  String name,  String cc,  String sponsor,  double latency)  $default,) {final _that = this;
switch (_that) {
case _SpeedTestNode():
return $default(_that.host,_that.name,_that.cc,_that.sponsor,_that.latency);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String host,  String name,  String cc,  String sponsor,  double latency)?  $default,) {final _that = this;
switch (_that) {
case _SpeedTestNode() when $default != null:
return $default(_that.host,_that.name,_that.cc,_that.sponsor,_that.latency);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SpeedTestNode implements SpeedTestNode {
  const _SpeedTestNode({this.host = '', this.name = '', this.cc = '', this.sponsor = '', this.latency = 0});
  factory _SpeedTestNode.fromJson(Map<String, dynamic> json) => _$SpeedTestNodeFromJson(json);

@override@JsonKey() final  String host;
@override@JsonKey() final  String name;
@override@JsonKey() final  String cc;
@override@JsonKey() final  String sponsor;
@override@JsonKey() final  double latency;

/// Create a copy of SpeedTestNode
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SpeedTestNodeCopyWith<_SpeedTestNode> get copyWith => __$SpeedTestNodeCopyWithImpl<_SpeedTestNode>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SpeedTestNodeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SpeedTestNode&&(identical(other.host, host) || other.host == host)&&(identical(other.name, name) || other.name == name)&&(identical(other.cc, cc) || other.cc == cc)&&(identical(other.sponsor, sponsor) || other.sponsor == sponsor)&&(identical(other.latency, latency) || other.latency == latency));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,host,name,cc,sponsor,latency);
}

@override
String toString() {
    return 'SpeedTestNode(host: $host, name: $name, cc: $cc, sponsor: $sponsor, latency: $latency)';
}


}

/// @nodoc
abstract mixin class _$SpeedTestNodeCopyWith<$Res> implements $SpeedTestNodeCopyWith<$Res> {
  factory _$SpeedTestNodeCopyWith(_SpeedTestNode value, $Res Function(_SpeedTestNode) _then) = __$SpeedTestNodeCopyWithImpl;
@override @useResult
$Res call({
 String host, String name, String cc, String sponsor, double latency
});




}
/// @nodoc
class __$SpeedTestNodeCopyWithImpl<$Res>
    implements _$SpeedTestNodeCopyWith<$Res> {
  __$SpeedTestNodeCopyWithImpl(this._self, this._then);

  final _SpeedTestNode _self;
  final $Res Function(_SpeedTestNode) _then;

/// Create a copy of SpeedTestNode
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? host = null,Object? name = null,Object? cc = null,Object? sponsor = null,Object? latency = null,}) {
  return _then(_SpeedTestNode(
host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,cc: null == cc ? _self.cc : cc // ignore: cast_nullable_to_non_nullable
as String,sponsor: null == sponsor ? _self.sponsor : sponsor // ignore: cast_nullable_to_non_nullable
as String,latency: null == latency ? _self.latency : latency // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}


/// @nodoc
mixin _$SpeedTestSettings {

 SpeedTestProvider get provider; SpeedTestProtocol get protocol; int get duration; bool get multiThread;@JsonKey(name: 'use-system-dns') bool get useSystemDns; SpeedTestNode? get server;
/// Create a copy of SpeedTestSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SpeedTestSettingsCopyWith<SpeedTestSettings> get copyWith => _$SpeedTestSettingsCopyWithImpl<SpeedTestSettings>(this as SpeedTestSettings, _$identity);

  /// Serializes this SpeedTestSettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SpeedTestSettings;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SpeedTestSettings&&(identical(other.provider, _this.provider) || other.provider == _this.provider)&&(identical(other.protocol, _this.protocol) || other.protocol == _this.protocol)&&(identical(other.duration, _this.duration) || other.duration == _this.duration)&&(identical(other.multiThread, _this.multiThread) || other.multiThread == _this.multiThread)&&(identical(other.useSystemDns, _this.useSystemDns) || other.useSystemDns == _this.useSystemDns)&&(identical(other.server, _this.server) || other.server == _this.server));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SpeedTestSettings;
  return Object.hash(runtimeType,_this.provider,_this.protocol,_this.duration,_this.multiThread,_this.useSystemDns,_this.server);
}

@override
String toString() {
  final _this = this as SpeedTestSettings;
  return 'SpeedTestSettings(provider: ${_this.provider}, protocol: ${_this.protocol}, duration: ${_this.duration}, multiThread: ${_this.multiThread}, useSystemDns: ${_this.useSystemDns}, server: ${_this.server})';
}


}

/// @nodoc
abstract mixin class $SpeedTestSettingsCopyWith<$Res>  {
  factory $SpeedTestSettingsCopyWith(SpeedTestSettings value, $Res Function(SpeedTestSettings) _then) = _$SpeedTestSettingsCopyWithImpl;
@useResult
$Res call({
 SpeedTestProvider provider, SpeedTestProtocol protocol, int duration, bool multiThread,@JsonKey(name: 'use-system-dns') bool useSystemDns, SpeedTestNode? server
});


$SpeedTestNodeCopyWith<$Res>? get server;

}
/// @nodoc
class _$SpeedTestSettingsCopyWithImpl<$Res>
    implements $SpeedTestSettingsCopyWith<$Res> {
  _$SpeedTestSettingsCopyWithImpl(this._self, this._then);

  final SpeedTestSettings _self;
  final $Res Function(SpeedTestSettings) _then;

/// Create a copy of SpeedTestSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? provider = null,Object? protocol = null,Object? duration = null,Object? multiThread = null,Object? useSystemDns = null,Object? server = freezed,}) {
  return _then(SpeedTestSettings(
provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as SpeedTestProvider,protocol: null == protocol ? _self.protocol : protocol // ignore: cast_nullable_to_non_nullable
as SpeedTestProtocol,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as int,multiThread: null == multiThread ? _self.multiThread : multiThread // ignore: cast_nullable_to_non_nullable
as bool,useSystemDns: null == useSystemDns ? _self.useSystemDns : useSystemDns // ignore: cast_nullable_to_non_nullable
as bool,server: freezed == server ? _self.server : server // ignore: cast_nullable_to_non_nullable
as SpeedTestNode?,
  ));
}
/// Create a copy of SpeedTestSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SpeedTestNodeCopyWith<$Res>? get server {
    if (_self.server == null) {
    return null;
  }

  return $SpeedTestNodeCopyWith<$Res>(_self.server!, (value) {
    return _then(_self.copyWith(server: value));
  });
}
}


/// Adds pattern-matching-related methods to [SpeedTestSettings].
extension SpeedTestSettingsPatterns on SpeedTestSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SpeedTestSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SpeedTestSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SpeedTestSettings value)  $default,){
final _that = this;
switch (_that) {
case _SpeedTestSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SpeedTestSettings value)?  $default,){
final _that = this;
switch (_that) {
case _SpeedTestSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SpeedTestProvider provider,  SpeedTestProtocol protocol,  int duration,  bool multiThread, @JsonKey(name: 'use-system-dns')  bool useSystemDns,  SpeedTestNode? server)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SpeedTestSettings() when $default != null:
return $default(_that.provider,_that.protocol,_that.duration,_that.multiThread,_that.useSystemDns,_that.server);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SpeedTestProvider provider,  SpeedTestProtocol protocol,  int duration,  bool multiThread, @JsonKey(name: 'use-system-dns')  bool useSystemDns,  SpeedTestNode? server)  $default,) {final _that = this;
switch (_that) {
case _SpeedTestSettings():
return $default(_that.provider,_that.protocol,_that.duration,_that.multiThread,_that.useSystemDns,_that.server);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SpeedTestProvider provider,  SpeedTestProtocol protocol,  int duration,  bool multiThread, @JsonKey(name: 'use-system-dns')  bool useSystemDns,  SpeedTestNode? server)?  $default,) {final _that = this;
switch (_that) {
case _SpeedTestSettings() when $default != null:
return $default(_that.provider,_that.protocol,_that.duration,_that.multiThread,_that.useSystemDns,_that.server);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SpeedTestSettings implements SpeedTestSettings {
  const _SpeedTestSettings({this.provider = SpeedTestProvider.apple, this.protocol = SpeedTestProtocol.http2, this.duration = 10, this.multiThread = true, @JsonKey(name: 'use-system-dns') this.useSystemDns = false, this.server});
  factory _SpeedTestSettings.fromJson(Map<String, dynamic> json) => _$SpeedTestSettingsFromJson(json);

@override@JsonKey() final  SpeedTestProvider provider;
@override@JsonKey() final  SpeedTestProtocol protocol;
@override@JsonKey() final  int duration;
@override@JsonKey() final  bool multiThread;
@override@JsonKey(name: 'use-system-dns') final  bool useSystemDns;
@override final  SpeedTestNode? server;

/// Create a copy of SpeedTestSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SpeedTestSettingsCopyWith<_SpeedTestSettings> get copyWith => __$SpeedTestSettingsCopyWithImpl<_SpeedTestSettings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SpeedTestSettingsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SpeedTestSettings&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.protocol, protocol) || other.protocol == protocol)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.multiThread, multiThread) || other.multiThread == multiThread)&&(identical(other.useSystemDns, useSystemDns) || other.useSystemDns == useSystemDns)&&(identical(other.server, server) || other.server == server));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,provider,protocol,duration,multiThread,useSystemDns,server);
}

@override
String toString() {
    return 'SpeedTestSettings(provider: $provider, protocol: $protocol, duration: $duration, multiThread: $multiThread, useSystemDns: $useSystemDns, server: $server)';
}


}

/// @nodoc
abstract mixin class _$SpeedTestSettingsCopyWith<$Res> implements $SpeedTestSettingsCopyWith<$Res> {
  factory _$SpeedTestSettingsCopyWith(_SpeedTestSettings value, $Res Function(_SpeedTestSettings) _then) = __$SpeedTestSettingsCopyWithImpl;
@override @useResult
$Res call({
 SpeedTestProvider provider, SpeedTestProtocol protocol, int duration, bool multiThread,@JsonKey(name: 'use-system-dns') bool useSystemDns, SpeedTestNode? server
});


@override $SpeedTestNodeCopyWith<$Res>? get server;

}
/// @nodoc
class __$SpeedTestSettingsCopyWithImpl<$Res>
    implements _$SpeedTestSettingsCopyWith<$Res> {
  __$SpeedTestSettingsCopyWithImpl(this._self, this._then);

  final _SpeedTestSettings _self;
  final $Res Function(_SpeedTestSettings) _then;

/// Create a copy of SpeedTestSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? provider = null,Object? protocol = null,Object? duration = null,Object? multiThread = null,Object? useSystemDns = null,Object? server = freezed,}) {
  return _then(_SpeedTestSettings(
provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as SpeedTestProvider,protocol: null == protocol ? _self.protocol : protocol // ignore: cast_nullable_to_non_nullable
as SpeedTestProtocol,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as int,multiThread: null == multiThread ? _self.multiThread : multiThread // ignore: cast_nullable_to_non_nullable
as bool,useSystemDns: null == useSystemDns ? _self.useSystemDns : useSystemDns // ignore: cast_nullable_to_non_nullable
as bool,server: freezed == server ? _self.server : server // ignore: cast_nullable_to_non_nullable
as SpeedTestNode?,
  ));
}

/// Create a copy of SpeedTestSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SpeedTestNodeCopyWith<$Res>? get server {
    if (_self.server == null) {
    return null;
  }

  return $SpeedTestNodeCopyWith<$Res>(_self.server!, (value) {
    return _then(_self.copyWith(server: value));
  });
}
}


/// @nodoc
mixin _$SpeedTestData {

 SpeedTestSettings get settings; List<SpeedTestRecord> get records;
/// Create a copy of SpeedTestData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SpeedTestDataCopyWith<SpeedTestData> get copyWith => _$SpeedTestDataCopyWithImpl<SpeedTestData>(this as SpeedTestData, _$identity);

  /// Serializes this SpeedTestData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SpeedTestData;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SpeedTestData&&(identical(other.settings, _this.settings) || other.settings == _this.settings)&&const DeepCollectionEquality().equals(other.records, _this.records));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SpeedTestData;
  return Object.hash(runtimeType,_this.settings,const DeepCollectionEquality().hash(_this.records));
}

@override
String toString() {
  final _this = this as SpeedTestData;
  return 'SpeedTestData(settings: ${_this.settings}, records: ${_this.records})';
}


}

/// @nodoc
abstract mixin class $SpeedTestDataCopyWith<$Res>  {
  factory $SpeedTestDataCopyWith(SpeedTestData value, $Res Function(SpeedTestData) _then) = _$SpeedTestDataCopyWithImpl;
@useResult
$Res call({
 SpeedTestSettings settings, List<SpeedTestRecord> records
});


$SpeedTestSettingsCopyWith<$Res> get settings;

}
/// @nodoc
class _$SpeedTestDataCopyWithImpl<$Res>
    implements $SpeedTestDataCopyWith<$Res> {
  _$SpeedTestDataCopyWithImpl(this._self, this._then);

  final SpeedTestData _self;
  final $Res Function(SpeedTestData) _then;

/// Create a copy of SpeedTestData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? settings = null,Object? records = null,}) {
  return _then(SpeedTestData(
settings: null == settings ? _self.settings : settings // ignore: cast_nullable_to_non_nullable
as SpeedTestSettings,records: null == records ? _self.records : records // ignore: cast_nullable_to_non_nullable
as List<SpeedTestRecord>,
  ));
}
/// Create a copy of SpeedTestData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SpeedTestSettingsCopyWith<$Res> get settings {
  
  return $SpeedTestSettingsCopyWith<$Res>(_self.settings, (value) {
    return _then(_self.copyWith(settings: value));
  });
}
}


/// Adds pattern-matching-related methods to [SpeedTestData].
extension SpeedTestDataPatterns on SpeedTestData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SpeedTestData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SpeedTestData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SpeedTestData value)  $default,){
final _that = this;
switch (_that) {
case _SpeedTestData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SpeedTestData value)?  $default,){
final _that = this;
switch (_that) {
case _SpeedTestData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SpeedTestSettings settings,  List<SpeedTestRecord> records)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SpeedTestData() when $default != null:
return $default(_that.settings,_that.records);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SpeedTestSettings settings,  List<SpeedTestRecord> records)  $default,) {final _that = this;
switch (_that) {
case _SpeedTestData():
return $default(_that.settings,_that.records);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SpeedTestSettings settings,  List<SpeedTestRecord> records)?  $default,) {final _that = this;
switch (_that) {
case _SpeedTestData() when $default != null:
return $default(_that.settings,_that.records);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SpeedTestData implements SpeedTestData {
  const _SpeedTestData({this.settings = const SpeedTestSettings(),  List<SpeedTestRecord> records = const []}): _records = records;
  factory _SpeedTestData.fromJson(Map<String, dynamic> json) => _$SpeedTestDataFromJson(json);

@override@JsonKey() final  SpeedTestSettings settings;
 final  List<SpeedTestRecord> _records;
@override@JsonKey() List<SpeedTestRecord> get records {
  if (_records is EqualUnmodifiableListView) return _records;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_records);
}


/// Create a copy of SpeedTestData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SpeedTestDataCopyWith<_SpeedTestData> get copyWith => __$SpeedTestDataCopyWithImpl<_SpeedTestData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SpeedTestDataToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SpeedTestData&&(identical(other.settings, settings) || other.settings == settings)&&const DeepCollectionEquality().equals(other.records, _records));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,settings,const DeepCollectionEquality().hash(_records));
}

@override
String toString() {
    return 'SpeedTestData(settings: $settings, records: $records)';
}


}

/// @nodoc
abstract mixin class _$SpeedTestDataCopyWith<$Res> implements $SpeedTestDataCopyWith<$Res> {
  factory _$SpeedTestDataCopyWith(_SpeedTestData value, $Res Function(_SpeedTestData) _then) = __$SpeedTestDataCopyWithImpl;
@override @useResult
$Res call({
 SpeedTestSettings settings, List<SpeedTestRecord> records
});


@override $SpeedTestSettingsCopyWith<$Res> get settings;

}
/// @nodoc
class __$SpeedTestDataCopyWithImpl<$Res>
    implements _$SpeedTestDataCopyWith<$Res> {
  __$SpeedTestDataCopyWithImpl(this._self, this._then);

  final _SpeedTestData _self;
  final $Res Function(_SpeedTestData) _then;

/// Create a copy of SpeedTestData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? settings = null,Object? records = null,}) {
  return _then(_SpeedTestData(
settings: null == settings ? _self.settings : settings // ignore: cast_nullable_to_non_nullable
as SpeedTestSettings,records: null == records ? _self._records : records // ignore: cast_nullable_to_non_nullable
as List<SpeedTestRecord>,
  ));
}

/// Create a copy of SpeedTestData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SpeedTestSettingsCopyWith<$Res> get settings {
  
  return $SpeedTestSettingsCopyWith<$Res>(_self.settings, (value) {
    return _then(_self.copyWith(settings: value));
  });
}
}

// dart format on
