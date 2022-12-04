defmodule SlayPlay.Player do
  @moduledoc """
  The player context
  """

  require Logger

  import Ecto.Query, warn: false
  alias SlayPlay.{MP3Stat, Repo}
  alias SlayPlay.Player.{Events, Song, Slide, Station}
  alias Ecto.{Changeset, Multi}

  @pubsub SlayPlay.PubSub
  @auto_next_threshold_seconds 5
  @max_songs 30

  defdelegate stopped?(song), to: Song
  defdelegate playing?(song), to: Song
  defdelegate paused?(song), to: Song

  @doc """
  Subscribes to the default player
  """
  def subscribe do
    Phoenix.PubSub.subscribe(@pubsub, "player:default")
  end

  @doc """
  Unsubscribes from the player
  """
  def unsubscribe do
    Phoenix.PubSub.unsubscribe(@pubsub, "player:default")
  end

  @doc """
  Gets the local filepath for a file type

  Defaults to the songs folder
  """
  def local_filepath(filename_uuid, type \\ :songs) when is_binary(filename_uuid) do
    dir = SlayPlay.config([:files, :uploads_dir])
    Path.join([dir, to_string(type), filename_uuid])
  end

  @doc """
  Returns the url for a background image

  Uses phoenix token
  """
  def slide_img_url(%Slide{img_name: filename}, token) when is_binary(token),
    do: Slide.img_url(filename) <> "?token=#{token}"

  @doc """
  Plays a song on all subscribed
  """
  def play_song(%Song{id: id}) do
    play_song(id)
  end

  def play_song(id) do
    song = get_song!(id)

    played_at =
      cond do
        playing?(song) ->
          song.played_at

        paused?(song) ->
          elapsed = DateTime.diff(song.paused_at, song.played_at, :second)
          DateTime.add(DateTime.utc_now(), -elapsed)

        true ->
          DateTime.utc_now()
      end

    changeset =
      Changeset.change(song, %{
        played_at: DateTime.truncate(played_at, :second),
        status: :playing
      })

    stopped_query =
      from s in Song,
        where: s.status in [:playing, :paused],
        update: [set: [status: :stopped]]

    {:ok, %{now_playing: new_song}} =
      Multi.new()
      |> Multi.update_all(:now_stopped, fn _ -> stopped_query end, [])
      |> Multi.update(:now_playing, changeset)
      |> Repo.transaction()

    elapsed = elapsed_playback(new_song)

    broadcast!(%Events.Play{song: song, elapsed: elapsed})

    new_song
  end

  @doc """
  Pauses a song for all subscribed
  """
  def pause_song(%Song{} = song) do
    now = DateTime.truncate(DateTime.utc_now(), :second)
    set = [status: :paused, paused_at: now]
    pause_query = from(s in Song, where: s.id == ^song.id, update: [set: ^set])

    stopped_query =
      from s in Song,
        where: s.status in [:playing, :paused],
        update: [set: [status: :stopped]]

    {:ok, _} =
      Multi.new()
      |> Multi.update_all(:now_stopped, fn _ -> stopped_query end, [])
      |> Multi.update_all(:now_paused, fn _ -> pause_query end, [])
      |> Repo.transaction()

    broadcast!(%Events.Pause{song: song})
  end

  @doc """
  Automatically plays the next song at the end
  """
  def play_next_song_auto do
    song = get_current_active_song() || get_first_song()

    if song && elapsed_playback(song) >= song.duration - @auto_next_threshold_seconds do
      song
      |> get_next_song()
      |> play_song()
    end
  end

  @doc """
  Plays the previous song in the list

  If there is no active song, the first is used
  """
  def play_prev_song do
    song = get_current_active_song() || get_first_song()

    if prev_song = get_prev_song(song) do
      play_song(prev_song)
    end
  end

  @doc """
  Plays the next song in the list

  If there is no active song, the first is used
  """
  def play_next_song do
    song = get_current_active_song() || get_first_song()

    if next_song = get_next_song(song) do
      play_song(next_song)
    end
  end

  @doc """
  Plays the next slide for a station
  """
  def set_next_slide(%Station{} = station) do
    current_slide = get_current_active_slide(station.name) || get_first_slide()

    if next_slide = get_next_slide(current_slide) do
      set_slide(next_slide, station.name)
    end
  end

  @doc """
  Gets the current active slide
  """
  def get_current_active_slide(station_name) do
    get_station!(station_name)
    |> Repo.preload(:active_slide)
    |> Map.get(:active_slide)
  end

  @doc """
  Gets the current active song

  An active is one that is either `:playing` or `:paused`.
  All other songs are `:stopped`.
  """
  def get_current_active_song do
    Repo.one(from s in Song, where: s.status in [:playing, :paused])
  end

  @doc """
  Sets the current slide for a station

  Default to the "default" player
  """
  def set_slide(%Slide{} = slide, station \\ "default") do
    station = get_station!("default") |> Repo.preload(:active_slide)
    changeset = Station.changeset(station, %{}) |> Station.put_slide(slide)

    {:ok, station} = Repo.update(changeset)

    broadcast!(%Events.SlideChanged{station: station, slide: slide})

    station
  end

  @doc """
  Lists all stations

  An optional limit can be supplied (defaults to 100)
  """
  def list_stations(limit \\ 100) do
    from(s in Station, limit: ^limit)
    |> order_by_playlist(:asc)
    |> Repo.all()
  end

  @doc """
  Lists all songs

  An optional limit can be supplied (defaults to 100)
  """
  def list_songs(limit \\ 100) do
    from(s in Song, limit: ^limit)
    |> order_by_playlist(:asc)
    |> Repo.all()
  end

  @doc """
  Lists all slides

  An optional limit can be supplied (defaults to 100)
  """
  def list_slides(limit \\ 100) do
    from(s in Slide, limit: ^limit)
    |> order_by_playlist(:asc)
    |> Repo.all()
  end

  @doc """
  Stores an mp3 in the permenant location
  """
  def store_mp3(%Song{} = song, tmp_path) do
    File.mkdir_p!(Path.dirname(song.mp3_filepath))
    File.cp!(tmp_path, song.mp3_filepath)
  end

  @doc """
  Stores a slide bg in the permenant location
  """
  def store_bg(%Slide{} = slide, tmp_path) do
    path = local_filepath(slide.img_name, :background)
    File.mkdir_p!(Path.dirname(path))
    File.cp!(tmp_path, path)
  end

  @doc """
  Put the MP3 stats to the song changeset
  """
  def put_stats(%Ecto.Changeset{} = changeset, %MP3Stat{} = stat) do
    chset = Song.put_stats(changeset, stat)

    if error = chset.errors[:duration] do
      {:error, %{duration: error}}
    else
      {:ok, chset}
    end
  end

  @doc """
  Imports one or more songs
  """
  def import_songs(changesets, consume_file)
      when is_map(changesets) and is_function(consume_file, 2) do
    multi =
      Enum.reduce(changesets, Ecto.Multi.new(), fn {ref, chset}, acc ->
        chset = Song.put_mp3_path(chset)

        Ecto.Multi.insert(acc, {:song, ref}, chset)
      end)

    case SlayPlay.Repo.transaction(multi) do
      {:ok, results} ->
        songs =
          results
          |> Enum.filter(&match?({{:song, _ref}, _}, &1))
          |> Enum.map(fn {{:song, ref}, song} ->
            consume_file.(ref, fn tmp_path -> store_mp3(song, tmp_path) end)
            {ref, song}
          end)

        broadcast_imported(songs)

        {:ok, Enum.into(songs, %{})}

      {:error, failed_op, failed_val, _changes} ->
        failed_op =
          case failed_op do
            {:song, _number} -> "Invalid song (#{failed_val.changes.title})"
            # :is_songs_count_updated? -> :invalid
            failed_op -> failed_op
          end

        {:error, {failed_op, failed_val}}
    end
  end

  @doc """
  Creates a slide
  """
  def create_slide(params, type, consume_file)
      when is_function(consume_file, 1) do
    with [extension | _] <- MIME.extensions(type),
         changeset = change_slide(%Slide{}, params) |> Slide.put_img_name(extension),
         {:ok, slide} <- Repo.insert(changeset) do
      IO.inspect(slide)
      consume_file.(fn tmp_path -> store_bg(slide, tmp_path) end)

      broadcast_slide_create(slide)

      {:ok, slide}
    end
    |> IO.inspect()
  end

  @doc """
  Parses a filename to try to extract title and artist
  """
  def parse_file_name(name) do
    case Regex.split(~r/[-–]/, Path.rootname(name), parts: 2) do
      [title] -> %{title: String.trim(title), artist: nil}
      [title, artist] -> %{title: String.trim(title), artist: String.trim(artist)}
    end
  end

  @doc """
  Gets elapsed time from song start
  """
  def elapsed_playback(%Song{} = song) do
    cond do
      playing?(song) ->
        start_seconds = song.played_at |> DateTime.to_unix()
        System.os_time(:second) - start_seconds

      paused?(song) ->
        DateTime.diff(song.paused_at, song.played_at, :second)

      stopped?(song) ->
        0
    end
  end

  @doc """
  Applies changes to a song
  """
  def change_song(song_or_changeset, attrs \\ %{})

  def change_song(%Song{} = song, attrs) do
    Song.changeset(song, attrs)
  end

  @keep_changes [:duration, :mp3_filesize, :mp3_filepath]
  def change_song(%Ecto.Changeset{} = prev_changeset, attrs) do
    %Song{}
    |> change_song(attrs)
    |> Ecto.Changeset.change(Map.take(prev_changeset.changes, @keep_changes))
  end

  @doc """
  Applies changes to a slide
  """
  def change_slide(%Slide{} = slide, attrs \\ %{}) do
    Slide.changeset(slide, attrs)
  end

  @doc """
  Gets a station by name
  """
  def get_station!(name), do: Repo.get_by!(Station, name: name)

  @doc """
  Gets a song by id
  """
  def get_song!(id), do: Repo.get!(Song, id)

  @doc """
  Gets a slide by id
  """
  def get_slide!(id), do: Repo.get!(Slide, id)

  @doc """
  Gets the first song in the list
  """
  def get_first_song do
    from(s in Song,
      limit: 1
    )
    |> order_by_playlist(:asc)
    |> Repo.one()
  end

  @doc """
  Gets the last song in the list
  """
  def get_last_song do
    from(s in Song,
      limit: 1
    )
    |> order_by_playlist(:desc)
    |> Repo.one()
  end

  @doc """
  Gets the next song in the list
  """
  def get_next_song(%Song{} = song) do
    next =
      from(s in Song,
        where: s.id > ^song.id,
        limit: 1
      )
      |> order_by_playlist(:asc)
      |> Repo.one()

    next || get_first_song()
  end

  @doc """
  Gets the previous song in the list
  """
  def get_prev_song(%Song{} = song) do
    prev =
      from(s in Song,
        where: s.id < ^song.id,
        order_by: [desc: s.inserted_at, desc: s.id],
        limit: 1
      )
      |> order_by_playlist(:desc)
      |> Repo.one()

    prev || get_last_song()
  end

  @doc """
  Gets the first slide
  """
  def get_first_slide do
    from(s in Slide,
      limit: 1
    )
    |> order_by_playlist(:asc)
    |> Repo.one()
  end

  @doc """
  Gets the next slide
  """
  def get_next_slide(%Slide{} = slide) do
    next =
      from(s in Slide,
        where: s.id > ^slide.id,
        limit: 1
      )
      |> order_by_playlist(:asc)
      |> Repo.one()

    next || get_first_slide()
  end

  @doc """
  Updates a song
  """
  def update_song(%Song{} = song, attrs) do
    song
    |> Song.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a song
  """
  def delete_song(%Song{} = song) do
    delete_song_file(song)

    case Repo.delete(song) do
      {:ok, _} -> :ok
      other -> other
    end
  end

  @doc """
  Deletes a slide
  """
  def delete_slide(%Slide{} = slide) do
    case Repo.delete(slide) do
      {:ok, _} -> :ok
      other -> other
    end
  end

  defp delete_song_file(song) do
    case File.rm(song.mp3_filepath) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.info(
          "unable to delete song #{song.id} at #{song.mp3_filepath}, got: #{inspect(reason)}"
        )
    end
  end

  defp broadcast!(msg) do
    Logger.info("Broadcasting #{inspect(msg.__struct__ || "unknown")}")
    Phoenix.PubSub.broadcast!(@pubsub, "player:default", {__MODULE__, msg})
  end

  defp order_by_playlist(%Ecto.Query{} = query, direction) when direction in [:asc, :desc] do
    from(s in query, order_by: [{^direction, s.inserted_at}, {^direction, s.id}])
  end

  defp broadcast_imported(songs) do
    songs = Enum.map(songs, fn {_ref, song} -> song end)
    broadcast!(%Events.SongsImported{songs: songs})
  end

  defp broadcast_slide_create(slide) do
    broadcast!(%Events.SlideCreated{slide: slide})
  end
end
