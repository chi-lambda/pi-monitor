defmodule PiMonitor.Telegram.Api do
  def send_message(text) do
    chat_id = Application.get_env(:pi_monitor, :telegram_chat_id)
    telegram_call('sendMessage', :post, Jason.encode!(%{"chat_id" => chat_id, "text" => text}))
  end

  def get_updates(offset, timeout, allowed_updates \\ []) do
    telegram_call(
      'getUpdates',
      :post,
      '{"offset": #{offset}, "timeout": #{timeout}, "allowed_updates": [#{:string.join(allowed_updates, ',')}]}'
    )
  end

  defp telegram_call(path, method, body) do
    token = Application.get_env(:pi_monitor, :telegram_token)

    HTTPoison.request(
      method,
      "https://api.telegram.org/bot#{token}/#{path}",
      body,
      [
        {"Content-Type", "application/json"}
      ],
      recv_timeout: 65000
    )
  end
end
