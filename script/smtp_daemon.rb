#!/usr/bin/env ruby


#if defined?(Rails)
  # Assume we are loaded from the rails app

#else
  require File.dirname(__FILE__) + '/../config/environment'
#end

require 'gserver'
require 'hpricot'

class ExceptionNotifier < ActionMailer::Base
public
  def exception_notification_smtp(exception, message, data = {})
    content_type "text/plain"

    subject    "#{message.mail_from} (#{exception.class}) #{exception.message.inspect}"

    recipients exception_recipients
    from       sender_address

    controller = (Struct.new(:controller_name, :action_name)).new("email", "message")
#    request = (Struct.new(:protocol, :parameters, :env)).new( 'SMTP', {}, {'HTTP_HOST' => host })

    body       render_message('exception_notification',
                              data.merge({ :controller => controller, #:request => request,
                                           :exception => exception, #:host => (request.env["HTTP_X_FORWARDED_HOST"] || request.env["HTTP_HOST"]),
                                           :backtrace => sanitize_backtrace(exception.backtrace),
                                           :rails_root => rails_root, #:data => data,
                                           :sections => %w(backtrace) }))
  end
end

    

class MessageProcessError < StandardError
  def initialize(string)
    @string = string
  end

  def message
    @string
  end
end

class IgnoreMessage < StandardError
end
                                                            

class Message
  def initialize
    @data = ''
    @data_mode = false
  end
  attr_reader :host, :mail_from, :rcpt_to, :data

  def process_message(fake = false)
    headers = {}

    klass = case mail_from
            when /auto(note|task)@leedsworld.com/i
              LeedsProcessor
            when /customer.service@gemline.com/i
              GemlineProcessor
            when /quinn@mountainofpromos.com/i
              TestProcessor
            end
    
    if klass
      obj = klass.new(self)
      begin
        obj.process
        headers['Status'] = 'Processed'
      rescue IgnoreMessage
        headers['Status'] = 'Ignore'
      rescue => exception
        raise if fake
        ExceptionNotifier.deliver_exception_notification_smtp(exception, self)
        headers['Status'] = 'Exception'
        headers['Exception'] = "#{exception.class}: #{exception.message.inspect} for #{klass}"
      end
      headers.merge!(obj.headers)
    else
      headers['Status'] = 'Unkown'
    end

    if fake
      puts headers.inspect
      return
    end

    moddata = data.sub(/(\r?\n){2}/, headers.collect { |k, v| "\\1X-MOPBOT-#{k}: #{v}" }.join + '\1\1')
    raise MessageProcessError, "Couldn't apply headers" if moddata.length == data.length
    Net::SMTP.start('127.0.0.1', 10026) do |smtp|
      smtp.send_message(moddata, mail_from, rcpt_to)
    end
  end

  def tmail
    return @tmail if @tmail
    @tmail = TMail::Mail.parse(data)
  end

  def process_fake(host, mail_from, rcpt_to, data)
    @host, @mail_from, @rcpt_to, @data = host, mail_from, rcpt_to, data
    process_message(true)
  end

  def process_line(line)
    if (line =~ /^(?:HELO|EHLO)\s+(.+)/)
      @host = $1
      return true, "250 and..?\r\n"
    end
    if (line =~ /^QUIT/)
      return false, "bye\r\n"
    end
    if (line =~ /^MAIL FROM\:(.+)/)
      @mail_from = $1
      return true, "250 OK\r\n"
    end
    if (line =~ /^RCPT TO\:(.+)/)
      @rcpt_to = $1
      return true, "250 OK\r\n"
    end
    if (line =~ /^DATA/)
      @data_mode = true
      return true, "354 Enter message, ending with \".\" on a line by itself\r\n"
    end
    if @data_mode
      if line.chomp =~ /^\.$/
        @data << line.chomp("\r\n.\r\n")
        @data_mode = false
        process_message
        return true, "220 OK\r\n"
      else
        @data << line
        return true, ""
      end
    end

    return true, "500 ERROR\r\n"

    # RSET
  end
end


