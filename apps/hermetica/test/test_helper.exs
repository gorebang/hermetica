ExUnit.start(capture_log: true)

# Make sure the Registry exists for FlowServer name lookups in tests.
# If your Application already starts it, this will just no-op.
{:ok, _} =
  case Process.whereis(Hermetica.Registry) do
    nil -> Registry.start_link(keys: :unique, name: Hermetica.Registry)
    pid when is_pid(pid) -> {:ok, pid}
  end
