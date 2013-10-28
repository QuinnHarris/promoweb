class Spam < ActionMailer::Base
  default from: "Quinn Harris <quinn@mountainofpromos.com>"

  def spam_message(customer)
    @customer = customer

    mail(:subject => "How can we serve you better?") do |format|
      format.text
    end
  end
end
