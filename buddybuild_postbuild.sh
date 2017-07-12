#!/usr/bin/env bash

if [[ "$BUDDYBUILD_TRIGGERED_BY" == webhook_pull_request* ]]; then
    echo "This is a pull request. No deployment will be done."
    exit 0
fi

if [[ "$BUDDYBUILD_BRANCH" == "master" ]]; then
  echo "Uploading staging app HockeyApp..."

  curl \
    -F "status=2" \
    -F "notify=0" \
    -F "ipa=@$BUDDYBUILD_IPA_PATH" \
    -H "X-HockeyAppToken: $HOCKEY_APP_TOKEN" \
    https://rink.hockeyapp.net/api/2/apps/$HOCKEY_APP_ID/app_versions

  echo "Finished uploading to HockeyApp."
fi