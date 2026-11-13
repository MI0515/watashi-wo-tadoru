require "capybara/rspec"
require "selenium-webdriver"

Capybara.register_driver :headless_chromium do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.binary = ENV.fetch("CHROME_BIN", "/usr/bin/chromium")
  options.add_argument("--headless=new")

  # 開発コンテナではrootで実行するため、ブラウザのsandboxを無効にする
  options.add_argument("--no-sandbox")

  # Dockerの小さな共有メモリ領域を使い切ることを避ける
  options.add_argument("--disable-dev-shm-usage")
  options.add_argument("--window-size=1280,900")

  service = Selenium::WebDriver::Chrome::Service.new(
    path: ENV.fetch("CHROMEDRIVER_PATH", "/usr/bin/chromedriver")
  )

  Capybara::Selenium::Driver.new(
    app,
    browser: :chrome,
    options: options,
    service: service
  )
end

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :headless_chromium
  end
end
