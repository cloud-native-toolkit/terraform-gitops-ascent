#!/bin/bash

echo $RANDOM > /dev/null; TOKEN=$(echo $RANDOM | shasum | head -c 20; echo) && echo "{ \"token\": \"${TOKEN}\" }"