# Load Rails
require File.dirname(__FILE__) + '/../../config/environment'
require 'fileutils'

class FileCache
  def initialize(name)
    @root_dir = File.join("/home/quinn/promoweb-data", name)
  end

  def file_path(parsed_url)
    base = "#{@root_dir}/#{parsed_url.host}:#{parsed_url.port}/#{parsed_url.request_uri}"
#    base = "#{base}/index.html" if parsed_url.path[-1..-1] == '/'
    path, file = File.split(base)
    "#{path}/!#{file}".gsub(/\/+/,'/')
  end
  
  def exists?(parsed_url)
    File.exists?(file_path(parsed_url))
  end
  
  def delete(parsed_url)
    FileUtils.rm_f(file_path(parsed_url))
  end
  
  def mkdir(fp)
    path, file = File.split(fp)
    FileUtils.mkdir_p(path) unless File.exists?(path)
  end
  
  def move(from_url, to_url)
    from_fp = file_path(from_url)
    to_fp = file_path(to_url)
    return if from_fp == to_fp
    mkdir(to_fp)
    FileUtils.mv(from_fp, to_fp)
  end
  
  def get(parsed_url)
    fp = file_path(parsed_url)
    if File.exists?(fp)
      return File.open(fp) { |f| Marshal.load(f) }
    end
    return nil
  end
  
  def cache(parsed_url)
    fp = file_path(parsed_url)
#    if File.exists?(fp)
#      return File.open(fp) { |f| Marshal.load(f) }
#    end
    
    res = yield parsed_url
    
    mkdir(fp)
    File.open(fp, "w") { |f| Marshal.dump(res, f) }
    res
  end
end
