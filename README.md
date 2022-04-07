# toggl_track_to_openproject

A configurable script for uploading your TogglTrack time entries to OpenProject.

## What it does

This script aggregates all Toggl Track time entries having the same title per date and creates a time entry on OpenProject. It does so by relying on having the work package ID in the title of Toggl Track time entries.

## Usage

Use the Toggl Track browser extension and activate it for your OpenProject instance. With it you can start tracking time on OpenProject work packages. The browser extension ensures that the time entries on the Toggl Track server will contain the work package ID in its title. These IDs are necessary for this script here to identify the work packages to which you want to upload the time entries.

### Configure the script via a .env file before running

Once you have Toggl Track time entries with OpenProject work package IDs in its title you can use this script here. Just copy the `.env.example` file to `.env` and adopt it to your needs. Put your access tokens for Toggle Track and OpenProject. Specify the host name of your OpenProject instance. Then specify the date range for which you want to upload the time entries.

### Running the script

From within the root folder of this repository run

`bundle exec ruby run.rb`

## Contribution

Please feel free to improve this repository. I am happy about any pull request.
