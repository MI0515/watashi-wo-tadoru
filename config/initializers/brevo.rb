require Rails.root.join("lib/brevo_delivery").to_s

# Action Mailerの読み込み後に、Brevo APIによる送信方法を登録する
ActiveSupport.on_load(:action_mailer) do
  add_delivery_method :brevo, BrevoDelivery,
    api_key: ENV["BREVO_API_KEY"],
    reply_to: "nanami.apps.contact@gmail.com"
end
