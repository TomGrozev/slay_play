defmodule SlayPlay.Player.Events do
  defmodule Play do
    defstruct song: nil, elapsed: nil
  end

  defmodule Pause do
    defstruct song: nil
  end

  defmodule SongsImported do
    defstruct songs: []
  end
end
