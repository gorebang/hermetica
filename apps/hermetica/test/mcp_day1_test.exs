defmodule Hermetica.MCP.Day1Test do
  use ExUnit.Case, async: false
  alias Hermetica.MCP.Router

  setup do
    File.rm_rf!(".hermetica/runs")
    {:ok, io: {:test, self()}}   # <— runtime, correct PID
  end

  test "initialize -> list -> call (partials) -> resources list/read", %{io: io} do
    init = Router.handle(%{"jsonrpc"=>"2.0","id"=>1,"method"=>"initialize"}, io)
    assert init["result"]["capabilities"]["tools"]["call"]

    list = Router.handle(%{"jsonrpc"=>"2.0","id"=>2,"method"=>"tools/list"}, io)
    tools = list["result"]["tools"] |> Enum.map(& &1["name"])
    assert "flows.example" in tools

    resp = Router.handle(%{
      "jsonrpc"=>"2.0","id"=>3,"method"=>"tools/call",
      "params"=>%{"name"=>"flows.example","arguments"=>%{"message"=>"hi","steps"=>2}}
    }, io)

    assert_receive {:tools_partial, %{id: 3}}, 1_500
    assert_receive {:tools_partial, %{id: 3}}, 1_500

    assert %{"result" => %{"content" => [%{"text" => text, "mimeType" => "application/json"} | _]}} = resp
    body = Jason.decode!(text)
    assert body["echoed"] == "hi"
    assert body["status"] == "ok"
    run_id = body["run_id"]
    assert is_binary(run_id)

    rlist = Router.handle(%{"jsonrpc"=>"2.0","id"=>4,"method"=>"resources/list"}, io)
    uris  = rlist["result"]["resources"] |> Enum.map(& &1["uri"])
    assert "hermetica://runs/#{run_id}" in uris

    read = Router.handle(%{
      "jsonrpc"=>"2.0","id"=>5,"method"=>"resources/read",
      "params"=>%{"uri"=>"hermetica://runs/#{run_id}"}}, io)
    assert %{"result" => %{"contents" => [%{"text" => text2}]}} = read
    assert Jason.decode!(text2)["run_id"] == run_id
  end

  test "validation error when required arg missing", %{io: io} do
    resp = Router.handle(%{
      "jsonrpc"=>"2.0","id"=>9,"method"=>"tools/call",
      "params"=>%{"name"=>"flows.example","arguments"=>%{}}
    }, io)
    assert %{"error" => %{"code" => -32602, "message" => msg}} = resp
    assert msg =~ "Missing required"
  end

  test "timeout surfaces clean error", %{io: io} do
    resp = Router.handle(%{
      "jsonrpc"=>"2.0","id"=>10,"method"=>"tools/call",
      "params"=>%{"name"=>"flows.example","arguments"=>%{"message"=>"x","steps"=>99,"timeout_ms"=>10}}
    }, io)
    assert %{"error" => %{"code" => 1002, "message" => msg}} = resp
    assert msg =~ "timed out"
  end
end
