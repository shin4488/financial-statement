#!/bin/bash

# node_modulesはコンテナ専用ボリュームにあるため、ホストでlockfileが変わっても自動では追随しない。
# 起動のたびに同期する（差分が無ければ "Already up-to-date" ですぐ終わる）
yarn install --frozen-lockfile

yarn watch &
yarn start
