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

  defmodule SlideChanged do
    defstruct station: nil, slide: nil
  end

  defmodule SlideCreated do
    defstruct slide: nil
  end
end
