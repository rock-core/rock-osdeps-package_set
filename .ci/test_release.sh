#!/bin/bash
RELEASE_NAME=$1

source /home/docker/releases/$RELEASE_NAME/env.sh

validate_availability()
{
    PATH_TO_BIN=`which $1`
    if [ ! $? -eq 0 ]; then
        echo "$1 is not available"
        exit 1
    else
        echo "$1 found: $PATH_TO_BIN"
    fi
}

# Program to test for availability
rock-log-level

validate_availability orogen
orogen --help

validate_availability rock-display

