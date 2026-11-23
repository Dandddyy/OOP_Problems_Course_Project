import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../models/car_models.dart';

class CarApiService {
  final Dio _dio;

  CarApiService(this._dio);

  Future<CarInitDataModel> getInitData() async {
    final response = await _dio.get('${ApiConstants.carsEndpoint}/init');
    return CarInitDataModel.fromJson(response.data);
  }

  Future<List<CarModelResponseModel>> getModels({
    required String brandId,
  }) async {
    final response = await _dio.get(
      '${ApiConstants.carsEndpoint}/models',
      queryParameters: {'brandId': brandId},
    );
    return (response.data as List)
        .map((e) => CarModelResponseModel.fromJson(e))
        .toList();
  }

  Future<CarResponseModel> addCar({
    required String brandId,
    required String modelName,
    required String color,
    required String plateNumber,
    required int passengerCapacity,
  }) async {
    final response = await _dio.post(
      ApiConstants.carsEndpoint,
      data: {
        "brandId": brandId,
        "modelName": modelName,
        "color": color,
        "plateNumber": plateNumber,
        "passengerCapacity": passengerCapacity,
      },
    );
    return CarResponseModel.fromJson(response.data);
  }

  Future<void> deleteCar(String carId) async {
    await _dio.delete('${ApiConstants.carsEndpoint}/$carId');
  }

  Future<CarResponseModel> updateCar({
    required String carId,
    required String brandId,
    required String modelName,
    required String color,
    required String plateNumber,
    required int passengerCapacity,
  }) async {
    final response = await _dio.put(
      '${ApiConstants.carsEndpoint}/$carId',
      data: {
        'brandId': brandId,
        'modelName': modelName,
        'color': color,
        'plateNumber': plateNumber,
        'passengerCapacity': passengerCapacity,
      },
    );
    return CarResponseModel.fromJson(response.data);
  }
}
