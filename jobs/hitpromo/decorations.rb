require '../generic_import'

apply_decorations('Hit Promotional Products', %w(None Embroidery\ @\ 5000 Embroidery\ @\ 7000)) do |hit|
  # Blank Bag Costs
  dec_grp = hit.decoration_price_groups.create(
    { :technique => DecorationTechnique.find_by_name("None") })
    dec_grp.entries.create({ :minimum => 0,
      :fixed_price_const => 0.0,
      :fixed_price_exp => 0.0,
      :fixed_price_marginal => Money.new(0),
      :fixed_price_fixed => Money.new(0),
      :fixed => PriceGroup.create_prices([
      { :fixed => Money.new(0),
        :marginal => Money.new(0),
        :minimum => 0 }]) })

  # Embroidery
  base_tech = DecorationTechnique.find_by_name("Embroidery")
  [5000, 7000].each do |brk|
    tech = base_tech.children.find_by_name("Embroidery @ #{brk}")
    tech = base_tech.children.create(:name => "Embroidery @ #{brk}", :unit_name => base_tech.unit_name,
                                     :unit_default => base_tech.unit_default) unless tech
    dec_grp = hit.decoration_price_groups.create(:technique => tech)
    # <= 5000
    dec_grp.entries.create({ :minimum => 1,
                             :fixed_price_marginal => Money.new(2.5),
                             :fixed_price_fixed => Money.new(100.00),
                             :fixed => PriceGroup.create_prices([
                                                                 { :fixed => Money.new(80.00),
                                                                   :marginal => Money.new(2.5),
                                                                   :minimum => 1 } ]) })
            
    # >= 5000
    dec_grp.entries.create({ :minimum => brk+1,
                             :fixed_price_marginal => Money.new(2.5),
                             :fixed_price_fixed => Money.new(100.00),
                             :fixed => PriceGroup.create_prices([{ :fixed => Money.new(80.00),
                                                                   :marginal => Money.new(2.5),
                                                                   :minimum => 1 } ]),
                             :fixed_divisor => 1000,
                             :fixed_offset => brk - 1000,
                             :marginal_divisor => 1000,
                             :marginal_offset => brk - 1000,
                             
                             :marginal_price_marginal => Money.new(0.35),
                             :marginal_price_fixed => Money.new(35.00),
                             :marginal => PriceGroup.create_prices([{ :fixed => Money.new(28.00),
                                                                      :marginal => Money.new(0.28),
                                                                      :minimum => 1 }]) })
  end
end
