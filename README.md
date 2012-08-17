# gcit2ghi.rb

This is a simple script to convert from Google Code Issue Tracker to GitHub Issues.

## Usage

`ruby gcit2ghi.rb project,user,repo,password,org`

**project** - Google Code project  
**user** - GitHub user name  
**password** - GitHub user password  
**owner** - Repository's owner's username on GitHub (ensures compatibility with personal and organization-owned repos)  
**repo** - Repository name  
~~**max-results** - (optional) Maximum tickets and maximum comments to fetch (defaults is 500)~~ (disabled for debugging)

###Usage Examples
`ruby gcit2ghi.rb beef joe super-secret joe my-beef` - fetches 500 oldest tickets and 500 oldest comments per ticket from Google Code project [Beef](http://code.google.com/p/beef/) and appends them to GitHub repo `joe/my-beef` using the password `super-secret`.

`ruby gcit2ghi.rb beef joe super-secret joes-org our-beef` - fetches 500 oldest tickets and 500 oldest comments per ticket from Google Code project [Beef](http://code.google.com/p/beef/) and appends them to GitHub repo `joes-org/our-beef` on behalf of user `joe` using the password `super-secret`.

~~`ruby gcit2ghi.rb beef joe super-secret joe my-beef 25` - fetches 25 oldest tickets and 25 oldest comments per ticket from Google Code project [Beef](http://code.google.com/p/beef/) and appends them to GitHub repo `joe/my-beef` using the password `super-secret`.~~

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

If you want to import more/fewer than 500 tickets or comments per ticket you need to edit the script manually. Global constant `MAX_RESULTS` [on line 14](https://github.com/dnbrv/gcit2ghi/blob/master/gcit2ghi.rb#L14) is responsible for that.

There is very little error handling done. There are only basic comments in the source code (whatever I, dnbrv, added or was able to understand in the original code).

Files uploaded to Google Code (aka attachments) are not copied. This is a limitation of Google Code Issue Tracker API.

Labels and milestones are not copied, only the title and body of issues and the body of comments.

Tickets are imported without assignee by default. If you want to assign them to someone automatically, see [line 81 of the script](https://github.com/dnbrv/gcit2ghi/blob/master/gcit2ghi.rb#L81) for instructions.

There's no way to delete existing tickets from GitHub either manually or via API. If you botch-up a migration, you'll have to delete and re-create the repo on GitHub. **DO NOT ATTEMPT THIS** if you don't know what you're doing. Tip: make sure your local copy of the repo is up-to-date and secured before deleting the remote one.

This was used to convert the ruby-sequel Google Code issues to [jeremyevans/sequel](https://github.com/jeremyevans/sequel) on GitHub. Jeremy has  stopped development since then so [Denis Baranov](http://www.dnbrv.com) made some improvements to transition [7plus](https://github.com/7plus/7plus).

## License

This code is licensed under the MIT license.  See the <a href="https://github.com/dnbrv/gcit2ghi/blob/master/MIT-LICENSE.md">MIT-LICENSE.md</a> file for details.

## Authors

Jeremy Evans <code@jeremyevans.net> - original author  
Denis Baranov <dev@dnbrv.com> - author of this fork

## Whishlist

 - A relatively simple way to migrate labels and milestones (it can't be very simple because of Google Code treats everything as labels and GitHub throws an error when a label doesn't exist, which requires either a label creation sub-routine or renaming labels prior to import).
 - Allowing users set the number of tickets to import in console not file.
 - Checking for existing tickets in GitHub and prompting users to overwrite them (i.e., fix a prematurely-stopped migration).