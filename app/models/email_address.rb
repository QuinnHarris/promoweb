class EmailAddress < ActiveRecord::Base
  belongs_to :customer

  def self.main_column; 'address'; end

  def valid_email?
    return nil unless address
    begin
      TMail::Address.parse(address.strip)
    rescue TMail::SyntaxError
      errors.add_to_base("Must be a valid email")
    end
  end
  validate :valid_email?
end
