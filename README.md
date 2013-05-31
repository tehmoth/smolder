Smolder - continuous integration smoke server
=============================================

Smolder is a web-based continuous integration smoke server. It's a central
repository for you smoke tests for multiple public and private repositories.

Please see [Smolder::Manual](https://metacpan.org/module/Smolder::Manual)
for how to use it.

![recent smoke reports](http://i.imgur.com/Hb2cD.png)

Features
--------
* Self contained web application
  Smolder has its own built-in HTTP server (Net::Server) and database (SQLite).
* Standard Format
  Smolder uses [TAP](http://en.wikipedia.org/wiki/Test_Anything_Protocol)
  and TAP Archives as its reporting format.
  See [Smolder::Manual](https://metacpan.org/module/Smolder::Manual) for
  more details.
* Multiple Notification Channels
  Smolder can notifiy you of new or failing tests either by email or Atom
  data feeds.
* Public and Private Projects
  Use Smolder for your public open source projects, or for you private work
  related projects. Smolder can host multiple projects of each type.
* Project Graphs
  Smolder has graphs to help you visualize the changes to your test suite
  over time. See how the number of tests has grown or find patterns in
  your failing tests.
* Smoke Report Organization
  You can organize your smoke reports by platform, architecture or any tag
  you want. This makes it easy to see how your project is doing on multiple
  platforms, or with different configurations.

![administration interface](http://i.imgur.com/ASTGB.png)

Install
-------
From the CPAN, using the traditional CPAN shell:

    $ cpan Smolder

or using [cpanminus](https://metacpan.org/module/App::cpanminus):

    $ cpanm --sudo --skip-satisfied Smolder

From the sources:

    $ git clone https://github.com/Smolder/smolder.git
    $ perl Build.PL
    $ ./Build test
    $ sudo ./Build install

Usage
-----
A good practice is to create a dedicated `smolder` user account.

Then create a directory where to store your smoker data, and create
a configuration file:

    HostName    smoker.example.com
    Port        21234
    FromAddress smolder@example.com
    DataDir     /home/smolder/main
    PidFile     /home/smolder/main/smolder.pid
    LogFile     /home/smolder/main/smolder.log

Run the daemon:

    $ smolder --daemon --conf /home/smolder/main/smolder.conf

Now you can submit reports by executing your tests using the `--archive`
option of the `prove` utility:

    $ prove --archive test_run.tar.gz

and send them using the provided `smolder_smoke_signal` utility:

    $ smolder_smoke_signal --server smoker.example.com --port 21234 \
        --username smokebot --password s33kret \
        --project MyProject --file test_run.tar.gz

Again, see [Smolder::Manual](https://metacpan.org/module/Smolder::Manual)
for more details.

