# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20131122142807) do

  create_table "addresses", :force => true do |t|
    t.string "name"
    t.string "address1"
    t.string "address2"
    t.string "city"
    t.string "state"
    t.string "postalcode"
    t.string "country",    :limit => 2, :default => "US"
  end

  create_table "aliases", :id => false, :force => true do |t|
    t.integer "sticky"
    t.string  "alias",    :limit => 128
    t.string  "command",  :limit => 4096
    t.string  "hostname", :limit => 256
  end

  add_index "aliases", ["alias"], :name => "alias1"

  create_table "artwork_groups", :force => true do |t|
    t.string   "name"
    t.text     "description"
    t.integer  "customer_id", :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "artwork_groups", ["name", "customer_id"], :name => "artwork_groups_name_customer", :unique => true

  create_table "artwork_tags", :force => true do |t|
    t.string  "name"
    t.integer "artwork_id", :null => false
  end

  add_index "artwork_tags", ["name", "artwork_id"], :name => "artwork_tags_artwork_name", :unique => true

  create_table "artworks", :force => true do |t|
    t.string   "name"
    t.string   "art_file_name"
    t.text     "customer_notes"
    t.datetime "created_at",       :null => false
    t.datetime "updated_at",       :null => false
    t.text     "our_notes"
    t.integer  "user_id"
    t.string   "host"
    t.integer  "group_id",         :null => false
    t.string   "art_content_type"
    t.integer  "art_file_size"
  end

  add_index "artworks", ["art_file_name", "group_id"], :name => "artworks_file_group_id", :unique => true

  create_table "bills", :force => true do |t|
    t.integer  "purchase_id",                         :null => false
    t.string   "quickbooks_ref",      :default => ""
    t.string   "quickbooks_id"
    t.datetime "quickbooks_at"
    t.string   "quickbooks_sequence"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "call_logs", :force => true do |t|
    t.string   "uuid",                             :limit => 36,                    :null => false
    t.string   "caller_number",                                                     :null => false
    t.string   "caller_name"
    t.string   "called_number",                                                     :null => false
    t.boolean  "inbound",                                        :default => false, :null => false
    t.integer  "customer_id"
    t.datetime "create_time",                                                       :null => false
    t.datetime "ring_time"
    t.datetime "answered_time"
    t.integer  "user_id"
    t.string   "chan_name"
    t.string   "end_reason"
    t.datetime "end_time"
    t.integer  "rtp_audio_in_raw_bytes",                         :default => 0,     :null => false
    t.integer  "rtp_audio_in_media_bytes",                       :default => 0,     :null => false
    t.integer  "rtp_audio_in_packet_count",                      :default => 0,     :null => false
    t.integer  "rtp_audio_in_media_packet_count",                :default => 0,     :null => false
    t.integer  "rtp_audio_in_skip_packet_count",                 :default => 0,     :null => false
    t.integer  "rtp_audio_in_jb_packet_count",                   :default => 0,     :null => false
    t.integer  "rtp_audio_in_dtmf_packet_count",                 :default => 0,     :null => false
    t.integer  "rtp_audio_in_cng_packet_count",                  :default => 0,     :null => false
    t.integer  "rtp_audio_in_flush_packet_count",                :default => 0,     :null => false
    t.integer  "rtp_audio_in_largest_jb_size",                   :default => 0,     :null => false
    t.integer  "rtp_audio_out_raw_bytes",                        :default => 0,     :null => false
    t.integer  "rtp_audio_out_media_bytes",                      :default => 0,     :null => false
    t.integer  "rtp_audio_out_packet_count",                     :default => 0,     :null => false
    t.integer  "rtp_audio_out_media_packet_count",               :default => 0,     :null => false
    t.integer  "rtp_audio_out_skip_packet_count",                :default => 0,     :null => false
    t.integer  "rtp_audio_out_jb_packet_count",                  :default => 0,     :null => false
    t.integer  "rtp_audio_out_dtmf_packet_count",                :default => 0,     :null => false
    t.integer  "rtp_audio_out_cng_packet_count",                 :default => 0,     :null => false
    t.integer  "rtp_audio_out_flush_packet_count",               :default => 0,     :null => false
    t.integer  "rtp_audio_out_largest_jb_size",                  :default => 0,     :null => false
  end

  create_table "calls", :id => false, :force => true do |t|
    t.string  "call_uuid"
    t.string  "call_created",       :limit => 128
    t.integer "call_created_epoch"
    t.string  "function",           :limit => 1024
    t.string  "caller_cid_name",    :limit => 1024
    t.string  "caller_cid_num",     :limit => 256
    t.string  "caller_dest_num",    :limit => 256
    t.string  "caller_chan_name",   :limit => 1024
    t.string  "caller_uuid",        :limit => 256
    t.string  "callee_cid_name",    :limit => 1024
    t.string  "callee_cid_num",     :limit => 256
    t.string  "callee_dest_num",    :limit => 256
    t.string  "callee_chan_name",   :limit => 1024
    t.string  "callee_uuid",        :limit => 256
    t.string  "hostname",           :limit => 256
  end

  add_index "calls", ["call_uuid", "hostname"], :name => "eeuuindex2"
  add_index "calls", ["callee_uuid", "hostname"], :name => "eeuuindex"
  add_index "calls", ["caller_uuid", "hostname"], :name => "eruuindex"
  add_index "calls", ["hostname"], :name => "calls1"
  add_index "calls", ["hostname"], :name => "callsidx1"

  create_table "categories", :force => true do |t|
    t.integer  "parent_id"
    t.integer  "lft",                                              :null => false
    t.integer  "rgt",                                              :null => false
    t.string   "name",            :limit => 32,                    :null => false
    t.datetime "updated_at",                                       :null => false
    t.tsvector "search_vector"
    t.text     "description"
    t.boolean  "pinned",                        :default => false, :null => false
    t.string   "google_category"
  end

  add_index "categories", ["name", "parent_id"], :name => "name_categories", :unique => true
  add_index "categories", ["search_vector"], :name => "categories_fts_vectors_index"

  create_table "categories_keywords", :id => false, :force => true do |t|
    t.integer "category_id", :null => false
    t.integer "keyword_id",  :null => false
    t.string  "name"
  end

  create_table "categories_products", :id => false, :force => true do |t|
    t.integer "product_id",  :null => false
    t.integer "category_id", :null => false
    t.boolean "pinned"
  end

  add_index "categories_products", ["product_id", "category_id"], :name => "unique_categories_products", :unique => true

  create_table "channels", :id => false, :force => true do |t|
    t.string  "uuid",             :limit => 256
    t.string  "direction",        :limit => 32
    t.string  "created",          :limit => 128
    t.integer "created_epoch"
    t.string  "name",             :limit => 1024
    t.string  "state",            :limit => 64
    t.string  "cid_name",         :limit => 1024
    t.string  "cid_num",          :limit => 256
    t.string  "ip_addr",          :limit => 256
    t.string  "dest",             :limit => 1024
    t.string  "application",      :limit => 128
    t.string  "application_data", :limit => 4096
    t.string  "dialplan",         :limit => 128
    t.string  "context",          :limit => 128
    t.string  "read_codec",       :limit => 128
    t.string  "read_rate",        :limit => 32
    t.string  "read_bit_rate",    :limit => 32
    t.string  "write_codec",      :limit => 128
    t.string  "write_rate",       :limit => 32
    t.string  "write_bit_rate",   :limit => 32
    t.string  "secure",           :limit => 32
    t.string  "hostname",         :limit => 256
    t.string  "presence_id",      :limit => 4096
    t.string  "presence_data",    :limit => 4096
    t.string  "callstate",        :limit => 64
    t.string  "callee_name",      :limit => 1024
    t.string  "callee_num",       :limit => 256
    t.string  "callee_direction", :limit => 5
    t.string  "call_uuid",        :limit => 256
    t.string  "sent_callee_name", :limit => 1024
    t.string  "sent_callee_num",  :limit => 256
  end

  add_index "channels", ["call_uuid"], :name => "uuindex2"
  add_index "channels", ["hostname"], :name => "channels1"
  add_index "channels", ["hostname"], :name => "chidx1"
  add_index "channels", ["uuid"], :name => "uuindex"

  create_table "commissions", :force => true do |t|
    t.integer  "user_id",             :null => false
    t.integer  "payed",               :null => false
    t.text     "comment"
    t.datetime "quickbooks_at"
    t.string   "quickbooks_id"
    t.string   "quickbooks_sequence"
    t.string   "quickbooks_ref"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "complete", :id => false, :force => true do |t|
    t.integer "sticky"
    t.string  "a1",       :limit => 128
    t.string  "a2",       :limit => 128
    t.string  "a3",       :limit => 128
    t.string  "a4",       :limit => 128
    t.string  "a5",       :limit => 128
    t.string  "a6",       :limit => 128
    t.string  "a7",       :limit => 128
    t.string  "a8",       :limit => 128
    t.string  "a9",       :limit => 128
    t.string  "a10",      :limit => 128
    t.string  "hostname", :limit => 256
  end

  add_index "complete", ["a1", "a2", "a3", "a4", "a5", "a6", "a7", "a8", "a9", "a10", "hostname"], :name => "complete11"
  add_index "complete", ["a1", "hostname"], :name => "complete1"
  add_index "complete", ["a10", "hostname"], :name => "complete10"
  add_index "complete", ["a2", "hostname"], :name => "complete2"
  add_index "complete", ["a3", "hostname"], :name => "complete3"
  add_index "complete", ["a4", "hostname"], :name => "complete4"
  add_index "complete", ["a5", "hostname"], :name => "complete5"
  add_index "complete", ["a6", "hostname"], :name => "complete6"
  add_index "complete", ["a7", "hostname"], :name => "complete7"
  add_index "complete", ["a8", "hostname"], :name => "complete8"
  add_index "complete", ["a9", "hostname"], :name => "complete9"

  create_table "customer_tasks", :force => true do |t|
    t.integer  "customer_id",                :null => false
    t.text     "comment"
    t.datetime "created_at",                 :null => false
    t.datetime "updated_at",                 :null => false
    t.integer  "user_id"
    t.string   "data",        :limit => nil
    t.string   "type",                       :null => false
    t.string   "host"
    t.boolean  "active"
    t.datetime "expected_at"
  end

  add_index "customer_tasks", ["customer_id", "active", "type"], :name => "customer_tasks_unique", :unique => true

  create_table "customers", :force => true do |t|
    t.string   "uuid",                :limit => 22,                    :null => false
    t.string   "username"
    t.string   "password"
    t.string   "company_name"
    t.string   "person_name"
    t.integer  "default_address_id"
    t.integer  "ship_address_id"
    t.integer  "bill_address_id"
    t.datetime "created_at",                                           :null => false
    t.datetime "updated_at",                                           :null => false
    t.integer  "user_id"
    t.string   "quickbooks_id"
    t.datetime "quickbooks_at"
    t.string   "quickbooks_sequence"
    t.boolean  "solicit",                           :default => false, :null => false
    t.text     "our_notes"
  end

  add_index "customers", ["username"], :name => "unique_username", :unique => true
  add_index "customers", ["uuid"], :name => "unique_uuid", :unique => true

  create_table "decoration_price_entries", :force => true do |t|
    t.integer "group_id"
    t.integer "minimum"
    t.integer "fixed_divisor",           :default => 1,   :null => false
    t.integer "fixed_offset",            :default => 0,   :null => false
    t.integer "marginal_divisor",        :default => 1,   :null => false
    t.integer "marginal_offset",         :default => 0,   :null => false
    t.integer "fixed_id"
    t.float   "fixed_price_const",       :default => 0.0, :null => false
    t.float   "fixed_price_exp",         :default => 0.0, :null => false
    t.integer "fixed_price_marginal",    :default => 0
    t.integer "fixed_price_fixed",       :default => 0
    t.integer "marginal_id"
    t.float   "marginal_price_const",    :default => 0.0, :null => false
    t.float   "marginal_price_exp",      :default => 0.0, :null => false
    t.integer "marginal_price_marginal", :default => 0
    t.integer "marginal_price_fixed",    :default => 0
  end

  add_index "decoration_price_entries", ["group_id", "minimum"], :name => "minimum_decoration_price_entries", :unique => true

  create_table "decoration_price_groups", :force => true do |t|
    t.integer "technique_id", :null => false
    t.integer "supplier_id",  :null => false
  end

  add_index "decoration_price_groups", ["supplier_id", "technique_id"], :name => "unique_decoration_price_groups", :unique => true

  create_table "decoration_techniques", :force => true do |t|
    t.string   "name",                :limit => 64,                :null => false
    t.integer  "parent_id"
    t.string   "unit_name",           :limit => 16
    t.integer  "unit_default",                      :default => 1
    t.string   "quickbooks_id"
    t.datetime "quickbooks_at"
    t.string   "quickbooks_sequence"
  end

  add_index "decoration_techniques", ["name"], :name => "unique_decoration_techniques", :unique => true

  create_table "decorations", :force => true do |t|
    t.integer "product_id",                      :null => false
    t.integer "technique_id",                    :null => false
    t.text    "location"
    t.integer "limit"
    t.float   "width"
    t.float   "height"
    t.float   "diameter"
    t.float   "triangle"
    t.boolean "deleted",      :default => false, :null => false
  end

  add_index "decorations", ["product_id"], :name => "decorations_product_id"

  create_table "delegatables", :force => true do |t|
    t.string  "name"
    t.integer "user_id", :null => false
  end

  add_index "delegatables", ["name", "user_id"], :name => "delegatables_uniq", :unique => true

  create_table "email_addresses", :force => true do |t|
    t.integer "customer_id"
    t.string  "address"
    t.string  "notes"
  end

  add_index "email_addresses", ["address"], :name => "index_email_addresses_on_address"

  create_table "engine_schema_info", :id => false, :force => true do |t|
    t.string  "engine_name"
    t.integer "version"
  end

  create_table "factual_businesses", :force => true do |t|
    t.string   "factual_id"
    t.string   "name"
    t.string   "address"
    t.string   "address_extended"
    t.string   "po_box"
    t.string   "neighborhood"
    t.string   "locality"
    t.string   "region"
    t.string   "country"
    t.string   "postcode"
    t.float    "latitude"
    t.float    "longitude"
    t.string   "tel"
    t.string   "fax"
    t.string   "website"
    t.string   "email"
    t.string   "categories"
    t.string   "hours"
    t.datetime "created_at",       :null => false
    t.datetime "updated_at",       :null => false
  end

  create_table "interfaces", :id => false, :force => true do |t|
    t.string "type",        :limit => 128
    t.string "name",        :limit => 1024
    t.string "description", :limit => 4096
    t.string "ikey",        :limit => 1024
    t.string "filename",    :limit => 4096
    t.string "syntax",      :limit => 4096
    t.string "hostname",    :limit => 256
  end

  create_table "invoice_entries", :force => true do |t|
    t.integer  "invoice_id",                  :null => false
    t.string   "type",                        :null => false
    t.integer  "entry_id",                    :null => false
    t.text     "description", :default => "", :null => false
    t.text     "data"
    t.integer  "total_price", :default => 0,  :null => false
    t.integer  "quantity",    :default => 1,  :null => false
    t.datetime "created_at",                  :null => false
    t.datetime "updated_at",                  :null => false
  end

  create_table "invoices", :force => true do |t|
    t.integer  "order_id",                             :null => false
    t.string   "quickbooks_ref"
    t.string   "quickbooks_id"
    t.datetime "quickbooks_at"
    t.string   "quickbooks_sequence"
    t.datetime "created_at",                           :null => false
    t.datetime "updated_at",                           :null => false
    t.text     "comment"
    t.float    "tax_rate",            :default => 0.0, :null => false
    t.string   "tax_type"
  end

  create_table "keywords", :force => true do |t|
    t.string "phrase"
  end

  create_table "nat", :id => false, :force => true do |t|
    t.integer "sticky"
    t.integer "port"
    t.integer "proto"
    t.string  "hostname", :limit => 256
  end

  add_index "nat", ["port", "proto", "hostname"], :name => "nat_map_port_proto"

  create_table "order_entries", :force => true do |t|
    t.integer  "order_id",                      :null => false
    t.string   "name"
    t.text     "description",   :default => ""
    t.integer  "price",         :default => 0,  :null => false
    t.integer  "cost",          :default => 0
    t.integer  "quantity",      :default => 1,  :null => false
    t.string   "quickbooks_id"
    t.datetime "quickbooks_at"
    t.datetime "created_at",                    :null => false
    t.datetime "updated_at",                    :null => false
  end

  create_table "order_item_decorations", :force => true do |t|
    t.integer  "order_item_id",               :null => false
    t.integer  "technique_id",                :null => false
    t.integer  "decoration_id"
    t.integer  "count"
    t.integer  "marginal_price"
    t.integer  "fixed_price"
    t.integer  "marginal_cost"
    t.integer  "fixed_cost"
    t.datetime "created_at",                  :null => false
    t.datetime "updated_at",                  :null => false
    t.text     "description"
    t.integer  "artwork_group_id"
    t.text     "our_notes"
    t.string   "quickbooks_po_marginal_id"
    t.string   "quickbooks_po_fixed_id"
    t.string   "quickbooks_bill_marginal_id"
    t.string   "quickbooks_bill_fixed_id"
  end

  create_table "order_item_entries", :force => true do |t|
    t.integer  "order_item_id",                               :null => false
    t.string   "name"
    t.text     "description",                 :default => "", :null => false
    t.integer  "marginal_price",              :default => 0
    t.integer  "fixed_price",                 :default => 0
    t.integer  "marginal_cost",               :default => 0
    t.integer  "fixed_cost",                  :default => 0
    t.datetime "created_at",                                  :null => false
    t.datetime "updated_at",                                  :null => false
    t.string   "quickbooks_po_marginal_id"
    t.string   "quickbooks_po_fixed_id"
    t.string   "quickbooks_bill_marginal_id"
    t.string   "quickbooks_bill_fixed_id"
  end

  create_table "order_item_tasks", :force => true do |t|
    t.integer  "order_item_id",                :null => false
    t.text     "comment"
    t.datetime "created_at",                   :null => false
    t.datetime "updated_at",                   :null => false
    t.integer  "user_id"
    t.string   "data",          :limit => nil
    t.string   "type",                         :null => false
    t.string   "host"
    t.boolean  "active"
    t.datetime "expected_at"
  end

  add_index "order_item_tasks", ["order_item_id", "active", "type"], :name => "order_item_tasks_unique", :unique => true

  create_table "order_item_variants", :force => true do |t|
    t.integer  "order_item_id",                      :null => false
    t.integer  "variant_id"
    t.integer  "quantity",                           :null => false
    t.string   "imprint_colors",     :default => "", :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "quickbooks_po_id"
    t.string   "quickbooks_bill_id"
  end

  add_index "order_item_variants", ["order_item_id", "variant_id"], :name => "order_item_variants_pair", :unique => true

  create_table "order_items", :force => true do |t|
    t.integer  "order_id",                                       :null => false
    t.integer  "price_group_id",                                 :null => false
    t.text     "customer_notes"
    t.text     "our_notes"
    t.integer  "marginal_price"
    t.integer  "fixed_price"
    t.integer  "marginal_cost"
    t.integer  "fixed_cost"
    t.date     "ship_date"
    t.string   "ship_tracking"
    t.datetime "created_at",                                     :null => false
    t.datetime "updated_at",                                     :null => false
    t.integer  "purchase_id"
    t.string   "shipping_type"
    t.string   "shipping_code"
    t.integer  "shipping_price"
    t.integer  "shipping_cost"
    t.string   "quickbooks_po_id"
    t.string   "quickbooks_po_shipping_id"
    t.string   "quickbooks_bill_id"
    t.string   "quickbooks_bill_shipping_id"
    t.integer  "product_id",                                     :null => false
    t.boolean  "sample_requested",            :default => false, :null => false
  end

  add_index "order_items", ["order_id"], :name => "order_items_order_id"
  add_index "order_items", ["product_id"], :name => "order_items_product_id"

  create_table "order_tasks", :force => true do |t|
    t.integer  "order_id",                   :null => false
    t.text     "comment"
    t.datetime "created_at",                 :null => false
    t.datetime "updated_at",                 :null => false
    t.integer  "user_id"
    t.string   "data",        :limit => nil
    t.string   "type",                       :null => false
    t.string   "host"
    t.boolean  "active"
    t.datetime "expected_at"
  end

  add_index "order_tasks", ["order_id", "active", "type"], :name => "order_tasks_unique", :unique => true

  create_table "orders", :force => true do |t|
    t.integer  "customer_id",                                                  :null => false
    t.date     "delivery_date"
    t.string   "event_nature"
    t.string   "special"
    t.text     "customer_notes"
    t.text     "our_notes"
    t.datetime "created_at",                                                   :null => false
    t.datetime "updated_at",                                                   :null => false
    t.boolean  "process_order"
    t.integer  "user_id"
    t.text     "our_comments"
    t.string   "terms"
    t.boolean  "rush"
    t.string   "ship_method"
    t.string   "fob"
    t.boolean  "closed",                                    :default => false
    t.string   "quickbooks_id"
    t.datetime "quickbooks_at"
    t.string   "quickbooks_sequence"
    t.string   "urgent_note"
    t.integer  "total_price_cache",                                            :null => false
    t.integer  "total_cost_cache",                                             :null => false
    t.float    "commission"
    t.integer  "payed",                                     :default => 0,     :null => false
    t.boolean  "settled",                                   :default => false, :null => false
    t.boolean  "delivery_date_not_important",               :default => false, :null => false
    t.float    "tax_rate",                                  :default => 0.0,   :null => false
    t.string   "tax_type"
    t.string   "purchase_order",              :limit => 32
  end

  create_table "payment_methods", :force => true do |t|
    t.integer  "customer_id",                  :null => false
    t.integer  "address_id",                   :null => false
    t.string   "type",                         :null => false
    t.string   "name",                         :null => false
    t.string   "display_number",               :null => false
    t.string   "billing_id"
    t.datetime "created_at",                   :null => false
    t.datetime "updated_at",                   :null => false
    t.string   "sub_type",       :limit => 18
  end

  create_table "payment_transactions", :force => true do |t|
    t.integer  "method_id",                                           :null => false
    t.integer  "order_id",                                            :null => false
    t.string   "type",                                                :null => false
    t.integer  "amount",                                              :null => false
    t.text     "comment"
    t.datetime "created_at",                                          :null => false
    t.string   "number"
    t.text     "data"
    t.string   "quickbooks_id"
    t.datetime "quickbooks_at"
    t.string   "quickbooks_sequence"
    t.string   "auth_code",           :limit => 16
    t.integer  "invoice_id"
    t.integer  "order_number"
    t.boolean  "active",                            :default => true, :null => false
  end

  create_table "permissions", :force => true do |t|
    t.string   "name"
    t.integer  "user_id",    :null => false
    t.integer  "order_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "permissions", ["name", "user_id", "order_id"], :name => "permissions_uniq", :unique => true

  create_table "phone_numbers", :force => true do |t|
    t.integer "customer_id"
    t.string  "name"
    t.integer "number",        :limit => 8
    t.string  "number_string"
    t.string  "notes"
  end

  add_index "phone_numbers", ["number"], :name => "index_phone_numbers_on_number"

  create_table "phones", :force => true do |t|
    t.integer  "user_id",    :null => false
    t.string   "name",       :null => false
    t.string   "identifier"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "plugin_schema_info", :id => false, :force => true do |t|
    t.string  "plugin_name"
    t.integer "version"
  end

  create_table "price_entries", :force => true do |t|
    t.integer "price_group_id", :null => false
    t.integer "minimum",        :null => false
    t.integer "fixed"
    t.integer "marginal"
  end

  add_index "price_entries", ["price_group_id", "minimum"], :name => "minimum_price_entries", :unique => true

  create_table "price_groups", :force => true do |t|
    t.string  "currency",    :limit => 4
    t.integer "source_id"
    t.string  "uri"
    t.float   "coefficient"
    t.float   "exponent"
  end

  create_table "price_groups_variants", :id => false, :force => true do |t|
    t.integer "price_group_id", :null => false
    t.integer "variant_id",     :null => false
  end

  add_index "price_groups_variants", ["variant_id", "price_group_id"], :name => "unique_price_groups_variants", :unique => true

  create_table "price_sources", :force => true do |t|
    t.string   "name",       :null => false
    t.string   "url"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "price_sources", ["name"], :name => "name_price_sources", :unique => true

  create_table "product_images", :force => true do |t|
    t.integer  "product_id",   :null => false
    t.string   "supplier_ref"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "tag"
  end

  add_index "product_images", ["product_id", "supplier_ref"], :name => "product_images_supplier_ref_uniq", :unique => true
  add_index "product_images", ["product_id"], :name => "product_images_product_id"

  create_table "product_images_variants", :id => false, :force => true do |t|
    t.integer "product_image_id", :null => false
    t.integer "variant_id",       :null => false
  end

  add_index "product_images_variants", ["product_image_id"], :name => "product_images_variants_product_images_id"
  add_index "product_images_variants", ["variant_id"], :name => "product_images_variants_variant_id"

  create_table "products", :force => true do |t|
    t.string   "supplier_num",            :limit => 32
    t.integer  "supplier_id",                                              :null => false
    t.string   "name",                                                     :null => false
    t.text     "description"
    t.integer  "price_min_cache"
    t.integer  "price_max_cache"
    t.integer  "price_comp_cache"
    t.integer  "featured_id"
    t.datetime "featured_at"
    t.float    "package_weight"
    t.integer  "package_units"
    t.float    "package_unit_weight"
    t.float    "package_height"
    t.float    "package_width"
    t.float    "package_length"
    t.datetime "created_at",                                               :null => false
    t.datetime "updated_at",                                               :null => false
    t.boolean  "deleted",                               :default => false, :null => false
    t.string   "quickbooks_id"
    t.datetime "quickbooks_at"
    t.string   "quickbooks_sequence"
    t.tsvector "search_vector"
    t.text     "data"
    t.string   "price_fullstring_cache"
    t.string   "price_shortstring_cache", :limit => 12
    t.integer  "lead_time_normal_min"
    t.integer  "lead_time_normal_max"
    t.integer  "lead_time_rush"
    t.float    "lead_time_rush_charge"
  end

  add_index "products", ["search_vector"], :name => "products_fts_vectors_index"
  add_index "products", ["supplier_id", "supplier_num"], :name => "supplier_num_products", :unique => true

  create_table "properties", :force => true do |t|
    t.string "name",  :limit => 32, :null => false
    t.text   "value",               :null => false
  end

  add_index "properties", ["name", "value"], :name => "unique_properties", :unique => true

  create_table "properties_variants", :id => false, :force => true do |t|
    t.integer "property_id", :null => false
    t.integer "variant_id",  :null => false
  end

  add_index "properties_variants", ["variant_id", "property_id"], :name => "unique_properties_variants", :unique => true

  create_table "purchase_entries", :force => true do |t|
    t.integer  "purchase_id",                        :null => false
    t.text     "description",        :default => "", :null => false
    t.integer  "price"
    t.integer  "cost",               :default => 0,  :null => false
    t.integer  "quantity",           :default => 1,  :null => false
    t.datetime "created_at",                         :null => false
    t.datetime "updated_at",                         :null => false
    t.string   "quickbooks_po_id"
    t.string   "quickbooks_bill_id"
  end

  create_table "purchase_orders", :force => true do |t|
    t.integer  "purchase_id",                            :null => false
    t.boolean  "sent",                :default => false, :null => false
    t.string   "quickbooks_ref"
    t.string   "quickbooks_id"
    t.datetime "quickbooks_at"
    t.string   "quickbooks_sequence"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "purchase_orders", ["quickbooks_ref"], :name => "purchase_orders_quickbooks_ref", :unique => true

  create_table "purchases", :force => true do |t|
    t.datetime "created_at",                  :null => false
    t.datetime "updated_at",                  :null => false
    t.text     "comment",     :default => "", :null => false
    t.integer  "supplier_id"
  end

  create_table "quickbooks_deletes", :force => true do |t|
    t.string "txn_class"
    t.string "txn_type"
    t.string "txn_id"
  end

  create_table "recovery", :id => false, :force => true do |t|
    t.string "runtime_uuid"
    t.string "technology"
    t.string "profile_name"
    t.string "hostname"
    t.string "uuid"
    t.text   "metadata"
  end

  add_index "recovery", ["profile_name"], :name => "recovery2"
  add_index "recovery", ["technology"], :name => "recovery1"
  add_index "recovery", ["uuid"], :name => "recovery3"

  create_table "registrations", :id => false, :force => true do |t|
    t.string  "reg_user",      :limit => 256
    t.string  "realm",         :limit => 256
    t.string  "token",         :limit => 256
    t.text    "url"
    t.integer "expires"
    t.string  "network_ip",    :limit => 256
    t.string  "network_port",  :limit => 256
    t.string  "network_proto", :limit => 256
    t.string  "hostname",      :limit => 256
    t.string  "metadata",      :limit => 256
  end

  add_index "registrations", ["reg_user", "realm", "hostname"], :name => "regindex1"

  create_table "shipping_rates", :force => true do |t|
    t.string   "type"
    t.integer  "customer_id", :null => false
    t.integer  "product_id",  :null => false
    t.integer  "quantity"
    t.text     "data"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "shipping_rates", ["customer_id", "product_id", "quantity"], :name => "unique_shipping_rates", :unique => true

  create_table "suppliers", :force => true do |t|
    t.string   "name",                     :limit => 64
    t.integer  "price_source_id"
    t.string   "web"
    t.string   "status"
    t.string   "description"
    t.text     "notes"
    t.datetime "created_at",                                            :null => false
    t.datetime "updated_at",                                            :null => false
    t.string   "quickbooks_id"
    t.datetime "quickbooks_at"
    t.string   "quickbooks_sequence"
    t.integer  "address_id"
    t.string   "artwork_email"
    t.string   "po_email"
    t.integer  "fax",                      :limit => 8
    t.integer  "phone",                    :limit => 8
    t.integer  "parent_id"
    t.string   "po_note"
    t.string   "inside_sales_name"
    t.string   "inside_sales_email"
    t.integer  "inside_sales_phone",       :limit => 8
    t.string   "accounting_name"
    t.string   "accounting_email"
    t.integer  "accounting_phone",         :limit => 8
    t.string   "customer_service_name"
    t.string   "customer_service_email"
    t.integer  "customer_service_phone",   :limit => 8
    t.string   "problem_resolution_name"
    t.string   "problem_resolution_email"
    t.integer  "problem_resolution_phone", :limit => 8
    t.integer  "credit",                                 :default => 0, :null => false
    t.string   "account_number"
    t.string   "samples_email"
    t.text     "standard_colors"
    t.string   "login_url"
  end

  add_index "suppliers", ["parent_id", "name"], :name => "name_suppliers", :unique => true

  create_table "tags", :force => true do |t|
    t.string  "name",       :limit => 16, :null => false
    t.integer "product_id",               :null => false
  end

  create_table "tasks", :id => false, :force => true do |t|
    t.integer "task_id"
    t.string  "task_desc",        :limit => 4096
    t.string  "task_group",       :limit => 1024
    t.integer "task_sql_manager"
    t.string  "hostname",         :limit => 256
  end

  add_index "tasks", ["hostname", "task_id"], :name => "tasks1"

  create_table "users", :force => true do |t|
    t.string  "login",                  :limit => 80,                    :null => false
    t.string  "password",                                                :null => false
    t.string  "name"
    t.string  "email"
    t.integer "current_order_id"
    t.float   "commission"
    t.integer "extension"
    t.integer "direct_phone_number",    :limit => 8
    t.string  "external_phone_number",  :limit => 24
    t.boolean "external_phone_enable",                :default => false, :null => false
    t.boolean "external_phone_all",                   :default => false, :null => false
    t.integer "external_phone_timeout",               :default => 15,    :null => false
    t.string  "phone_password"
  end

  add_index "users", ["login"], :name => "login_users", :unique => true

  create_table "variants", :force => true do |t|
    t.integer  "product_id",                                    :null => false
    t.string   "supplier_num", :limit => 64,                    :null => false
    t.datetime "created_at",                                    :null => false
    t.datetime "updated_at",                                    :null => false
    t.boolean  "deleted",                    :default => false, :null => false
  end

  add_index "variants", ["product_id", "supplier_num"], :name => "supplier_num_variants", :unique => true

  create_table "warehouses", :force => true do |t|
    t.integer "supplier_id"
    t.string  "address_1"
    t.string  "address_2"
    t.string  "city"
    t.string  "state"
    t.string  "postalcode"
  end

  add_foreign_key "artwork_groups", "customers", name: "artwork_groups_customer_id_fkey"

  add_foreign_key "artwork_tags", "artworks", name: "artwork_tags_artwork_id_fkey"

  add_foreign_key "artworks", "artwork_groups", name: "artworks_group_id_fkey", column: "group_id"
  add_foreign_key "artworks", "users", name: "artworks_user_id_fkey"

  add_foreign_key "bills", "purchases", name: "bills_purchase_id"

  add_foreign_key "call_logs", "customers", name: "call_logs_customer_id_fk"
  add_foreign_key "call_logs", "users", name: "call_logs_user_id_fk"

  add_foreign_key "categories", "categories", name: "categories_parent_id_fkey", column: "parent_id"

  add_foreign_key "categories_keywords", "categories", name: "categories_keywords_category_id_fkey"
  add_foreign_key "categories_keywords", "keywords", name: "categories_keywords_keyword_id_fkey"

  add_foreign_key "categories_products", "categories", name: "categories_products_category_id_fkey"
  add_foreign_key "categories_products", "products", name: "categories_products_product_id_fkey"

  add_foreign_key "commissions", "users", name: "commissions_user_id_fk"

  add_foreign_key "customer_tasks", "customers", name: "customer_tasks_customer_id_fkey"
  add_foreign_key "customer_tasks", "users", name: "customer_tasks_user_id_fkey"

  add_foreign_key "customers", "addresses", name: "customers_bill_address_id_fkey", column: "bill_address_id"
  add_foreign_key "customers", "addresses", name: "customers_default_address_id_fkey", column: "default_address_id"
  add_foreign_key "customers", "addresses", name: "customers_ship_address_id_fkey", column: "ship_address_id"
  add_foreign_key "customers", "users", name: "fkey_customers_on_user_id"

  add_foreign_key "decoration_price_entries", "decoration_price_groups", name: "decoration_price_entries_group_id_fkey", column: "group_id"
  add_foreign_key "decoration_price_entries", "price_groups", name: "decoration_price_entries_fixed_id_fkey", column: "fixed_id"
  add_foreign_key "decoration_price_entries", "price_groups", name: "decoration_price_entries_marginal_id_fkey", column: "marginal_id"

  add_foreign_key "decoration_price_groups", "decoration_techniques", name: "decoration_price_groups_technique_id_fkey", column: "technique_id"
  add_foreign_key "decoration_price_groups", "suppliers", name: "decoration_price_groups_supplier_id_fkey"

  add_foreign_key "decoration_techniques", "decoration_techniques", name: "decoration_techniques_parent_id_fkey", column: "parent_id"

  add_foreign_key "decorations", "decoration_techniques", name: "decorations_technique_id_fkey", column: "technique_id"
  add_foreign_key "decorations", "products", name: "decorations_product_id_fkey"

  add_foreign_key "delegatables", "users", name: "delegatables_user_id_fkey"

  add_foreign_key "email_addresses", "customers", name: "email_addresses_customer_id_fk"

  add_foreign_key "invoice_entries", "invoices", name: "invoice_entries_invoice_id_fkey"

  add_foreign_key "invoices", "orders", name: "invoices_order_id_fkey"

  add_foreign_key "order_entries", "orders", name: "order_entries_order_id_fkey"

  add_foreign_key "order_item_decorations", "artwork_groups", name: "order_item_decorations_artwork_group_id_fkey"
  add_foreign_key "order_item_decorations", "decoration_techniques", name: "order_item_decorations_technique_id_fkey", column: "technique_id"
  add_foreign_key "order_item_decorations", "decorations", name: "order_item_decorations_decoration_id_fkey"
  add_foreign_key "order_item_decorations", "order_items", name: "order_item_decorations_order_item_id_fkey"

  add_foreign_key "order_item_entries", "order_items", name: "order_item_entries_order_item_id_fkey"

  add_foreign_key "order_item_tasks", "order_items", name: "order_item_tasks_order_item_id_fkey"
  add_foreign_key "order_item_tasks", "users", name: "order_item_tasks_user_id_fkey"

  add_foreign_key "order_item_variants", "order_items", name: "order_item_variants_order_item_id_fkey"
  add_foreign_key "order_item_variants", "variants", name: "order_item_variants_variant_id_fkey"

  add_foreign_key "order_items", "orders", name: "order_items_order_id_fkey"
  add_foreign_key "order_items", "price_groups", name: "order_items_price_group_id_fkey"
  add_foreign_key "order_items", "products", name: "order_items_product_id_fk"
  add_foreign_key "order_items", "purchases", name: "order_items_purchase_order_id_fkey"

  add_foreign_key "order_tasks", "orders", name: "order_tasks_order_id_fkey"
  add_foreign_key "order_tasks", "users", name: "order_tasks_user_id_fkey"

  add_foreign_key "orders", "customers", name: "orders_customer_id_fkey"
  add_foreign_key "orders", "users", name: "fkey_orders_on_user_id"

  add_foreign_key "payment_methods", "addresses", name: "payment_methods_address_id_fkey"
  add_foreign_key "payment_methods", "customers", name: "payment_methods_customer_id_fkey"

  add_foreign_key "payment_transactions", "invoices", name: "payment_transactions_invoice_id_fk"
  add_foreign_key "payment_transactions", "orders", name: "payment_transactions_order_id_fkey"
  add_foreign_key "payment_transactions", "payment_methods", name: "payment_transactions_method_id_fkey", column: "method_id"

  add_foreign_key "permissions", "orders", name: "permissions_order_id_fkey"
  add_foreign_key "permissions", "users", name: "permissions_user_id_fkey"

  add_foreign_key "phone_numbers", "customers", name: "phone_numbers_customer_id_fk"

  add_foreign_key "phones", "users", name: "phones_user_id_fk"

  add_foreign_key "price_entries", "price_groups", name: "price_entries_price_group_id_fkey"

  add_foreign_key "price_groups", "price_sources", name: "price_groups_source_id_fkey", column: "source_id"

  add_foreign_key "price_groups_variants", "price_groups", name: "price_groups_variants_price_group_id_fkey"
  add_foreign_key "price_groups_variants", "variants", name: "price_groups_variants_variant_id_fkey"

  add_foreign_key "products", "categories", name: "products_featured_id_fkey", column: "featured_id"
  add_foreign_key "products", "suppliers", name: "products_supplier_id_fkey"

  add_foreign_key "properties_variants", "properties", name: "properties_variants_property_id_fkey"
  add_foreign_key "properties_variants", "variants", name: "properties_variants_variant_id_fkey"

  add_foreign_key "purchase_entries", "purchases", name: "purchase_order_entries_purchase_order_id_fkey"

  add_foreign_key "purchase_orders", "purchases", name: "purchase_orders_purchase_id"

  add_foreign_key "purchases", "suppliers", name: "purchase_orders_supplier_id_fkey"

  add_foreign_key "shipping_rates", "customers", name: "shipping_rates_customer_id_fkey"
  add_foreign_key "shipping_rates", "products", name: "shipping_rates_product_id_fkey"

  add_foreign_key "suppliers", "addresses", name: "suppliers_address_id_fkey"
  add_foreign_key "suppliers", "price_sources", name: "suppliers_price_source_id_fkey"
  add_foreign_key "suppliers", "suppliers", name: "suppliers_parent_id_fkey", column: "parent_id"

  add_foreign_key "tags", "products", name: "tags_product_id_fkey"

  add_foreign_key "users", "orders", name: "users_current_order_id_fkey", column: "current_order_id"

  add_foreign_key "variants", "products", name: "variants_product_id_fkey"

  add_foreign_key "warehouses", "suppliers", name: "warehouses_supplier_id_fkey"

end
