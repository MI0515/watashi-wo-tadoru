#!/bin/bash
set -e

# テーブルの準備後に初期データを投入する
./bin/rails db:prepare
./bin/rails db:seed

# 投入後の件数と感情の表示順をログへ出す
./bin/rails runner '
  puts "PersonalityType: #{PersonalityType.count}"
  puts "Companion: #{Companion.count}"
  puts "Monologue: #{Monologue.count}"
  puts "Emotion: #{Emotion.count}"
  pp Emotion.order(:display_order).pluck(:display_order, :name)
'

# 通常のWebサーバーを起動する
exec ./bin/thrust ./bin/rails server