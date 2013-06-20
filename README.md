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
