# Extends base.json.rabl and adds additional nodes

extends("base")

code :release_year do |m|
  m.release_date.year
end

code :poster_image_url do |m|
  m.poster_image_url(:large)
end