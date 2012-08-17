# gcit2ghi.rb

This is a simple script to convert from Google Code Issue Tracker to GitHub Issues.

## Usage

`ruby gcit2ghi.rb(project,user,repo,password,*org,*max-results)`

Parentheses and commas are highly recommended to avoid confusion between the last two optional arguments.
**project** - Google Code project  
**user** - GitHub user name  
**repo** - GitHub repository name  
**password** - GitHub user password  
**org** - (optional) Organization's username on GitHub for non-personal repos  
**max-results** - (optional) Maximum tickets and maximum comments to fetch (defaults is 500)

###Usage Examples
`ruby gcit2ghi.rb(beef,joe,my-beef,super-secret)` - fetches first 500 tickets and first 500 comments per ticket from Google Code project [Beef](http://code.google.com/p/beef/) and appends them to GitHub repo joe/my-beef using the password `super-secret`.

`ruby gcit2ghi.rb(beef,joe,my-beef,super-secret,,25)` - fetches first 25 tickets and first 25 comments per ticket from Google Code project [Beef](http://code.google.com/p/beef/) and appends them to GitHub repo joe/my-beef using the password `super-secret`.

`ruby gcit2ghi.rb(beef,joe,our-beef,super-secret,my-org)` - fetches first 500 tickets and first 500 comments per ticket from Google Code project [Beef](http://code.google.com/p/beef/) and appends them to GitHub repo my-org/our-beef on behalf of user `joe` using the password `super-secret`.

## Requirements

 1. `ruby` - Programming language ([find installer for your OS](http://www.ruby-lang.org/en/downloads/))
 2. `rubygems` - Gem management package for Ruby ([installation instructions](http://rubygems.org/pages/download))
 3. `nokogiri` - For parsing the Google Code XML files (open console/terminal/command prompt and execute `gem install nokogiri`)
 4. `json` - For serializing the GitHub API calls (open console/terminal/command prompt and execute `gem install json`)
 5. `rest-client` - For submitting the GitHub API calls (open console/terminal/command prompt and execute `gem install rest-client`)

## How It Works

 1. Downloads the Issue Tracker feed from Google Code (caching it locally in the created xml subdirectory). Parses out all issues.
 2. For each issue, downloads the Issue Comments feed from Google Code (caching it locally) and parses out all comments for the issue as long as they aren't empty (e.g., Google Code marks label changes as comments).
 3. Does some preprocessing of the parsed out entries to add to the body of issues and comments adding the valuable reference information:
   - link to the original Google Code issue and its ID number there
   - anonymized author of the issue & each comment on Google Code (email domain is truncated because GitHub automatically converts them into `mailto:` links)
   - the creation and the closure date of the issue
 4. Uploads each issue to GitHub, potentially marks the issue as closed if it was closed on Google Code, and uploads each comment related to the issue.

## Caveats

There is very little error handling done. There are only basic comments in the source code (whatever I, dnbrv, added or was able to understand in the original code).

Files uploaded to Google Code (aka attachments) are not copied. This is a limitation of accessing tickets through feeds.

Labels and milestones are not copied, only the title and body of issues and the body of comments. Tickets are imported without assignee.

If you have a problem with the script after a partial import, you can open the script and uncomment out the lines that delete existing issues.  You shouldn't do this if you want to keep any existing issues, though.

This was used to convert the ruby-sequel Google Code issues to [jeremyevans/sequel](https://github.com/jeremyevans/sequel) on GitHub. Jeremy has  stopped development since then so [Denis Baranov](http://www.dnbrv.com) made some improvements to transition [7plus](https://github.com/7plus/7plus).

## License

This code is licensed under the MIT license.  See the MIT-LICENSE file for details.

## Authors

Jeremy Evans <code@jeremyevans.net> - original author  
Denis Baranov <dev@dnbrv.com> - author of this fork