Done Reports
============

## API

### `POST /api/report/new`

* token - The auth token for the group
* username - The username sending the report
* type - past, future, blocking, hero, unknown
* message - The text of the report

The server knows the current open report where responses are being collected.

Post a new entry to the current open report. (TODO: This should be renamed to /api/entry/new)


### `POST /api/report/remove`

* token - The auth token for the group
* username - The username sending the report
* message - The text of the report

Remove an entry. Only entries from an open report can be removed. Entries are matched on the entry
text, not by ID, so you must pass in the exact text of the entry to remove.


### `POST /api/user/new`

Bold fields are required. All others are optional.

* **token** - The auth token for the group
* **username** - A unique username for the user. If a user exists with this username already, the record is updated
* **email** - The email address of the user.
* nicks - A comma-separated string of alternate IRC nicks this user may be using.
* github_username - The user's Github username
* github_email - The user's email address in commits on Github


### `POST /hook/github`

* ?github_token=xxxxx - The internal Github auth token for the group
* ... whatever Github sends

This endpoint handles Github's event hooks. Note this is different from the standard git post-commit hooks. A full list of events sent by Github can be [found here](http://developer.github.com/v3/activity/events/types/).


### `POST /api/github_hook/add`

* token - The auth token for the group
* repo_url - The HTTP URL of the Github repositry

Add the appropriate Github hook to the specified repository. Will fail if the repo is not a Github URL.


### `GET /api/group/config`

* token - The auth token for the group

Returns a JSON config block for the group to be put into the IRC bot config file.


## List of all API Methods

### Accounts

#### `GET /auth/assertion`

Allows the website to obtain a token for a user without going through Github auth

#### `GET /autocomplete/users`

Website access only. Allows the website to get a list of user accounts beginning with the input text.

#### `GET /autocomplete/user/:username`

Get user info given a username. Returns:

* username
* email
* nicks
* github_username
* github_email

#### `POST /accounts

Create a new user and corresponding organization.

### Groups

#### `GET /api/groups`

Get a list of all groups the authenticated user has access to across all orgs.

#### `GET /api/orgs/:org/groups`

Get a list of all groups on the given org.

#### `GET /api/orgs/:org/groups/:group`

Retrieve information about a group.

#### `POST /api/orgs/:org/groups/:group`

Update information about a group.

#### `POST /api/orgs/:org/groups`

Create a new group under the given organization.

#### `GET /api/orgs/:org/groups/:group/users`

Get a list of all users in a group.

#### `POST /api/orgs/:org/groups/:group/users`

Add an existing user to a group. If the user is not yet part of the organization, they are added at this time.

#### `POST /api/orgs/:org/groups/:group/users/remove`

Remove a user from a group.

### Orgs

#### `GET /api/orgs/:org/servers`

Get a list of servers for the org.

#### `POST /api/orgs/:org/servers`

Add a new IRC server to the org.

### Users

#### `GET /api/users`

Retrieve all users for all orgs the authenticating user is a member of, including the list of channels each user is in.

#### `GET /api/users/:username`

Get user account info.

#### `POST /api/users/:username`

Update user profile info. Org admins can update the profile info of users in their org.

TODO: Change this to only allow updating profile info of users who do not have their own login.

#### `POST /api/orgs/:org/users`

Create a new user, optionally adding them to a group at the same time.

### Reporting API

#### `POST /api/report/new`

Post a new report. Automatically associated with the current open report for the group.

#### `POST /api/report/remove`

Remove a report. Only entries from an open report can be removed.

#### `GET /api/group/config`

Returns a JSON config block for the group to be loaded into the IRC bot config.

#### `GET /api/bot/config`

Returns a JSON config block for the bot, loaded into the IRC bot config.




## License

Copyright 2013 Esri

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

A copy of the license is available in the repository's `LICENSE.txt` file.
