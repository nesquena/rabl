# Syntax

## Steps

 - [ ] Change documentation 
 - [ ] Update tests to reflect new syntax changes
 - [ ] Add new tests for special cases (collection with nodes outside)
 - [ ] Fix code to match

## Summary

Temporary file for storing the syntax changes:

## Change object syntax into a block

```ruby
object @post do |p|
  attributes :id, :name, :body, :created_at
end
```

```ruby
object :article => @post do |p|
  attributes :id, :name, :body, :created_at
end
```

## Change collection syntax into a block

```ruby
collection :articles => @posts do |p|
  attributes :id, :name, :body, :created_at

  node :is_read do |p|
    p.read_by? @user
  end

  child :author do |p|
    attributes :name, :username, :email
  end
end
```

## Change caching syntax

Change caching syntax to reflect changes:

```ruby
object @post do
   cache @post 
   # or cache true
   attributes :foo, :bar
end
```

## Handle collections with extra nodes

```ruby
collection :articles => @posts do |p|
  # ...
end

node :total_pages do
   @posts.total_pages
end

node :current_page do
  @posts.current_page
end
```

as well as if the collection has no root node with:

```
{ collection: [....], total_pages: xx }
```

## Reverse hash syntax from

```ruby
collection @posts => :articles
```

to

```ruby
collection :articles => @posts
```

## Improved handling of collection and object commands

If the developer says 'object' then assume object, if they say collection then assume collection. 
We no longer will detect this ourselves. 