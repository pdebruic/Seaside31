#!/bin/bash -x
#
#  Sample test driver that allows for customizing build/tests based on env vars defined in .travis.yml
#
#      -verbose flag causes unconditional transcript display
#
# Copyright (c) 2013 VMware, Inc. All Rights Reserved <dhenrich@vmware.com>.
#

echo "--->$TRAVIS_BUILD_DIR"
echo "`pwd`"

if [ "${CONFIGURATION}x" = "x" ]; then
  if [ "${BASELINE}x" = "x" ]; then
    echo "Must specify either BASELINE or CONFIGURATION"
    exit 1
  else
    PROJECT_LINE="  baseline: '${BASELINE}';"
    VERSION_LINE=""
    FULL_CONFIG_NAME="BaselineOf${BASELINE}"
  fi
else
  PROJECT_LINE="  configuration: '${CONFIGURATION}';"
  VERSION_LINE="  version: '$VERSION';"
  FULL_CONFIG_NAME="ConfigurationOf${CONFIGURATION}"
fi

if [ "${REPOSITORY}x" = "x" ]; then
  echo "Must specify REPOSITORY"
  exit 1
fi
REPOSITORY_LINE="  repository: '$REPOSITORY';"

OUTPUT_PATH="${PROJECT_HOME}/tests/travisCI.st"

cat - >> $OUTPUT_PATH << EOF
"Load and run tests to be performed by TravisCI"
Transcript cr; show: 'travis---->travisCI.st'.

GsDeployer deploy: [
  | glassVersion |
  glassVersion := ConfigurationOfGLASS project currentVersion.
  glassVersion versionNumber < '1.0-beta.9.3' asMetacelloVersionNumber
    ifTrue: [
      Transcript
        cr;
        show: '-----Upgrading GLASS to 1.0-beta.9.3'.
      GsDeployer deploy: [
        Gofer new
          package: 'ConfigurationOfGLASS';
          url: 'http://seaside.gemtalksystems.com/ss/MetacelloRepository';
          load.
        (((System stoneVersionAt: 'gsVersion') beginsWith: '2.') and: [glassVersion versionNumber < '1.0-beta.9.2' asMetacelloVersionNumber])
          ifTrue: [
            ((Smalltalk at: #ConfigurationOfGLASS) project version: '1.0-beta.9.2') load ].
        ((Smalltalk at: #ConfigurationOfGLASS) project version: '1.0-beta.9.3') load.
      ] ]
    ifFalse: [
      Transcript
        cr;
        show: '-----GLASS already upgraded to 1.0-beta.9.3' ] ].

GsDeployer deploy: [
  "Explicitly load latest Grease configuration, since we're loading the #bleeding edge"
  Metacello new
    configuration: 'Grease';
    repository: 'http://www.smalltalkhub.com/mc/Seaside/MetacelloConfigurations/main';
    get.

  "Load the configuration or baseline"
  Metacello new
  $PROJECT_LINE
  $VERSION_LINE
  $REPOSITORY_LINE
    load: #( ${LOADS} )
].

"Run the tests"
  TravisCIHarness
    value: #( '${FULL_CONFIG_NAME}' )
    value: 'TravisCISuccess.txt' 
    value: 'TravisCIFailure.txt'.
EOF

cat $OUTPUT_PATH

$BUILDER_CI_HOME/testTravisCI.sh "$@"
if [[ $? != 0 ]] ; then exit 1; fi