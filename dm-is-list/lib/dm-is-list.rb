require 'pathname'
require 'dm-adjust'
require 'dm-aggregates'

require Pathname(__FILE__).dirname.expand_path / 'dm-is-list' / 'is' / 'list'

DataMapper::Model.append_extensions DataMapper::Is::List
