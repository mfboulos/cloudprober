#!/bin/bash -eu
#
# Copyright 2017 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script builds cloudprober from source. This is primarily required to
# generate Go code for the config protobufs used by various Cloudprober
# modules.

PROTOC_VERSION="3.3.0"
PROJECT="github.com/google/cloudprober"

GOPATH=$(go env GOPATH)

if [ -z "$GOPATH" ]; then
  echo "Go environment is not setup correctly. Please look at"
  echo "https://golang.org/doc/code.html to set up Go environment."
  exit 1
fi

# Change directory to the project workspace in GOPATH
project_dir="${GOPATH}/src/${PROJECT}"

if [ ! -d "${project_dir}" ];then
  echo "${PROJECT} not found under Go workspace: ${GOPATH}/src. Please download"
  echo " cloudprober source code from github.com/google/cloudprober and set it "
  echo "such that it's available at ${project_dir}."
  exit 1
fi

# Make sure protobuf compilation is set up correctly.
export protoc_path=$(which protoc)
if [ -z ${protoc_path} ] || [ ! -x  ${protoc_path} ]; then
  echo "protoc (protobuf compiler) not found on the path. Trying to install it "
  echo "from the internet. To avoid repeating this step, please install protoc"
  echo " from https://github.com/google/protobuf, at a system-wide location, "
  echo "that is accessible through PATH environment variable."
  echo "======================================================================"
  sleep 1

  if [ "$(uname -s)" == "Darwin" ]; then
    os="osx"
  elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
    os="linux"
  else
    echo "OS unsupported by this this build script. Please install protoc manually."
  fi
  arch=$(uname -m)
  protoc_package="protoc-${PROTOC_VERSION}-${os}-${arch}.zip"
  protoc_package_url="https://github.com/google/protobuf/releases/download/v${PROTOC_VERSION}/${protoc_package}"

  TMPDIR=$(mktemp -d)
  cd $TMPDIR
  echo -e "Downloading protobuf compiler from..\n${protoc_package_url}"
  echo "======================================================================"
  wget "${protoc_package_url}"
  unzip "${protoc_package}"
  export protoc_path=${PWD}/bin/protoc
  cd -

  function cleanup {
    echo "Removing temporary directory used for protoc installation: ${TMPDIR}"
    rm  -r "${TMPDIR}"
  }
  trap cleanup EXIT
fi

# Get go plugin for protoc
go get github.com/golang/protobuf/protoc-gen-go

echo "Generating Go code for protobufs.."
echo "======================================================================"
# Generate protobuf code from the root directory to ensure proper import paths.
(
  cd $GOPATH/src
  find $PROJECT -name "*.proto" | \
    while read -r file
    do
      dir=$(basename $(dirname $file))
      ${protoc_path} --go_out=.,import_path=$dir:. $file
    done
)

cd ${project_dir}
# Get all dependencies
echo "Getting all the dependencies.."
echo "======================================================================"
go get -t ./...

# Build everything
echo "Build everything..."
echo "======================================================================"
go build ./...

# Run tests
echo "Running tests..."
echo "======================================================================"
go test ./...

# Install cloudprober
echo "Build static cloudprober binary.."
echo "======================================================================"
CGO_ENABLED=0 go build -ldflags '-extldflags "-static"' ./cmd/cloudprober.go
