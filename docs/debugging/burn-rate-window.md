# Debugging story: a single error window produced noisy pages

## Symptom

The original rule paged whenever the five-minute 5xx ratio exceeded 5%. A short controlled spike
could page even when the longer service trend was healthy.

## Diagnosis and fix

The rule mixed an error-ratio threshold with the language of error-budget burn. The replacement
calculates burn against the 0.5% budget and requires 5-minute and 1-hour signals together.

## Prevention

The deterministic fixture must transition from healthy to breached and back to recovered, while
contract tests verify both Prometheus windows and thresholds.
