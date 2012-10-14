README
==========

What's this
---------------
**Nippo Create 2** is daily report generator.
The report data is loaded from Google Calendar via its API.

Installation
---------------

    TODO: insert the git clone command here

Setting
----------

Edit *main.yaml* and rewrite some options.

    production:
      oauth_client_id    : 'REWRITE HERE'
      oauth_client_secret: 'REWRITE HERE'
      oauth_redirect_url : 'REWRITE HERE'

**NOTE**: There is the same settings at the "development" key. Each key (production or development) are switched by the application "mode".

Used Technology
----------------

* Google Calendar API
* OAuth authentization
* Mojolicious::Lite

License
--------
MIT License

Author
-------
Yusuke Ueno (uechoco)
