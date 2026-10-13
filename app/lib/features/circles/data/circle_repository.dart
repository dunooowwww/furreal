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

const circleNameMaxLength = 40;
const inviteCodeLength = 6;

abstract interface class CircleRepository {
  /// Circle yang diikuti user (RLS hanya mengembalikan circle miliknya).
  Future<List<Circle>> myCircles();

  Future<Circle> createCircle(String name);

  Future<Circle> joinCircle(String inviteCode);
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
}
