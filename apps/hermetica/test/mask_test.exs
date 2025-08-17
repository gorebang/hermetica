defmodule Hermetica.MaskTest do
  use ExUnit.Case, async: true
  alias Hermetica.Mask

  test "redacts sensitive keys in maps recursively" do
    input = %{
      token: "secret",
      profile: %{email: "a@b.com", nested: %{api_key: "abc"}},
      ok: "visible"
    }

    out = Mask.maybe(input)
    assert out.token == "[REDACTED]"
    assert out.profile.email == "[REDACTED]"
    assert out.profile.nested.api_key == "[REDACTED]"
    assert out.ok == "visible"
  end

  test "passes through non-maps and lists (recursing lists)" do
    assert Mask.maybe("x") == "x"
    assert Mask.maybe([%{password: "p"}]) == [%{password: "[REDACTED]"}]
  end
end
