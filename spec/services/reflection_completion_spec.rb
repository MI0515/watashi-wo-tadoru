require "rails_helper"

RSpec.describe ReflectionCompletion do
  let(:reflection) do
    create(
      :reflection,
      title: "会話のあと",
      insight: "自分の話も聞いてほしかったのかもしれない"
    )
  end
  let(:service) { described_class.new(reflection: reflection) }

  it "400文字のメモと完了状態・日時を保存する" do
    note = "あ" * 400

    expect(service.call(personal_note: note)).to eq(reflection)

    expect(reflection.reload.personal_note).to eq(note)
    expect(reflection).to be_completed
    expect(reflection.completed_at).to be_present
    expect(reflection.insight).to eq("自分の話も聞いてほしかったのかもしれない")
  end

  it "メモが空白だけでも保存を完了できる" do
    service.call(personal_note: "   ")

    expect(reflection.reload).to be_completed
    expect(reflection.personal_note).to be_nil
  end

  it "401文字のメモでは入力を保持し、DBの保存を完了しない" do
    note = "あ" * 401

    expect {
      service.call(personal_note: note)
    }.to raise_error(ActiveRecord::RecordInvalid)

    expect(reflection.personal_note).to eq(note)
    expect(reflection.reload).to be_in_progress
    expect(reflection.completed_at).to be_nil
    expect(reflection.personal_note).to be_nil
  end

  it "再送でメモと完了日時を上書きしない" do
    service.call(personal_note: "最初のメモ")
    saved = reflection.reload.attributes.slice("personal_note", "completed_at", "updated_at")

    service.call(personal_note: "再送されたメモ")

    expect(reflection.reload.attributes.slice(*saved.keys)).to eq(saved)
  end

  it "まとめがなければ保存を完了できない" do
    reflection.update!(title: nil, insight: nil)

    expect {
      service.call(personal_note: "メモ")
    }.to raise_error(described_class::NotReadyError)

    expect(reflection.reload).to be_in_progress
  end
end
