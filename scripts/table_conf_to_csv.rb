require 'csv'

data = Decidim::User.columns.map { |c| { 
  name: c.name, 
  type: c.sql_type, 
  required: !c.null,
  default: c.default.inspect  # .inspect para mostrar bien nil o valores
}}

CSV.open("scripts/tmp/campos_tabla_usuario.csv", "wb") do |csv|
  csv << ["name", "type", "required", "default"]
  data.each do |row|
    csv << [row[:name], row[:type], row[:required], row[:default]]
  end
end

puts "CSV creado!"