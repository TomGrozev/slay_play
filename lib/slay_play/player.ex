defmodule SlayPlay.Player do
  @moduledoc """
  The player context
  """

  @doc """
  Gets the local filepath for songs
  """
  def local_filepath(filename_uuid) when is_binary(filename_uuid) do
    dir = SlayPlay.config([:files, :uploads_dir])
    Path.join([dir, "songs", filename_uuid])
  end
end
