# lib/hermetica/runs.ex
defmodule Hermetica.Runs do
  @moduledoc """
  Minimal on-disk persistence for Hermetica runs.

  - Each run is saved to .hermetica/runs/<run_id>.json
  - Files contain exactly the map you pass to `save!/2` (no extra wrapping),
    so `load!/1` returns the same shape (good for resources/read).
  """

  @dir ".hermetica/runs"
  @ext ".json"

  @doc "Ensure the runs directory exists."
  def ensure_dir!, do: File.mkdir_p!(@dir)

  @doc "Absolute path for a given run id."
  def path(id) when is_binary(id), do: Path.join(@dir, id <> @ext)

  @doc """
  Save a run map to disk (atomic write). Returns the file path.

  NOTE: Writes the map verbatim; include `run_id`/`status` in the map
  BEFORE calling save!/2 if you want them present in the file.
  """
  def save!(id, map) when is_binary(id) and is_map(map) do
    ensure_dir!()
    file = path(id)
    tmp  = file <> ".tmp-" <> Integer.to_string(System.unique_integer([:positive]))
    bin  = Jason.encode!(map)
    File.write!(tmp, bin)
    File.rename!(tmp, file)
    file
  end

  @doc "Return a list of run ids (filenames without .json)."
  def list_ids do
    ensure_dir!()

    case File.ls(@dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, @ext))
        |> Enum.map(&Path.rootname/1)

      {:error, :enoent} ->
        []
    end
  end

  @doc "Load a run map by id (raises if missing or invalid JSON)."
  def load!(id) when is_binary(id) do
    path(id)
    |> File.read!()
    |> Jason.decode!()
  end

  @doc "Does a persisted run exist?"
  def exists?(id) when is_binary(id), do: File.exists?(path(id))

  @doc "Delete a single run file (returns :ok or {:error, reason})."
  def delete(id) when is_binary(id) do
    file = path(id)
    if File.exists?(file), do: File.rm(file), else: :ok
  end

  @doc "Nuke all persisted runs (useful in tests)."
  def clear_all! do
    ensure_dir!()
    File.ls!(@dir)
    |> Enum.each(fn f -> if String.ends_with?(f, @ext), do: File.rm!(Path.join(@dir, f)) end)
    :ok
  end

  @doc "Return run ids sorted by newest first (mtime)."
  def list_ids_newest_first do
    ensure_dir!()

    case File.ls(@dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, @ext))
        |> Enum.map(fn f ->
          full = Path.join(@dir, f)
          {{:ok, %File.Stat{mtime: mtime}}, f} = {File.stat(full), f}
          {mtime, Path.rootname(f)}
        end)
        |> Enum.sort_by(fn {mtime, _} -> mtime end, :desc)
        |> Enum.map(fn {_, id} -> id end)

      _ -> []
    end
  end
end
