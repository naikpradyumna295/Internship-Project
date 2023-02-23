#!/usr/bin/env ruby

require 'optparse'
require_relative '../secret'
require_relative 'cache_utils/caching_openbd'
require_relative 'cache_utils/remove_unsupport_format'
require_relative 'cache_utils/completion_of_cover_image'

unless File.writable? CACHE_DIR
	puts "No write permission: #{CACHE_DIR}"
	exit
end

opt = OptParse.new
opt.on('-u', '--update [OPTION]', 'caching openBD.') {|option| CacheUtil.caching_openbd CACHE_DIR, option}
opt.on('-r', '--remove', 'remove unsupport format.') {CacheUtil.remove_unsupport_format CACHE_DIR}
opt.on('-c', '--complete', 'completion of cover image.') {CacheUtil.completion_of_cover_image CACHE_DIR}
opt.parse ARGV
