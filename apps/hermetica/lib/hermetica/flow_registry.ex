# lib/hermetica/flow_registry.ex
defmodule Hermetica.FlowRegistry do
  @moduledoc false

  def all, do: Application.get_env(:hermetica, :flows, [])

  def by_name(name) do
    Enum.find(all(), fn mod -> mod.name() == name end)
  end

  def to_tool(mod) do
    %{
      "name" => "flows." <> mod.name(),
      "description" => mod.description(),
      "inputSchema" => mod.schema()
    }
  end
end
