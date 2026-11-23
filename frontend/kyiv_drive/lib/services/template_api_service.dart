import 'package:dio/dio.dart';

import '../core/constants/api_constants.dart';
import '../models/template_model.dart';

class TemplateApiService {
  final Dio _dio;

  TemplateApiService(this._dio);

  Future<TemplateCreateResponseModel> createTemplate(
    CreateTemplateRequestModel request,
  ) async {
    final response = await _dio.post(
      ApiConstants.templateEndpoint,
      data: request.toJson(),
    );
    return TemplateCreateResponseModel.fromJson(_jsonObject(response.data));
  }

  Future<List<TemplateResponseModel>> getTemplates({
    required bool isDriver,
  }) async {
    final response = await _dio.get(
      ApiConstants.templateEndpoint,
      queryParameters: {'is_driver': isDriver},
    );

    final data = response.data;
    if (data is! List) {
      throw const FormatException('Expected a JSON array of templates');
    }

    return data
        .map((item) => TemplateResponseModel.fromJson(_jsonObject(item)))
        .toList();
  }

  Future<TemplateMutationResponseModel> deleteTemplate(
    String templateId,
  ) async {
    final response = await _dio.delete(
      '${ApiConstants.templateEndpoint}/$templateId',
    );
    return TemplateMutationResponseModel.fromJson(_jsonObject(response.data));
  }
}

Map<String, dynamic> _jsonObject(Object? data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);

  throw const FormatException('Expected a JSON object response');
}
