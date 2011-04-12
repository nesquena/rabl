# RABL #

RABL is a ruby templating system for Rails that takes a different approach for generating JSON and other formats. Rather than using the ActiveRecord 'to_json', I generally find myself wanting to use a more expressive and flexible system for generating my Public APIs. This is especially true when I the json doesn't match to the exact schema defined in the database.

There were a few things in particular I wanted to do easily:

 * Create arbitrary nodes named based on combining data in the object
 * Include nodes only if a condition is met
 * Pass arguments to methods and store the result as a node
 * Include partial templates to reduce code duplication
 * Easily rename attributes from their name in the model

This general templating system solves all of those problems.

## Installation ##

    gem install rabl

## Usage ##

Basic usage of the templater:

    # app/views/users/show.json.rabl
    attributes :id, :foo, :bar

This will generate a json response with the attributes specified. You can also include arbitrary code:

    # app/views/users/show.json.rabl
    code :full_name do |u|
      u.first_name + " " + u.last_name
    end

You can also add children nodes:

    child @posts => :foobar do
      attributes :id, :title
    end

or use existing model associations:

    child :posts => :foobar do
      attributes :id, :title
    end

or get access to the hash representation of another object:

    code :location do
      { :place => partial("web/users/address", :object => @address) }
    end

You can also append attributes to the root node:

    glue @post do
      attribute :id => :post_id
    end

There is also the ability to extend other rabl templates with additional attributes:

    extends "base"

    code :release_year do |m|
      date = m.release_date || m.series_start
      date.try(:year)
    end

You can also extend other rabl templates to reduce duplication:

    # app/views/users/show.json.rabl
    child @address do
      extends "address/item"
    end

Use extend and liberally to cleanup your representations and keep them uniform.

## Issues ##

 * I am sloppy and once again failed to unit test this. Don't use it in production until I do obviously.