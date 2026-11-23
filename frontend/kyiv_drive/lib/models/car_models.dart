import 'car_color.dart';

class CarBrandModel {
  final String id;
  final String name;

  CarBrandModel({required this.id, required this.name});

  factory CarBrandModel.fromJson(Map<String, dynamic> json) {
    return CarBrandModel(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }
}

class CarModelResponseModel {
  final String id;
  final String name;

  CarModelResponseModel({required this.id, required this.name});

  factory CarModelResponseModel.fromJson(Map<String, dynamic> json) {
    return CarModelResponseModel(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }
}

class CarResponseModel {
  final String id;
  final String brandId;
  final String brandName;
  final String modelId;
  final String modelName;
  final CarColor color;
  final String plateNumber;
  final int passengerCapacity;

  CarResponseModel({
    required this.id,
    required this.brandId,
    required this.brandName,
    required this.modelId,
    required this.modelName,
    required this.color,
    required this.plateNumber,
    required this.passengerCapacity,
  });

  factory CarResponseModel.fromJson(Map<String, dynamic> json) {
    return CarResponseModel(
      id: json['id'] as String,
      brandId: json['brandId'] as String,
      brandName: json['brandName'] as String,
      modelId: json['modelId'] as String,
      modelName: json['modelName'] as String,
      color: CarColorExtension.fromBackend(json['color'] as String),
      plateNumber: json['plateNumber'] as String,
      passengerCapacity: json['passengerCapacity'] as int,
    );
  }
}

class CarInitDataModel {
  final List<CarBrandModel> brands;
  final List<CarResponseModel> myCars;

  CarInitDataModel({required this.brands, required this.myCars});

  factory CarInitDataModel.fromJson(Map<String, dynamic> json) {
    return CarInitDataModel(
      brands: (json['brands'] as List).map((e) => CarBrandModel.fromJson(e)).toList(),
      myCars: (json['myCars'] as List).map((e) => CarResponseModel.fromJson(e)).toList(),
    );
  }
}