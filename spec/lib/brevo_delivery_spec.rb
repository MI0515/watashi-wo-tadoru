require "rails_helper"

RSpec.describe BrevoDelivery do
  let(:api) { instance_double(Brevo::TransactionalEmailsApi) }

  let(:delivery) do
    described_class.new(
      api_key: "test-api-key",
      reply_to: "nanami.apps.contact@gmail.com"
    )
  end

  let(:message) do
    Mail.new do
      from "わたしを辿る <nanami.apps.contact@gmail.com>"
      to "recipient@example.com"
      subject "送信テスト"
      body "テスト本文"
    end
  end

  before do
    allow(Brevo::TransactionalEmailsApi).to receive(:new).and_return(api)
  end

  it "送信者・宛先・件名・テキスト本文・返信先をAPIへ渡す" do
    expect(api).to receive(:send_transac_email) do |email|
      expect(email.sender).to eq(
        email: "nanami.apps.contact@gmail.com",
        name: "わたしを辿る"
      )
      expect(email.to).to eq([ { email: "recipient@example.com" } ])
      expect(email.subject).to eq("送信テスト")
      expect(email.text_content).to eq("テスト本文")
      expect(email.reply_to).to eq(
        email: "nanami.apps.contact@gmail.com"
      )
    end

    delivery.deliver!(message)
  end

  it "複数形式のメールではテキストとHTMLの両方を渡す" do
    message.body = nil
    message.text_part = Mail::Part.new do
      body "テキスト本文"
    end
    message.html_part = Mail::Part.new do
      content_type "text/html; charset=UTF-8"
      body "<p>HTML本文</p>"
    end

    expect(api).to receive(:send_transac_email) do |email|
      expect(email.text_content).to eq("テキスト本文")
      expect(email.html_content).to eq("<p>HTML本文</p>")
    end

    delivery.deliver!(message)
  end

  it "APIの送信エラーを握りつぶさず呼び出し元へ返す" do
    allow(api).to receive(:send_transac_email)
      .and_raise(Brevo::ApiError.new)

    expect {
      delivery.deliver!(message)
    }.to raise_error(Brevo::ApiError)
  end
end
