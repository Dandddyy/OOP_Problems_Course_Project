package ua.kyiv.drive.kyiv_drive.service;

import tools.jackson.databind.JsonNode;

import java.util.ArrayList;
import java.util.List;

/** Travel times along an existing route; stops never become OSRM waypoints. */
final class RouteTimingProfile {
    private final List<Leg> legs;
    private final double distance;
    private final double duration;

    private RouteTimingProfile(List<Leg> legs, double distance, double duration) {
        this.legs = List.copyOf(legs);
        this.distance = distance;
        this.duration = duration;
    }

    static RouteTimingProfile from(JsonNode route) {
        List<Leg> legs = new ArrayList<>();
        double distance = 0;
        double duration = 0;
        for (JsonNode node : requiredArray(route, "legs")) {
            Leg leg = Leg.from(node);
            legs.add(leg);
            distance += leg.segments().distance();
            duration += leg.duration();
        }
        double routeDuration = nonNegativeNumber(route.path("duration"));
        requireMatchingDuration(duration, routeDuration);
        if (distance <= 0) {
            throw invalidTiming("Route annotations have no distance");
        }
        return new RouteTimingProfile(legs, distance, routeDuration);
    }

    int etaSeconds(double routeFraction) {
        if (!Double.isFinite(routeFraction) || routeFraction < 0 || routeFraction > 1) {
            throw invalidTiming("Stop position is outside the route");
        }
        if (routeFraction == 0) {
            return 0;
        }

        // PostGIS supplies a position along the projected route. Locate the same
        // relative distance in OSRM's annotation distances, retaining the existing
        // stop selection and its small projection/geometry rounding differences.
        double remainingDistance = routeFraction * distance;
        double elapsed = 0;
        for (Leg leg : legs) {
            if (remainingDistance < leg.segments().distance()) {
                double eta = elapsed + leg.durationAt(remainingDistance);
                return (int) Math.round(Math.min(duration, Math.max(0, eta)));
            }
            remainingDistance -= leg.segments().distance();
            elapsed += leg.duration();
        }
        return (int) Math.round(duration);
    }

    private record Leg(SegmentTimes segments, List<Step> steps, double stepDistance, double duration) {
        static Leg from(JsonNode node) {
            SegmentTimes segments = SegmentTimes.from(node.path("annotation"));
            List<Step> steps = new ArrayList<>();
            double distance = 0;
            double duration = 0;
            for (JsonNode stepNode : requiredArray(node, "steps")) {
                Step step = new Step(nonNegativeNumber(stepNode.path("distance")),
                        nonNegativeNumber(stepNode.path("duration")));
                steps.add(step);
                distance += step.distance();
                duration += step.duration();
            }
            requireMatchingDuration(duration, nonNegativeNumber(node.path("duration")));
            if (segments.distance() > 0 && distance <= 0) {
                throw invalidTiming("OSRM steps have no distance");
            }
            return new Leg(segments, List.copyOf(steps), distance, duration);
        }

        double durationAt(double distance) {
            double startDistance = 0;
            double elapsed = 0;
            for (Step step : steps) {
                // Step distances are rounded by OSRM. Align their cumulative
                // positions to the unrounded annotation distances within this leg.
                double endDistance = startDistance + step.distance() * segments.distance() / stepDistance;
                if (distance < endDistance) {
                    double startTime = segments.durationAt(startDistance);
                    double travelTime = segments.durationAt(endDistance) - startTime;
                    double fraction = travelTime > 0
                            ? (segments.durationAt(distance) - startTime) / travelTime
                            : (distance - startDistance) / (endDistance - startDistance);

                    // Annotations omit turn costs; step.duration includes them.
                    // Distribute that difference by segment travel time only within
                    // this step. Completed steps retain their full OSRM duration.
                    return elapsed + Math.clamp(fraction, 0, 1) * step.duration();
                }
                startDistance = endDistance;
                elapsed += step.duration();
            }
            return duration;
        }
    }

    private record Step(double distance, double duration) {
    }

    private record SegmentTimes(double[] distances, double[] durations) {
        static SegmentTimes from(JsonNode annotation) {
            JsonNode distances = requiredArray(annotation, "distance");
            JsonNode durations = requiredArray(annotation, "duration");
            if (distances.size() != durations.size()) {
                throw invalidTiming("OSRM annotation arrays have different lengths");
            }
            double[] cumulativeDistances = new double[distances.size() + 1];
            double[] cumulativeDurations = new double[durations.size() + 1];
            for (int index = 0; index < distances.size(); index++) {
                cumulativeDistances[index + 1] = cumulativeDistances[index]
                        + nonNegativeNumber(distances.get(index));
                cumulativeDurations[index + 1] = cumulativeDurations[index]
                        + nonNegativeNumber(durations.get(index));
            }
            return new SegmentTimes(cumulativeDistances, cumulativeDurations);
        }

        double distance() {
            return distances[distances.length - 1];
        }

        double durationAt(double distance) {
            if (distance <= 0) {
                return 0;
            }
            if (distance >= distance()) {
                return durations[durations.length - 1];
            }
            // Find the first segment endpoint strictly beyond the target. This
            // also skips repeated coordinates without dividing by zero.
            int low = 1;
            int high = distances.length - 1;
            while (low < high) {
                int middle = (low + high) / 2;
                if (distances[middle] <= distance) {
                    low = middle + 1;
                } else {
                    high = middle;
                }
            }
            int start = low - 1;
            double fraction = (distance - distances[start]) / (distances[low] - distances[start]);
            return durations[start] + fraction * (durations[low] - durations[start]);
        }
    }

    private static JsonNode requiredArray(JsonNode node, String name) {
        JsonNode array = node.path(name);
        if (!array.isArray() || array.isEmpty()) {
            throw invalidTiming("Missing OSRM " + name + " array");
        }
        return array;
    }

    private static double nonNegativeNumber(JsonNode node) {
        if (!node.isNumber()) {
            throw invalidTiming("OSRM timing metric is not a number");
        }
        double value = node.asDouble();
        if (!Double.isFinite(value) || value < 0) {
            throw invalidTiming("OSRM timing metric must be finite and non-negative");
        }
        return value;
    }

    private static void requireMatchingDuration(double actual, double expected) {
        if (Math.abs(actual - expected) > 1) {
            throw invalidTiming("OSRM route, leg and step durations do not match");
        }
    }

    private static IllegalStateException invalidTiming(String message) {
        return new IllegalStateException(message);
    }
}
