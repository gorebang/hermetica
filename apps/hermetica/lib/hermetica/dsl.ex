defmodule Hermetica.DSL do
  defmacro defflow(name, do: block) do
    quote do
      Module.register_attribute(__MODULE__, :steps, accumulate: true)
      @flow_name unquote(name)
      unquote(block)
      def __flow__, do: %{name: @flow_name, steps: Enum.reverse(@steps)}
    end
  end

  # step :name, fn ctx -> ... end
  defmacro step(name, fun_ast) do
    fun_name = name |> to_string() |> then(&("step_" <> &1)) |> String.to_atom()
    quote do
      def unquote(fun_name)(ctx), do: unquote(fun_ast).(ctx)
      @steps {unquote(name), {:fun, &__MODULE__.unquote(fun_name)/1}}
    end
  end

  # step :name, [timeout: 1000, retries: 2], fn ctx -> ... end
  defmacro step(name, opts, fun_ast) do
    fun_name = name |> to_string() |> then(&("step_" <> &1)) |> String.to_atom()
    quote do
      def unquote(fun_name)(ctx), do: unquote(fun_ast).(ctx)
      @steps {unquote(name), {:fun, &__MODULE__.unquote(fun_name)/1, unquote(opts)}}
    end
  end
end
