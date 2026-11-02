#!/bin/bash
set -e

# テストメールの送信に成功したら、通常の起動処理へ進む
./bin/rails runner script/verify_brevo.rb
exec /rails/bin/docker-entrypoint ./bin/thrust ./bin/rails server
