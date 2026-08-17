require "test_helper"

class EpisodeTest < ActiveSupport::TestCase
  test "requires a unique sequence number within a series" do
    duplicate = episodes(:one).dup

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:episode_number], "has already been taken"
  end

  test "is streamable only after Mux has supplied a playback id" do
    episode = episodes(:one)
    episode.update!(video_status: :ready, mux_playback_id: "playback-id")

    assert_predicate episode, :streamable?
  end
end
