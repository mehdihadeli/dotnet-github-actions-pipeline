#!/usr/bin/env bash

set -euo pipefail

solution_path="${TEST_SOLUTION_PATH:-DevSecOpsPipelineSample.slnx}"
test_filter_queries="${TEST_FILTER_QUERIES:-}"
configuration="${TEST_CONFIGURATION:-Release}"
results_directory="${TEST_RESULTS_DIRECTORY:-TestResults}"
coverage_output_format="${TEST_COVERAGE_OUTPUT_FORMAT:-coverage}"
coverage_output="${TEST_COVERAGE_OUTPUT:-coverage.coverage}"
additional_coverage_output_format="${TEST_ADDITIONAL_COVERAGE_OUTPUT_FORMAT-cobertura}"
additional_coverage_output="${TEST_ADDITIONAL_COVERAGE_OUTPUT-coverage.cobertura.xml}"
verbosity="${TEST_VERBOSITY:-minimal}"
no_build="${TEST_NO_BUILD:-true}"

mkdir -p "$results_directory"

run_solution_test() {
  local target_results_directory="$1"
  local target_coverage_output="$2"
  local filter_query="${3:-}"

  local args=(
    test
    --solution "$solution_path"
    --configuration "$configuration"
    --results-directory "$target_results_directory"
    --report-trx
    --coverage
    --coverage-output-format "$coverage_output_format"
    --coverage-output "$target_coverage_output"
    --verbosity "$verbosity"
  )

  if [[ "$no_build" == "true" ]]; then
    args+=(--no-build)
  fi

  if [[ -n "$filter_query" ]]; then
    args+=(-- --filter-query "$filter_query" --ignore-exit-code 8)
  fi

  dotnet "${args[@]}"
}

merge_primary_coverage() {
  local target_output_path="$1"
  shift

  dotnet tool run dotnet-coverage merge \
    -o "$target_output_path" \
    -f "$coverage_output_format" \
    "$@"
}

if [[ -n "$test_filter_queries" ]]; then
  coverage_inputs=()
  run_index=0

  while IFS= read -r filter_query; do
    if [[ -z "$filter_query" ]]; then
      continue
    fi

    run_index=$((run_index + 1))
    run_results_directory="$results_directory/run-$run_index"
    mkdir -p "$run_results_directory"

    run_solution_test "$run_results_directory" "$coverage_output" "$filter_query"
    coverage_inputs+=("$run_results_directory/$coverage_output")
  done <<< "$test_filter_queries"

  if [[ ${#coverage_inputs[@]} -eq 0 ]]; then
    echo "No TEST_FILTER_QUERIES entries were provided."
    exit 1
  fi

  merge_primary_coverage "$results_directory/$coverage_output" "${coverage_inputs[@]}"
else
  run_solution_test "$results_directory" "$coverage_output"
fi

if [[ -n "$additional_coverage_output_format" && -n "$additional_coverage_output" ]]; then
  dotnet tool run dotnet-coverage merge \
    -o "$results_directory/$additional_coverage_output" \
    -f "$additional_coverage_output_format" \
    "$results_directory/$coverage_output"
fi