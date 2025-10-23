# frozen_string_literal: true

collection @users

extends "users/show", :locals => { :reversed => true }