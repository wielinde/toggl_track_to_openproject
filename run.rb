# Start this script with:
# $ bundle console

Bundler.require
require 'dotenv/load'

require 'json'

require 'active_support'
require 'active_support/core_ext'

op_host = ENV["OPENPROJECT_HOST"] || 'localhost:3000'
op_api_key = ENV["OPENPROJECT_API_KEY"]
toggl_token = ENV["TOGGL_TOKEN"]

if toggl_token.blank? || op_api_key.blank?
  abort("Aborted. Please setup your .env file. If there is not an .env file yet, please create one by copying .env.example and then adopting its values.")
end

op_http_schema = ENV["OPENPROJECT_HTTP_SCHEMA"] || 'http'
op_activity_id = ENV["OPENPROEJCT_DEFAULT_ACTIVITY_ID"] || 1

debug_on = ENV["DEBUG_ON"] == "true"

op_base_url = "#{op_http_schema}://apikey:#{op_api_key}@#{op_host}/api/v3/"

def time_entry_body(wp_id, activity_id, hours, spent_on, comment = '')
  body = {
    "_links": {
      "workPackage": {
        "href": ''
      },
      "activity": {
        "href": ''
      }
    }
  }
  body[:_links][:workPackage][:href] = "/api/v3/work_packages/#{wp_id}"
  body[:_links][:activity][:href] = "/api/v3/time_entries/activities/#{activity_id}"
  body[:hours] = "PT#{hours}H"
  body[:comment] = comment
  body[:spentOn] = spent_on

  body.to_json
end

def wp_id_from_description(description)
  match = description.strip.upcase.match(/^\[OP#(\d+)\]/i)
  match[1] if match
end

TogglV8::TOGGL_REPORTS_URL = 'https://api.track.toggl.com/reports/api/'

toggl_api    = TogglV8::API.new(toggl_token)
user         = toggl_api.me(all = true)
workspaces   = toggl_api.my_workspaces(user)
workspace_id = workspaces.first['id']

TOGGL_REPORTS_URL = 'https://toggl.com/reports/api/'

reports = TogglV8::ReportsV2.new(api_token: toggl_token)
reports.workspace_id = workspace_id

full_report = []
ask_for_more = true
page = 0
while ask_for_more
  page += 1
  report = reports.details('', since: ENV["PERIOD_FIRST_DAY"], until: ENV["PERIOD_LAST_DAY"], page: page)
  ask_for_more = false if report.size.zero?
  full_report += report
end

puts JSON.pretty_generate(full_report) if debug_on

time_total = 0
hours_total = 0
time_total_alt = 0
hours_total_alt = 0
by_description = full_report.group_by { |entry| entry['description'] }

by_description.keys.each do |key|
  wp_id = wp_id_from_description(key)
  unless wp_id
    puts "= Can't sync \"#{key}\": OpenProject work package ID missing. Please use the following syntax '[OP#<Work package ID>] <work package subject>'"
    next
  end

  duration = by_description[key].inject(0) { |sum, entry| sum + entry['dur'] }
  hours = (duration.to_f / 60.0 / 60.0 / 1000.0).round(2)
  time_total += duration
  hours_total += hours

  puts "===== #{hours}\t#{key} ======="
  by_date = by_description[key].group_by do |entry|
    Time.parse(entry['start']).strftime('%F')
  end
  by_date.keys.each do |date|
    duration_per_date = by_date[date].inject(0) { |sum, entry| sum + entry['dur'] }
    hours_per_date = (duration_per_date.to_f / 60.0 / 60.0 / 1000.0).round(2)
    puts "#{date}\t#{hours_per_date}"

    if wp_id.present? && op_activity_id.present? && hours_per_date.present? && hours_per_date > 0.0 && date.present?
      RestClient.post(op_base_url + 'time_entries', time_entry_body(wp_id, op_activity_id, hours_per_date, date, ''), {content_type: :json, accept: :json})
      sleep 2
    else
      puts "will not send POST request for #{key}"
    end

    time_total_alt += duration_per_date
    hours_total_alt += hours_per_date
  end
end

puts "#{(time_total.to_f / 60.0 / 60.0 / 1000.0).round(2)}"
puts "#{hours_total.round(2)}"
puts "#{(time_total_alt.to_f / 60.0 / 60.0 / 1000.0).round(2)}"
puts "#{hours_total_alt.round(2)}"

