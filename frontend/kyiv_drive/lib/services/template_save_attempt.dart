import 'dart:convert';

import '../models/template_model.dart';
import '../utils/uuid.dart';

class TemplateSaveAttempt {
  String? _payload;
  CreateTemplateRequestModel? _request;

  void reset() {
    _payload = null;
    _request = null;
  }

  CreateTemplateRequestModel prepare({
    required TemplateCreateRequestModel template,
    required List<TemplateStopCreateRequestModel> stops,
  }) {
    final payload = jsonEncode({
      'template': template.toJson(),
      'stops': stops.map((stop) => stop.toJson()).toList(),
    });
    if (_payload != payload) {
      _request = CreateTemplateRequestModel(
        requestId: generateUuidV4(),
        template: template,
        stops: List.unmodifiable(stops),
      );
      _payload = payload;
    }

    return _request!;
  }
}
