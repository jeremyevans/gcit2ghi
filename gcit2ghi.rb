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

  def ghi_issues_url # Generate the URL to push tickets into GitHub issues
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

  def issues_doc # Create one file listing all tickets
    return @issues_doc if @issues_doc
    filename = "xml/#{project}.issues.xml"
    unless File.exist?(filename)
      File.open(filename, 'wb'){|f| f.write(open(gcit_issues_url).read)}
    end
    @issues_doc = Nokogiri::XML(File.new(filename))
  end

  def comments_doc(issue_id) # Create one file per ticket with all comments in it
    filename = "xml/#{project}.issue-#{issue_id}.xml" # Set file name format to project.issue-ID.xml
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
        unless uh(c, 'atom:content').size == 0 # Allow  only comments with content.
            {
              :author=>t(c, 'atom:author/atom:name'),
              :published=>t(c, 'atom:published'),
              :json => {
                'body'=>uh(c, 'atom:content')
              }
            }
        end
      end
      print "."
    end
    puts 'done'

    print "Preprocessing issues and comments: "
    @entries.each do |e|
      author = e[:author].sub(/@\S*/,"") # Anonymize author's email. Google Code links it to profile but GitHub makes a mailto: link
      e[:json]['body'] << "\n\nImported from Google Code [Issue #{e[:id]}](http://code.google.com/p/#{project}/issues/detail?id=#{e[:id]})\nPosted by #{author} on: #{e[:published]}\nClosed On: #{e[:closed]}" # Append meta information and link to the original ticket in Google Code for reference and attachments that can't be transferred
      e[:comments].each do |c|
        unless c === nil # Allow  only comments with content.
          author = c[:author].sub(/@\S*/,"") # Anonymize author's email. Google Code links it to profile but GitHub makes a mailto: link
          c[:json]['body'] << "\n\nImported from Google Code\nPosted by #{author} on: #{c[:published]}"
        end
      end
    end
    puts 'done'

    r = @resource = RestClient::Resource.new(ghi_issues_url, :user=>user, :password=>password)
    begin

    print "Uploading issues (|), closing issues (/), and uploading comments (.): "
    @entries.each do |e|
      res = r.post(e[:json].to_json, :content_type=>:json, :accept=>:json)
      number = JSON.parse(res.body)['number'].to_s
      print "|"
      if e[:state] == 'closed'
        r[number].post({'state'=>'closed'}.to_json, :content_type=>:json, :accept=>:json)
        print "/"
      end
      unless e[:comments] == 0
          e[:comments].each do |c|
            unless c === nil # This is being checked just in case because it can't be verified without posting some tickets to GitHub
                r["#{number}/comments"].post(c[:json].to_json, :content_type=>:json, :accept=>:json)
                print "."
            end
          end
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
