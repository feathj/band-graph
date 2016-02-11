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
    crawl_music_pages(base_ref)
  end

  # Default route #####################################################
  get '/' do
  end

  # Crawler / Scraper #################################################
  def crawl_music_pages(base_ref)
    crawl_music_pages_helper(base_ref, 0, Set.new())
  end

  def crawl_music_pages_helper(ref, level, indexed)
    return if indexed.include?(ref)
    return unless ref.to_s != ''
    return unless level < MAX_RECURSION
    response = HTTParty.get(URI.join('https://en.wikipedia.org/wiki/', clean_ref(ref)))

    indexed.add(ref)

    page = Nokogiri::HTML(response.body)
    infobox = page.css("table.infobox")

    band_name = infobox.css("span.fn").text
    band_node = find_or_create_band_node(clean_ref(ref), band_name)
    return unless band_node

    puts band_name, ref

    members = infobox.css("tr th:contains('Members') ~ td a")
    members.each do |member|
     artist_node = find_or_create_artist_node(clean_ref(member['href']), member.text)
     find_or_create_relationship('member', artist_node, band_node) if artist_node
     #crawl_music_pages_helper(member['href'], level + 1, indexed)
    end

    associated_bands = infobox.css("tr th:contains('Associated acts') ~ td a")
    associated_bands.each do |associated_band|
      associated_band_node = find_or_create_band_node(clean_ref(associated_band['href']), associated_band.text)
      if associated_band_node
        find_or_create_relationship('associated', band_node, associated_band_node)
        crawl_music_pages_helper(associated_band['href'], level + 1, indexed)
      end
    end
  end

  def find_or_create_band_node(band_ref, band_name)
    return nil unless band_ref.to_s != '' && band_name.to_s != ''
    node = @neo.get_node_index('bands', 'ref', clean_ref(band_ref))[0] rescue nil
    unless node
      node = @neo.create_node('name' => band_name, 'ref' => clean_ref(band_ref))
      @neo.add_label(node, 'band')
      @neo.add_node_to_index('bands', 'ref', clean_ref(band_ref), node)
    end
    node
  end

  def find_or_create_artist_node(artist_ref, artist_name)
    return nil unless artist_ref.to_s != '' && artist_name.to_s != ''
    node = @neo.get_node_index('artists', 'ref', clean_ref(artist_ref))[0] rescue nil
    unless node
      node = @neo.create_node('name' => artist_name, 'ref' => clean_ref(artist_ref))
      @neo.add_label(node, 'artist')
      @neo.add_node_to_index('artists', 'ref', clean_ref(artist_ref), node)
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
