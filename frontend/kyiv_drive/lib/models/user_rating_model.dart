class UserRatingModel {
  final String name;
  final String? avatarUrl;
  final double rating;
  final int ratingCount;

  UserRatingModel({
    required this.name,
    required this.avatarUrl,
    required this.rating,
    required this.ratingCount,
  });

  factory UserRatingModel.fromJson(Map<String, dynamic> json) {
    return UserRatingModel(
      name: json['name'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      rating: (json['rating'] as num).toDouble(),
      ratingCount: json['ratingCount'] as int,
    );
  }
}
