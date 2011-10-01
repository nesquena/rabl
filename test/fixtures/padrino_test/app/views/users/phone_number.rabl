attributes :prefix, :suffix, :area_code
attributes :is_primary => :primary

node :formatted do |n|
  n.formatted
end