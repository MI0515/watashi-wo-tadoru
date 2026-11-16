class ReflectionPrompt
  STYLE_INSTRUCTIONS = {
    "casual" => "やわらかく落ち着いたタメ口で話してください。「です・ます」調は使わないでください。",
    "polite" => "やわらかく落ち着いた敬語で話してください。「です・ます」調を使い、堅すぎる敬語は避けてください。"
  }.freeze

  def self.call(speaking_style:, final_reply: false)
    common_prompt = Rails.root.join("config/prompts/reflection.txt").read
    style_instruction = STYLE_INSTRUCTIONS.fetch(speaking_style)

    # 最終返信かどうかは、モデルに推測させずアプリから明示する
    turn_instruction =
      if final_reply
        <<~TEXT
          今回は通常対話の最終返信です。
          共通指示の【最終返信】に従ってください。
          ただし、【安全を優先する例外】は最終返信の制約より優先します。
        TEXT
      else
        <<~TEXT
          今回は対話途中の返信です。
          利用者の言葉と状態に合わせて応答してください。
          質問を添える場合は原則として1つにしてください。
        TEXT
      end

    [ common_prompt, style_instruction, turn_instruction ].join("\n\n")
  end
end
