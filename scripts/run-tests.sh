#!/usr/bin/env bash

set -euo pipefail

solution_path="${TEST_SOLUTION_PATH:-DevSecOpsPipelineSample.slnx}"
configuration="${TEST_CONFIGURATION:-Release}"
results_directory="${TEST_RESULTS_DIRECTORY:-TestResults}"
coverage_output_format="${TEST_COVERAGE_OUTPUT_FORMAT:-coverage}"
coverage_output="${TEST_COVERAGE_OUTPUT:-coverage.coverage}"
additional_coverage_output_format="${TEST_ADDITIONAL_COVERAGE_OUTPUT_FORMAT-cobertura}"
additional_coverage_output="${TEST_ADDITIONAL_COVERAGE_OUTPUT-coverage.cobertura.xml}"
verbosity="${TEST_VERBOSITY:-minimal}"
no_build="${TEST_NO_BUILD:-true}"

args=(
  test
  --solution "$solution_path"
  --configuration "$configuration"
  --results-directory "$results_directory"
  --report-trx
  --coverage
  --coverage-output-format "$coverage_output_format"
  --coverage-output "$coverage_output"
  --verbosity "$verbosity"
)

if [[ "$no_build" == "true" ]]; then
  args+=(--no-build)
fi

dotnet "${args[@]}"

if [[ -n "$additional_coverage_output_format" && -n "$additional_coverage_output" ]]; then
  dotnet tool run dotnet-coverage merge \
    -o "$results_directory/$additional_coverage_output" \
    -f "$additional_coverage_output_format" \
    "$results_directory/$coverage_output"
fi