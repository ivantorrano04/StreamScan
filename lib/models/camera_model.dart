import 'dart:convert';

class CameraMetaInfo {
  final String? status;
  final String? country;
  final String? countryCode;
  final String? region;
  final String? regionName;
  final String? city;
  final String? zip;
  final double? lat;
  final double? lon;
  final String? timezone;
  final String? isp;
  final String? org;
  final String? model;
  final String? asName;
  final String? query;

  CameraMetaInfo({
    this.status,
    this.country,
    this.countryCode,
    this.region,
    this.regionName,
    this.city,
    this.zip,
    this.lat,
    this.lon,
    this.timezone,
    this.isp,
    this.org,
    this.asName,
    this.query,
    this.model
  });

  factory CameraMetaInfo.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    return CameraMetaInfo(
      status: json['status'] as String?,
      country: json['country'] as String?,
      countryCode: json['countryCode'] as String?,
      region: json['region'] as String?,
      regionName: json['regionName'] as String?,
      city: json['city'] as String?,
      zip: json['zip'] as String?,
      lat: parseDouble(json['lat']),
      lon: parseDouble(json['lon']),
      timezone: json['timezone'] as String?,
      isp: json['isp'] as String?,
      model: json['model'] as String?,
      org: json['org'] as String?,
      asName: json['as'] as String?,
      query: json['query'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'country': country,
        'countryCode': countryCode,
        'region': region,
        'regionName': regionName,
        'city': city,
        'zip': zip,
        'lat': lat,
        'lon': lon,
        'timezone': timezone,
        'isp': isp,
        'model': model,
        'org': org,
        'as': asName,
        'query': query,
      };
}

class CameraInfo {
  final String url;
  final String? estado;
  final String? importancia;
  CameraMetaInfo? info;
  bool? requiresAuth;
  bool? useFullWeb;
  String? authUser;
  String? authPass;

  CameraInfo({
    required this.url,
    this.estado,
    this.importancia,
    this.info,
    this.requiresAuth,
    this.useFullWeb,
    this.authUser,
    this.authPass,
  });

  factory CameraInfo.fromJson(Map<String, dynamic> json) {
    CameraMetaInfo? meta;
    if (json['info'] != null && json['info'] is Map) {
      meta = CameraMetaInfo.fromJson(Map<String, dynamic>.from(json['info']));
    }

    return CameraInfo(
      url: json['url']?.toString() ?? '',
      estado: json['estado'] as String?,
      importancia: json['importancia'] as String?,
      info: meta,
      requiresAuth: json['requiresAuth'] == true || (json['requiresAuth']?.toString().toLowerCase() == 'true'),
      useFullWeb: json['useFullWeb'] == true || (json['useFullWeb']?.toString().toLowerCase() == 'true'),
      authUser: json['authUser'] as String?,
      authPass: json['authPass'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'estado': estado,
        'importancia': importancia,
      'info': info?.toJson(),
      'requiresAuth': requiresAuth,
      'useFullWeb': useFullWeb,
      'authUser': authUser,
      'authPass': authPass,
      };

  @override
  String toString() => jsonEncode(toJson());
}
