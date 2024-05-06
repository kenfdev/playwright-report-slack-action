#!/bin/bash

# Fail script on any error
set -e

json_path=$RESULTS_JSON_PATH
artifact_url=$ARTIFACT_URL

# Parse JSON to build the Slack message payload
payload=$(jq -r --arg artifact_url "$artifact_url" '
# Initialize counters for passed and failed tests
reduce (.suites[] | (if .specs then .specs[] else empty end), (if .suites then .suites[].specs[] else empty end)) as $spec (
  {
    passed: 0,
    failed: 0,
    blocks: [
      {
        type: "header",
        text: {
          type: "plain_text",
          text: "Playwright Test Results"
        }
      }
    ],
    failed_tests: [] # Use an array to store failed tests temporarily
  };
  # Update counters and collect failed test titles
  $spec.tests[] as $test |
    if $test.results[0].status == "passed" then
      .passed += 1
    else
      .failed += 1 | .failed_tests += [{
        type: "section",
        text: {
          type: "mrkdwn",
          text: "✘ \($spec.title)"
        }
      }]
    end
) |
# Add the summary section right after the header
.blocks += [{
  type: "context",
  elements: [
    {
      type: "mrkdwn",
      text: ":large_green_circle: *Passed:* \(.passed)"
    },
    {
      type: "mrkdwn",
      text: ":red_circle: *Failed:* \(.failed)"
    },
    # Conditionally add the artifact URL if provided
    (if $artifact_url != "" then
      {
        type: "mrkdwn",
        text: "<\($artifact_url)|Download>"
      }
    else
      {
        type: "mrkdwn",
        text: " "
      }
    end)
  ]
}] |
# Append failed tests after the summary section
.blocks += .failed_tests |
# Output only the blocks array
{blocks: .blocks}
' $json_path)

echo $payload > payload-slack-content.json