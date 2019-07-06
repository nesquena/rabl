object @post
cache @post

attributes :title, :body

node :partial do |p|
  partial('posts/renderer_partial', object: p)
end