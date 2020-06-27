attributes :prefix, :suffix, :area_code
attributes :is_primary => :primary

if locals[:reversed]
  node(:reversed) { |n| n.formatted.reverse }
else
  node(:formatted) { |n| n.formatted }
end