import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../models/user_rating_model.dart';

class UserApiService {
  final Dio _dio;

  UserApiService(this._dio);

  Future<UserRatingModel> getUserRating() async {
    final response = await _dio.get(ApiConstants.userRatingEndpoint);
    return UserRatingModel.fromJson(response.data as Map<String, dynamic>);
  }
}