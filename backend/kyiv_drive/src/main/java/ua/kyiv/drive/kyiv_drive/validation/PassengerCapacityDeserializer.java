package ua.kyiv.drive.kyiv_drive.validation;

import tools.jackson.core.JsonParser;
import tools.jackson.core.JsonToken;
import tools.jackson.databind.DeserializationContext;
import tools.jackson.databind.ValueDeserializer;

public class PassengerCapacityDeserializer extends ValueDeserializer<Short> {
    @Override
    public Short deserialize(JsonParser parser, DeserializationContext context) {
        if (parser.hasToken(JsonToken.VALUE_NUMBER_FLOAT)) {
            return (Short) context.handleUnexpectedToken(Short.class, parser);
        }
        return context.readValue(parser, Short.class);
    }
}
