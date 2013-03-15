attributes :prefix, :suffix, :area_code
attributes :is_primary => :primary

if locals[:revert]
  node(:reverted) { |n| n.formatted.reverse }
else
  node(:formatted) { |n| n.formatted }
end