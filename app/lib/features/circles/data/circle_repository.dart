import 'package:supabase_flutter/supabase_flutter.dart';

class Circle {
  const Circle({
    required this.id,
    required this.name,
    required this.inviteCode,
  });

  factory Circle.fromJson(Map<String, dynamic> json) => Circle(
    id: json['id'] as String,
    name: json['name'] as String,
    inviteCode: json['invite_code'] as String,
  );

  final String id;
  final String name;
  final String inviteCode;
}

/// Anggota circle (untuk kelola circle di pengaturan).
class CircleMember {
  const CircleMember({
    required this.userId,
    required this.displayName,
    this.username,
    this.avatarPath,
  });

  factory CircleMember.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>? ?? const {};
    final username = profile['username'] as String?;
    return CircleMember(
      userId: json['user_id'] as String,
      username: username,
      displayName:
          (profile['display_name'] as String?) ?? username ?? 'seseorang',
      avatarPath: profile['avatar_path'] as String?,
    );
  }

  final String userId;
  final String? username;
  final String displayName;
  final String? avatarPath;
}

const circleNameMaxLength = 40;
const inviteCodeLength = 6;

abstract interface class CircleRepository {
  /// Circle yang diikuti user (RLS hanya mengembalikan circle miliknya).
  Future<List<Circle>> myCircles();

  Future<Circle> createCircle(String name);

  Future<Circle> joinCircle(String inviteCode);

  /// Anggota circle, urut dari yang paling dulu gabung.
  Future<List<CircleMember>> members(String circleId);

  /// Keluar circle. Circle yang jadi kosong ikut terhapus di server.
  Future<void> leaveCircle(String circleId);
}

class SupabaseCircleRepository implements CircleRepository {
  SupabaseCircleRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Circle>> myCircles() async {
    final rows = await _client
        .from('circles')
        .select('id, name, invite_code')
        .order('created_at');
    return rows.map(Circle.fromJson).toList();
  }

  @override
  Future<Circle> createCircle(String name) async {
    final row = await _client.rpc('create_circle', params: {'p_name': name});
    return Circle.fromJson(row as Map<String, dynamic>);
  }

  @override
  Future<Circle> joinCircle(String inviteCode) async {
    final row = await _client.rpc(
      'join_circle',
      params: {'invite_code': inviteCode},
    );
    return Circle.fromJson(row as Map<String, dynamic>);
  }

  @override
  Future<List<CircleMember>> members(String circleId) async {
    final rows = await _client
        .from('circle_members')
        .select('user_id, profiles(username, display_name, avatar_path)')
        .eq('circle_id', circleId)
        .order('joined_at');
    return rows.map(CircleMember.fromJson).toList();
  }

  @override
  Future<void> leaveCircle(String circleId) =>
      _client.rpc<void>('leave_circle', params: {'p_circle_id': circleId});
}
