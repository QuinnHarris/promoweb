# wkhtml2pdf Ruby interface
# http://code.google.com/p/wkhtmltopdf/

class WickedPdf
  attr_accessor :exe_path, :log_file, :logger

  def initialize
    @exe_path = `which wkhtmltopdf`.chomp
    @log_file = "#{RAILS_ROOT}/log/wkhtmltopdf.log"
    @logger   = RAILS_DEFAULT_LOGGER
  end

  def pdf_from_string(string)
    path = @exe_path
    # Don't output errors to standard out

    # Hack?
    tmp_file = "/tmp/wkhtmltopdf-#{Process.pid}.html"
    File.open(tmp_file, "w") { |f| f.write(string) }
    cmdline = "#{@exe_path} -q -n -B 0.75in -L 0.75in -R 0.75in -T 0.75in #{tmp_file} -"

    logger.info "Wicked execute: #{cmdline}"

    pdf = `#{cmdline}`
#    File.delete(tmp_file)
    pdf
  end
end


module PdfHelper
  def self.included(base)
    base.class_eval do
      alias_method_chain :render, :wicked_pdf
    end
  end

  def render_with_wicked_pdf(options = nil, *args, &block)
    if options.is_a?(Hash) && options.has_key?(:pdf)
      make_and_send_pdf(options.delete(:pdf), options)
    else
      render_without_wicked_pdf(options, *args, &block)
    end
  end

  private

  def make_pdf(options = {})
    options[:layout] ||= false
    options[:template] ||= File.join(controller_path, action_name)

    html_string = render_to_string(:template => options[:template], :layout => options[:layout])
    w = WickedPdf.new
    w.pdf_from_string(html_string)
  end

  def make_and_send_pdf(pdf_name, options = {})
    send_data(
      make_pdf(options),
      :filename => pdf_name + '.pdf',
      :type => 'application/pdf'
    )
  end
end


Mime::Type.register 'application/pdf', :pdf
 
ActionController::Base.send(:include, PdfHelper)
