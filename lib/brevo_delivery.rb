class BrevoDelivery
  def initialize(settings = {})
    @settings = settings
  end

  def deliver!(mail)
    configuration = Brevo::Configuration.new
    configuration.api_key["api-key"] = @settings.fetch(:api_key)

    api_client = Brevo::ApiClient.new(configuration)
    api = Brevo::TransactionalEmailsApi.new(api_client)

    sender = { email: mail.from.first }
    sender_name = mail[:from].display_names.first
    sender[:name] = sender_name if sender_name.present?

    attributes = {
      sender: sender,
      to: mail.to.map { |email| { email: email } },
      subject: mail.subject,
      replyTo: { email: @settings.fetch(:reply_to) }
    }

    if mail.multipart?
      attributes[:htmlContent] = mail.html_part.body.decoded if mail.html_part
      attributes[:textContent] = mail.text_part.body.decoded if mail.text_part
    elsif mail.mime_type == "text/html"
      attributes[:htmlContent] = mail.body.decoded
    else
      attributes[:textContent] = mail.body.decoded
    end

    email = Brevo::SendSmtpEmail.new(attributes)
    api.send_transac_email(email)
  end
end
