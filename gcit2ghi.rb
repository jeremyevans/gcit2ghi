#!/usr/bin/env ruby

require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'cgi'
require 'json'
require 'rest_client'

Dir.mkdir("xml") unless File.directory?("xml")
$stdout.sync = true

class GCIT2GHI
  MAX_RESULTS = 500
  attr_reader :project, :user, :repo, :password, :entries, :resource, :org

  def initialize(project, user, repo, password, *org)
    raise "No project name" unless project && !project.empty?
    @project, @user, @repo, @password, @org = project, user, repo, password, org
  end

  def gcit_issues_url
    "https://code.google.com/feeds/issues/p/#{project}/issues/full?max-results=#{MAX_RESULTS}"
  end

  def gcit_comments_url(issue_id)
    "https://code.google.com/feeds/issues/p/#{project}/issues/#{issue_id}/comments/full?max-results=#{MAX_RESULTS}"
  end

  def ghi_issues_url
	@org ? "https://api.github.com/repos/#{org}/#{repo}/issues" : "https://api.github.com/repos/#{user}/#{repo}/issues"
  end

  def namespaces
    @namespaces ||= Hash[*issues_doc.namespaces.to_a.map{|k, v| [k.gsub(/\Axmlns(:)?/){$1 ? '' : 'atom'}, v]}.flatten]
  end

  def q(doc, query)
    doc.xpath(query, namespaces)
  end
  
  def t(doc, query)
    q(doc, query).inner_text
  end

  def uh(doc, query)
    CGI.unescapeHTML(t(doc, query))
  end

  def issues_doc
    return @issues_doc if @issues_doc
    filename = "xml/#{project}.issues.xml"
    unless File.exist?(filename)
      File.open(filename, 'wb'){|f| f.write(open(gcit_issues_url).read)}
    end
    @issues_doc = Nokogiri::XML(File.new(filename))
  end

  def comments_doc(issue_id)
    filename = "xml/#{project}.issue-#{issue_id}.xml"
    unless File.exist?(filename)
      File.open(filename, 'wb'){|f| f.write(open(gcit_comments_url(issue_id)).read)}
    end
    Nokogiri::XML(File.new(filename))
  end

  def convert
    entries = q(issues_doc, '/atom:feed/atom:entry')
    print "Parsing issues XML file..."
    @entries = entries.map do |e|
      {
        :id=>t(e, 'issues:id'),
        :author=>t(e, 'atom:author/atom:name'),
        :published=>t(e, 'atom:published'),
        :closed=>t(e, 'issues:closedDate'),
        :state=>t(e, 'issues:state'),
        :json => {
          "title"=>t(e, 'atom:title'),
          "body"=>uh(e, 'atom:content'),
        }
      }
    end
    puts "done (#{entries.length} issues)"

    print "Getting comments for each issue: "
    @entries.each do |e|
      cdoc = q(comments_doc(e[:id]), '/atom:feed/atom:entry')
      e[:num_comments] = t(cdoc, "//openSearch:totalResults")
      e[:comments] = cdoc.map do |c|
        {
          :author=>t(c, 'atom:author/atom:name'),
          :published=>t(c, 'atom:published'),
          :json => {
            'body'=>uh(c, 'atom:content')
          }
        }
      end
      print "."
    end
    puts 'done'

    print "Preprocessing issues and comments: "
    @entries.each do |e|
      e[:json]['body'] << "\n\nGoogle Code Info:\nIssue #: #{e[:id]}\nAuthor: #{e[:author]}\nCreated On: #{e[:published]}\nClosed On: #{e[:closed]}"
      e[:comments].each do |c|
        c[:json]['body'] << "\n\nGoogle Code Info:\nAuthor: #{c[:author]}\nCreated On: #{c[:published]}"
      end
    end
    puts 'done'

    r = @resource = RestClient::Resource.new(ghi_issues_url, :user=>user, :password=>password)
    begin
=begin
    print "Deleting existing open issues: "
    while !(existing = JSON.parse(r.get.body)).empty?
      existing.map{|j| j['number']}.each do |i|
        r[i.to_s].delete
        print '.'
      end
    end
    puts 'done'
    print "Deleting existing closed issues: "
    cr = RestClient::Resource.new("#{ghi_issues_url}?state=closed", :user=>user, :password=>password)
    while !(existing = JSON.parse(cr.get.body)).empty?
      existing.map{|j| j['number']}.each do |i|
        r[i.to_s].delete
        print '.'
      end
    end
    puts 'done'
=end
    print "Uploading issues (|), closing issues (/), and uploading comments (.): "
    @entries.each do |e|
      res = r.post(e[:json].to_json, :content_type=>:json, :accept=>:json)
      number = JSON.parse(res.body)['number'].to_s
      print "|"
      if e[:state] == 'closed'
        r[number].post({'state'=>'closed'}.to_json, :content_type=>:json, :accept=>:json)
        print "/"
      end
      e[:comments].each do |c|
        r["#{number}/comments"].post(c[:json].to_json, :content_type=>:json, :accept=>:json)
        print "."
      end
    end
    puts 'done'
    rescue RestClient::Exception => ex
      puts "Error!!"
      puts ex
      puts ex.response
      puts ex.backtrace
      exit(1)
    end
  end
end

GCIT2GHI.new(*ARGV).convert if __FILE__ == $0
