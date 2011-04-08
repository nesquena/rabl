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



## Issues ##

 * I am sloppy and once again failed to unit test this. Don't use it in production until I do obviously.

