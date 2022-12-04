defmodule SlayPlay.Player do
  @moduledoc """
  The player context
  """

  import Ecto.Query, warn: false
  alias SlayPlay.MP3Stat
  alias SlayPlay.Player.{Events, Song}
  alias Ecto.{Changeset, Multi}

  @pubsub SlayPlay.PubSub

  defdelegate stopped?(song), to: Song
  defdelegate playing?(song), to: Song
  defdelegate paused?(song), to: Song

  @doc """
  Gets the local filepath for songs
  """
  def local_filepath(filename_uuid) when is_binary(filename_uuid) do
    dir = SlayPlay.config([:files, :uploads_dir])
    Path.join([dir, "songs", filename_uuid])
  end

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

  def store_mp3(%Song{} = song, tmp_path) do
    File.mkdir_p!(Path.dirname(song.mp3_filepath))
    File.cp!(tmp_path, song.mp3_filepath)
  end

  def put_stats(%Ecto.Changeset{} = changeset, %MP3Stat{} = stat) do
    chset = Song.put_stats(changeset, stat)

    if error = chset.errors[:duration] do
      {:error, %{duration: error}}
    else
      {:ok, chset}
    end
  end

  def import_songs(changesets, consume_file)
      when is_map(changesets) and is_function(consume_file, 2) do
    multi =
      Enum.reduce(changesets, Ecto.Multi.new(), fn {ref, chset}, acc ->
        chset = Song.put_mp3_path(chset)

        Ecto.Multi.insert(acc, {:song, ref}, chset)
      end)

    # |> Ecto.Multi.run(:valid_songs_count, fn _repo, changes ->
    #   new_songs_count = changes |> Enum.filter(&match?({{:song, _ref}, _}, &1)) |> Enum.count()
    #   validate_songs_limit(user.songs_count, new_songs_count)
    # end)
    # |> Ecto.Multi.update_all(
    #   :update_songs_count,
    #   fn %{valid_songs_count: new_count} ->
    #     from(u in Accounts.User,
    #       where: u.id == ^user.id and u.songs_count == ^user.songs_count,
    #       update: [inc: [songs_count: ^new_count]]
    #     )
    #   end,
    #   []
    # )
    # |> Ecto.Multi.run(:is_songs_count_updated?, fn _repo, %{update_songs_count: result} ->
    #   case result do
    #     {1, _} -> {:ok, user}
    #     _ -> {:error, :invalid}
    #   end
    # end)

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

  defp broadcast_imported(songs) do
    songs = Enum.map(songs, fn {_ref, song} -> song end)
    broadcast!(%Events.SongsImported{songs: songs})
  end

  def parse_file_name(name) do
    case Regex.split(~r/[-–]/, Path.rootname(name), parts: 2) do
      [title] -> %{title: String.trim(title), artist: nil}
      [title, artist] -> %{title: String.trim(title), artist: String.trim(artist)}
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

  def get_song!(id), do: Repo.replica().get!(Song, id)

  defp broadcast!(msg) do
    Phoenix.PubSub.broadcast!(@pubsub, "player:default", {__MODULE__, msg})
  end
end
