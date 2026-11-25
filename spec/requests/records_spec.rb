require "rails_helper"

RSpec.describe "保存済みの振り返り記録", type: :request do
  let(:companion) { create(:companion) }
  let(:user) do
    create(
      :user,
      nickname: "七海",
      personality_type: companion.personality_type,
      companion: companion
    )
  end
  let(:record_attributes) do
    {
      user: user,
      companion: companion,
      status: :completed,
      completed_at: Time.zone.local(2026, 11, 25, 12, 0),
      title: "話を聞いてほしかった気持ち",
      insight: "相談せずに決められたことが引っかかっていた。"
    }
  end

  before do
    post user_session_path, params: {
      user: { email: user.email, password: "test123" }
    }
  end

  it "本人の保存済み記録だけを、保存日時とIDの新しい順に表示する" do
    older = create(
      :reflection,
      **record_attributes,
      completed_at: record_attributes[:completed_at] - 1.day
    )
    newer = create(:reflection, **record_attributes)
    same_time = create(:reflection, **record_attributes)

    create(:reflection, user: user, companion: companion)
    create(
      :reflection,
      **record_attributes,
      user: create(:user)
    )

    get records_path

    expect(response).to have_http_status(:ok)
    links = response.parsed_body.css(".record-item").map { |link| link["href"] }
    expect(links).to eq([
      record_path(same_time),
      record_path(newer),
      record_path(older)
    ])
  end

  it "記録がない場合は振り返り開始への案内を表示する" do
    get records_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("保存した記録はまだありません。")
    expect(response.parsed_body.at_css(
      '.records-empty a[href="' + new_reflection_path + '"]'
    )).to be_present
  end

  it "詳細に保存内容・選択感情・任意メモを表示する" do
    emotion = create(:emotion)
    record = create(
      :reflection,
      **record_attributes,
      emotions: [ emotion ],
      personal_note: "決める前に一言相談してほしかった。"
    )

    get record_path(record)

    expect(response).to have_http_status(:ok)
    doc = response.parsed_body
    expect(doc.at_css("#record-title").text).to eq(record.title)
    expect(doc.at_css(".record-date")["datetime"])
      .to eq(record.completed_at.iso8601)
    expect(doc.css(".record-content").map(&:text)).to eq([
      record.initial_text,
      record.insight,
      record.personal_note
    ])
        expect(doc.css(".feeling-tags li").map(&:text)).to eq([ emotion.name ])
  end

  it "感情が未選択なら選択なしと表示し、空の任意メモ欄は表示しない" do
    record = create(:reflection, **record_attributes)

    get record_path(record)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("選択なし")
    expect(response.body).not_to include("自分の言葉で残しておきたいこと")
  end

  it "現在のミツメイトを変更しても、記録には当時のミツメイトを表示する" do
    record = create(:reflection, **record_attributes)
    new_companion = create(
      :companion,
      personality_type: companion.personality_type,
      appearance_type: "female",
      sd_image_path: "companions/intp-female-sd.png",
      full_image_path: "companions/intp-female-full.png"
    )
    user.update!(companion: new_companion)

    get records_path

    expect(response.parsed_body.at_css(".record-mate-badge").text)
      .to eq("INTP・動物")
    expect(response.parsed_body.at_css(".record-avatar img")["src"])
      .to include("nt-animal-icon")

    get record_path(record)

    expect(response.parsed_body.at_css(".record-mate-copy strong").text)
      .to eq("INTP・動物")
    expect(response.parsed_body.at_css(".record-mate-figure img")["src"])
      .to include("nt-animal-sd")
  end

  it "他人の記録や対話中の振り返りは詳細を表示しない" do
    other_record = create(
      :reflection,
      **record_attributes,
      user: create(:user)
    )
    ongoing = create(:reflection, user: user, companion: companion)

    get record_path(other_record)
    expect(response).to have_http_status(:not_found)

    get record_path(ongoing)
    expect(response).to have_http_status(:not_found)
  end

  it "未ログインでは一覧・詳細を表示しない" do
    record = create(:reflection, **record_attributes)
    delete destroy_user_session_path

    get records_path
    expect(response).to redirect_to(new_user_session_path)

    get record_path(record)
    expect(response).to redirect_to(new_user_session_path)
  end
end
