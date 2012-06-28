class CallLog < ActiveRecord::Base
  @@rtp_stat_params = %w(raw_bytes media_bytes packet_count media_packet_count skip_packet_count jb_packet_count dtmf_packet_count cng_packet_count flush_packet_count largest_jb_size)
  @@rtp_stat_names = %w(rtp_audio_in_ rtp_audio_out_).collect { |d| @@rtp_stat_params.collect { |e| d + e } }.flatten
  cattr_reader :rtp_stat_params, :rtp_stat_names
end