class MessageProcessor
  UPS = /(1Z ?[0-9A-Z]{3} ?[0-9A-Z]{3} ?[0-9A-Z]{2} ?[0-9A-Z]{4} ?[0-9A-Z]{3} ?[0-9A-Z]|[\dT]\d\d\d ?\d\d\d\d ?\d\d\d)/i
  FEDEX = /((96\d\d\d\d\d ?\d\d\d\d|96\d\d) ?\d\d\d\d ?d\d\d\d( ?\d\d\d)?)/i
  USPS = /(91\d\d ?\d\d\d\d ?\d\d\d\d ?\d\d\d\d ?\d\d\d\d ?\d\d|91\d\d ?\d\d\d\d ?\d\d\d\d ?\d\d\d\d ?\d\d\d\d)/i

  def initialize(msg)
    @message = msg
    @headers = {}
  end
  attr_reader :message, :headers
  
  def set_header(key, name)
    @headers[key] = name
  end

  def append_header(key, name)
    @headers[key] = @headers[key] ? "#{@headers[key]}, #{name}" : name
  end

  def task_complete(item, data, task_class, revokable = [], revoke = true)
    task = item.task_complete({ :user_id => 0,
                                :host => message.tmail.message_id,
                                :data => { :date => message.tmail.date }.merge(data) },
                              task_class, revokable, revoke)
    append_header('tasks', "#{task_class}-#{task.id}")
  end

  def expect_one(items, error = '')
    raise MessageProcessError, "Not enough #{error}" if items.empty?
    raise MessageProcessError, "Too many #{error}" if items.length > 1
    items.first
  end

  def get_po(po_id)
    po = PurchaseOrder.find_by_quickbooks_ref(po_id)
    raise MessageProcessError, "Can't find PO" unless po
    set_header('PO', po.quickbooks_ref)
    po
  end

  def get_item(po_id, item_id, null = false)
    po = po_id.is_a?(PurchaseOrder) ? po_id : get_po(po_id)
    
    items = po.purchase.items.find_all do |item|
      next true if item.price_group.variants.to_a.find { |v| v.supplier_num == item_id }
      item.product.supplier_num == item_id
    end
    raise MessageProcessError, "Not enough order items" if items.empty? and !null
    raise MessageProcessError, "Too many order items" if items.length > 1
    item = items.first
    append_header('items', item.id) if item
    item
  end

  def apply_confirmation(item)
    raise MessageProcessError, "Order already confirmed" if item.task_completed?(ConfirmItemTask)

    task_complete(item, {}, ConfirmItemTask)
  end

  def apply_estimate(item, date, days, direct = false, saturday = nil)
    raise MessageProcessError, "Estimated already entered" if direct and item.task_completed?(EstimatedItemTask)

    OrderItemTask.transaction do
      unless item.task_completed?(ConfirmItemTask)
        raise MessageProcessError, "Confirm Not Ready" unless item.task_ready?(ConfirmItemTask)
        task_complete(item, {}, ConfirmItemTask)
      end
      
      task_complete(item, { :email_sent => direct, :ship_date => date, :ship_days => days, :ship_saturday => saturday && '1' }, EstimatedItemTask)
    end
  end

  def apply_tracking(item, carrier, number, email = true)
    raise MessageProcessError, "Tracking already entered" if item.task_completed?(ShipItemTask)

    task_complete(item, { :email_sent => email, :carrier => carrier, :tracking => number }, ShipItemTask)
  end
end

class TestProcessor < MessageProcessor
  def process
    raise IgnoreMessage if message.tmail.subject == "Ignore"
    raise MessageProcessError, "Test Error Handling"
  end
end

class LeedsProcessor < MessageProcessor
  def get_rtf_attachment_text
    attachment = nil
    message.tmail.attachments.each do |a|
      next unless /\.rtf$/ === a.original_filename
      next unless /application\/(msword|rtf)/ === a.content_type
      raise MessageProcessError, "Multiple attachments" if attachment
      attachment = a
    end
    raise MessageProcessError, "No attachments" unless attachment

    File.open('/tmp/unrtf', 'w') do |f|
      f.write(message.tmail.attachments.first.string)
      f.close
    end
    `unrtf --nopict --text /tmp/unrtf 2> /dev/null`
  end

  TRACKING_PO_REGEXP = /\nCustomer PO:\n(\w+)\n/
  
  def process_tracking
    txt = get_rtf_attachment_text

    # Parse PO and product item
    raise MessageProcessError, "Unkown PO: #{txt.inspect}" unless TRACKING_PO_REGEXP === txt
    po_num = $1.chomp('S')
    item_ids = txt.scan(/^(\d{4}-\d{2})[A-Z]{2,3}$/).flatten
    raise MessageProcessError, "Expected atleast one item" if item_ids.empty?

    # Parse Dates
    unless /\n(\d{1,2}\/\d{1,2}\/\d{4})\nOrder Date:\n(.+)\n(\d{1,2}\/\d{1,2}\/\d{4})\nShip Date:\n(\d{1,2}\/\d{1,2}\/\d{4})\nIn Hand Date:\n/ === txt
      raise MessageProcessError, "Unkown Dates"
    end
    ship_date, in_hand_date = $3, $4
    ship_days = (Date.parse(in_hand_date) - Date.parse(ship_date)).to_i
    
    # Parse tracking #
    numbers = txt.scan(UPS).flatten
    carrier = 'UPS'
    if numbers.empty?
      numbers = txt.scan(FEDEX)
      carrier = 'FedEx'
    end
    raise MessageProcessError, "No tracking numbers" if numbers.empty?
    number = numbers.first

    # Apply tasks
    Order.transaction do
      po = get_po(po_num)

      items = item_ids.collect do |id|
        get_item(po, id, true)
      end.compact

      items.each do |item|
        apply_estimate(item, ship_date, ship_days) unless item.task_completed?(EstimatedItemTask)
        apply_tracking(item, carrier, number, item == items.last)
      end
    end      
  end

  include ActionView::Helpers::NumberHelper
  def process_confirmation
    txt = get_rtf_attachment_text
    item_id = expect_one(txt.scan(/^(\d{4}-\d{2})[A-Z]{2,3}$/).flatten, 'supplier numbers')

    Order.transaction do
      item = get_item(@po_num, item_id)

      cost = item.total_cost
      unless [cost, cost - (item.list_shipping_cost || 0)].find do |price|
          txt.include?(number_with_precision(price, :precision => 2, :separator => '.', :delimiter => ','))
        end
        raise MessageProcessError, "Couldn't find correct price"
      end

      apply_confirmation(item)
    end
  end

  def process
    case message.tmail.subject
      when /^Leed's Order (\w+) Shipping Confirmation$/
      process_tracking
      when /^Order Confirmation - PO#: (\w+)$/
      @po_num = $1
      process_confirmation
    else
      raise IgnoreMessage
    end
  end
