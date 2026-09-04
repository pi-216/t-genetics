# Org-scoped since finding #56 (2026-09-04): a chromosome without an org is
# invisible to every session and would resurrect the legacy org-less rows the
# migration rake task cleans up (bin/rake tgenetics:migrate_legacy_org_rows).
demo_org = Identity::Organization.find_or_create_by!(name: 'Demo Org')
chromosome = Chromosome.create(name: 'Tip Recommendations', organization: demo_org)

@allele_names = [:button1, :button2, :button3]
@allele_names.each do |name|
  chromosome.alleles.create(name:, inheritable: Alleles::Integer.create(minimum: 1, maximum: 50))
end
generation = chromosome.generations.create(iteration: 1)

def add_value(index, value)
  name = @allele_names[index]
  valuable = Values::Integer.new(data: value)
  Value.create(organism: @organism, allele: Allele.find_by(name:), valuable:)
end

@organism = Organism.create(id: 1, generation:, fitness: 9917)
[7, 14, 31].each_with_index { |value, index| add_value(index, value) }

@organism = Organism.create(id: 2, generation:, fitness: 16667)
[9, 14, 34].each_with_index { |value, index| add_value(index, value) }

@organism = Organism.create(id: 3, generation:, fitness: 3171)
[3, 21, 46].each_with_index { |value, index| add_value(index, value) }

@organism = Organism.create(id: 4, generation:, fitness: 11100)
[11, 28, 43].each_with_index { |value, index| add_value(index, value) }

@organism = Organism.create(id: 5, generation:, fitness: 1639)
[28, 46, 50].each_with_index { |value, index| add_value(index, value) }

@organism = Organism.create(id: 7, generation:, fitness: 8562)
[14, 44, 48].each_with_index { |value, index| add_value(index, value) }

@organism = Organism.create(id: 8, generation:, fitness: 3828)
[13, 21, 47].each_with_index { |value, index| add_value(index, value) }

@organism = Organism.create(id: 9, generation:, fitness: 9928)
[4, 25, 38].each_with_index { |value, index| add_value(index, value) }

@organism = Organism.create(id: 10, generation:, fitness: 9558)
[8, 24, 25].each_with_index { |value, index| add_value(index, value) }

@organism = Organism.create(id: 11, generation:, fitness: 4357)
[3, 4, 6].each_with_index { |value, index| add_value(index, value) }

@organism = Organism.create(id: 12, generation:, fitness: 5895)
[2, 41, 42].each_with_index { |value, index| add_value(index, value) }

@organism = Organism.create(id: 13, generation:, fitness: 7939)
[9, 12, 16].each_with_index { |value, index| add_value(index, value) }

@organism = Organism.create(id: 14, generation:, fitness: 6660)
[4, 11, 41].each_with_index { |value, index| add_value(index, value) }

@organism = Organism.create(id: 15, generation:, fitness: 5443)
[1, 24, 35].each_with_index { |value, index| add_value(index, value) }

@organism = Organism.create(id: 16, generation:)
[23, 29, 45].each_with_index { |value, index| add_value(index, value) }

@organism = Organism.create(id: 17, generation:)
[4, 23, 47].each_with_index { |value, index| add_value(index, value) }

@organism = Organism.create(id: 18, generation:)
[14, 26, 34].each_with_index { |value, index| add_value(index, value) }

@organism = Organism.create(id: 19, generation:)
[23, 39, 42].each_with_index { |value, index| add_value(index, value) }

@organism = Organism.create(id: 20, generation:)
[9, 11, 32].each_with_index { |value, index| add_value(index, value) }
