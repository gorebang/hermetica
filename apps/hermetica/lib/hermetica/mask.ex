defmodule Hermetica.Mask do
  @moduledoc """
  Lightweight PII mask for logs/persistence.
  Recurses through maps/lists and redacts common sensitive keys.
  """

  @redact "[REDACTED]"
  @sensitive_keys ~w(password token api_key apiKey secret authorization bearer cookie email Authorization)a

  def maybe(map) when is_map(map) do
    map
    |> Enum.reduce(%{}, fn {k, v}, acc ->
      key = k
      redacted_val =
        if sensitive_key?(key) do
          @redact
        else
          maybe(v)
        end

      Map.put(acc, key, redacted_val)
    end)
  end

  def maybe(list) when is_list(list), do: Enum.map(list, &maybe/1)
  def maybe(other), do: other

  defp sensitive_key?(key) do
    key
    |> to_string()
    |> String.downcase()
    |> then(&(&1 in ["password", "token", "api_key", "secret", "authorization", "bearer", "cookie", "email"]))
  end
end
