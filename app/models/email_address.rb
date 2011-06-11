class EmailAddress < ActiveRecord::Base
  belongs_to :customer

  def valid_email?
    begin
      TMail::Address.parse(address.strip)
    rescue TMail::SyntaxError
      errors.add_to_base("Must be a valid email")
    end
  end
  validate :valid_email?
end
