require 'sinatra/base'
require 'rubygems'
require 'byebug'
require 'set'

require 'httparty'
require 'neography'
require 'nokogiri'

class WebApp < Sinatra::Base
  # Config ############################################################
  MAX_RECURSION = 5
  configure do
    set :bind, '0.0.0.0'
    set :server, 'thin'
  end

  # Setup all connections #############################################
  before do
    @neo = Neography::Rest.new(server: 'neo4j', port: 7474)
  end

  # Index data ########################################################
  get '/index' do
    base_ref = params['base_ref']
    max_recursion = (params['max_recursion'] || MAX_RECURSION).to_i
    crawl_music_pages(base_ref, max_recursion)
  end

  # Default route #####################################################
  get '/' do
  end

  # Crawler / Scraper #################################################
  def crawl_music_pages(base_ref, max_recursion)
    crawl_music_pages_helper(base_ref, 0, max_recursion, set.New())
  end

  def crawl_music_pages_helper(ref, level, max_recursion, indexed)
    return if indexed.include?(ref)
    return unless ref.to_s != ''
    return unless level < max_recursion
    begin
      response = HTTParty.get(URI.join('https://en.wikipedia.org/wiki/', clean_ref(ref)))
    rescue Exception
      return
    end

    indexed.add(ref)

    page = Nokogiri::HTML(response.body)
    infobox = page.css("table.infobox")

    band_name = infobox.css("span.fn").text
    band_node = find_or_create_node('band', clean_ref(ref), band_name)
    return unless band_node

    puts band_name

    members = infobox.css("tr th:contains('Members') ~ td a")
    members.each do |member|
      artist_node = find_or_create_node('artist', clean_ref(member['href']), member.text)
      find_or_create_relationship('member', artist_node, band_node) if artist_node
    end

    genres = infobox.css("tr th:contains('Genres') ~ td a")
    genres.each do |genre|
      next unless !genre['href'].start_with?('#')
      genre_node = find_or_create_node('genre', clean_ref(genre['href']), genre.text)
      find_or_create_relationship('genre', band_node, genre_node) if genre_node
    end

    associated_bands = infobox.css("tr th:contains('Associated acts') ~ td a")
    associated_bands.each do |associated_band|
      associated_band_node = find_or_create_node('band', clean_ref(associated_band['href']), associated_band.text)
      if associated_band_node
        find_or_create_relationship('associated', band_node, associated_band_node)
        crawl_music_pages_helper(associated_band['href'], level + 1, max_recursion, indexed)
      end
    end
  end

  def find_or_create_node(node_type, ref, name)
    return nil unless ref.to_s != '' && name.to_s != ''
    index_name = "#{node_type}s"
    node = @neo.get_node_index(index_name, 'ref', clean_ref(ref))[0] rescue nil
    unless node
      node = @neo.create_node('name' => name, 'ref' => clean_ref(ref))
      @neo.add_label(node, node_type)
      @neo.add_node_to_index(index_name, 'ref', clean_ref(ref), node)
    end
    node
  end

  def find_or_create_relationship(relationship, node1, node2)
    return nil unless relationship.to_s != '' && node1 && node2
    ref_key = "#{node1['data']['ref']}_#{node2['data']['ref']}"
    @neo.create_unique_relationship('relationships', 'ref', ref_key, relationship, node1, node2)
  end

  def clean_ref(ref)
    ref.gsub('/wiki/', '')
  end
end

WebApp.run!
