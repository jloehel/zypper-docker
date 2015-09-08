#!/bin/bash

gimme $1
source ~/.gimme/envs/go${1}.env
godep go test -race ./...
climate -open=false -threshold=80.0 -errcheck -vet -fmt