end

class GemlineProcessor < MessageProcessor

  def get_table_value(doc, str)
    td = doc.search("//table//table/tr/td").find { |e| e.inner_html.strip == str }
    raise MessageProcessError, "Can't find #{str.inspect} header" unless td
    tds = td.parent.search('td')
    value = tds[tds.index(td)+1].inner_html
    raise MessageProcessError, "Can't find #{str.inspect} text" unless value
    value
  end

  def process_tracking    
    doc = Hpricot(message.tmail.body)
    po_num = get_table_value(doc, 'PO #:')
    
    tracking_tds = doc.search("//table//table/tr/td/a")

    Order.transaction do
      tracking_tds.each do |ta|
        number = ta.inner_html
        carrier = case number
                  when UPS
                    'UPS'
                  when FEDEX
                    'FedEx'
                  else
                    raise MessageProcessError, "Unkown tracking #: #{number.inspect}"
                  end
        
        item_id = ta.parent.parent.search("td").first.inner_html.chomp('S')
        
        item = get_item(po_num, item_id)
        #apply_estimate
        apply_tracking(item, carrier, number)
      end
    end
  end

  def process_confirmation
    doc = Hpricot(message.tmail.body)
    po_num = get_table_value(doc, 'PO#:')

    table = doc.search("//table//td/table")[2]
    Order.transaction do
      table.search('tr')[1..-1].each do |tr|
        tds = tr.search('td')
        next unless tds.length == 7
        item_id = tds[0].inner_html.strip.chomp('S')
        ship_date = tds[6].inner_html
        
        item = get_item(po_num, item_id)
        
        service = get_table_value(doc, 'Carrier/Service:')
        unless service == item.shipping.description
          raise MessageProcessError, "Shiping types don't match #{service.inspect} != #{item.shipping.description.inspect}"
        end
        
        apply_confirmation(item)
        apply_estimate(item, ship_date, item.shipping.days, true)
      end
    end
  end

  def process
    case message.tmail.subject
      when /^Order shipping details$/
      process_tracking
      when /^Order confirmation$/
      process_confirmation
    else
      raise IgnoreMessage
    end
  end
end

class SMTPServer < GServer
  def serve(io)
    msg = Message.new
    io.print "220 hello\r\n"
    loop do
      if IO.select([io], nil, nil, 0.1)
        data = io.readpartial(4096)
        ok, op = msg.process_line(data)
        break unless ok
        io.print op
      end
      break if io.closed?
    end
    io.print "221 bye\r\n"
    io.close
  end
end

def start_server
  a = SMTPServer.new(10025)
  a.start
  a.join
end

if RAILS_ENV == "production"
  pid = fork do
    start_server
  end
  Process.detach pid
  File.open("/home/quinn/promoweb/tmp/pids/smtp_daemon.rb.pid", "w") { |f| f.puts(pid) }
else
  if ARGV.empty?
    start_server
  else
    puts "Single Shot: #{ARGV[0].inspect} #{ARGV[1].inspect}"
    msg = Message.new
    msg.process_fake('test', ARGV[0], 'quinn@dev.qutek.net', File.open(ARGV[1]).read)
  end
end
