#!/bin/bash

MODULE_DIR=/home/app/financialStatement/node_modules

if [ ! -d $MODULE_DIR ] || [ -z "$(ls $MODULE_DIR)" ]; then
  yarn install
fi

yarn watch &
yarn start
