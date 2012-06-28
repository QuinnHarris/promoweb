class CallLog < ActiveRecord::Base
  @@rtp_stat_params = %w(raw_bytes media_bytes packet_count media_packet_count skip_packet_count jb_packet_count dtmf_packet_count cng_packet_count flush_packet_count largest_jb_size)
  @@rtp_stat_names = %w(rtp_audio_in_ rtp_audio_out_).collect { |d| @@rtp_stat_params.collect { |e| d + e } }.flatten
  cattr_reader :rtp_stat_params, :rtp_stat_names

  def rtp_stat_problems
    ret = {}
    %w(in out).each do |dir|
      total = send("rtp_audio_#{dir}_packet_count")
      %w(skip jb cng flush).each do |name|
        val = send("rtp_audio_#{dir}_#{name}_packet_count")
        ret["#{dir}_#{name}"] = [val, val * 100.0 / total] if val > 0
      end
    end
    ret
  end
end
