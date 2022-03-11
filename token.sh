#!/bin/bash

TOKEN=$(echo $(($RANDOM*$RANDOM*$RANDOM)) | base64 | sed 's/=//g' | head -c 20; echo) && echo "{ \"token\": \"${TOKEN}\" }"
