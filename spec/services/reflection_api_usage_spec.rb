require "rails_helper"

RSpec.describe "対話処理とAPI利用履歴の連携" do
  let(:reflection) { create(:reflection) }
  let(:client) { instance_double(OpenaiClient) }

  let(:usage) do
    instance_double(
      OpenAI::Models::Responses::ResponseUsage,
      input_tokens: 100,
      output_tokens: 30
    )
  end

  let(:response) do
    instance_double(
      OpenAI::Models::Responses::Response,
      id: "response-integration",
      output_text: "テスト用のAI返答",
      usage: usage
    )
  end

  let(:timeout_error) do
    OpenAI::Errors::APITimeoutError.new(
      url: URI("https://api.openai.com/v1/responses")
    )
  end

  before do
    allow(OpenaiClient).to receive(:new).and_return(client)
    allow(client).to receive(:call).and_return(response)
  end

  it "初回返信の成功を記録し、同じ処理を再度呼んでも履歴を増やさない" do
    service = ReflectionInitialReply.new(reflection: reflection)

    service.call

    expect {
      service.call
    }.not_to change(ApiUsageLog, :count)

    log = reflection.api_usage_logs.sole

    expect(log).to be_status_succeeded
    expect(log.initial_reply).to be true
    expect(log[:retry]).to be false
    expect(log.input_tokens).to eq(100)
    expect(log.output_tokens).to eq(30)
    expect(client).to have_received(:call).once
  end

  it "追加返信は初回返信と区別し、古い返信先への再送では履歴を増やさない" do
    first = create(:reflection_message, reflection: reflection, position: 1)
    service = ReflectionReply.new(reflection: reflection)

    service.call(content: "相談してほしかった", reply_to_id: first.id)

    expect {
      expect {
        service.call(content: "相談してほしかった", reply_to_id: first.id)
      }.to raise_error(ReflectionReply::NotReadyError)
    }.not_to change(ApiUsageLog, :count)

    log = reflection.api_usage_logs.sole

    expect(log).to be_status_succeeded
    expect(log.initial_reply).to be false
    expect(log[:retry]).to be false
    expect(client).to have_received(:call).once
  end

  it "初回の時間切れと再試行の成功を別々に残す" do
    allow(client).to receive(:call).and_raise(timeout_error)

    expect {
      ReflectionInitialReply.new(reflection: reflection).call
    }.to raise_error(OpenAI::Errors::APITimeoutError)

    allow(client).to receive(:call).and_return(response)

    ReflectionRetry.new(reflection: reflection).call(last_message_id: nil)

    logs = reflection.api_usage_logs.order(:id).to_a

    expect(logs.map(&:status)).to eq([ "timed_out", "succeeded" ])
    expect(logs.map(&:initial_reply)).to eq([ true, true ])
    expect(logs.map { |log| log[:retry] }).to eq([ false, true ])
    expect(logs.first.input_tokens).to be_nil
    expect(logs.last.input_tokens).to eq(100)
    expect(reflection.reflection_messages.count).to eq(1)
  end

  it "追加返信の再試行では、利用者の発言を増やさず履歴だけを追加する" do
    first = create(:reflection_message, reflection: reflection, position: 1)
    allow(client).to receive(:call).and_raise(timeout_error)

    expect {
      ReflectionReply.new(reflection: reflection).call(
        content: "相談してほしかった",
        reply_to_id: first.id
      )
    }.to raise_error(OpenAI::Errors::APITimeoutError)

    last = reflection.reflection_messages.order(:position).last
    allow(client).to receive(:call).and_return(response)

    ReflectionRetry.new(reflection: reflection).call(last_message_id: last.id)

    logs = reflection.api_usage_logs.order(:id).to_a

    expect(logs.map(&:status)).to eq([ "timed_out", "succeeded" ])
    expect(logs.map(&:initial_reply)).to eq([ false, false ])
    expect(logs.map { |log| log[:retry] }).to eq([ false, true ])
    expect(reflection.reflection_messages.where(role: :user).count).to eq(1)
    expect(reflection.reflection_messages.count).to eq(3)
  end
end
