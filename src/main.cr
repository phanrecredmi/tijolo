require "libadwaita"
require "log"

require "./tijolo_application"

{% raise "This branch isn't ready yet, try the latest tag (v0.7.1) instead." unless flag?(:i_know_what_im_doing) %}
{% raise "Tijolo requires GTK >= 4.8, found: #{Gtk::MAJOR_VERSION}.#{Gtk::MINOR_VERSION}" if Gtk::MINOR_VERSION < 8 %}

Gio.register_resource("data/resources.xml", source_dir: "data")
app = TijoloApplication.new
exit(app.run)

require "./monkey_patches"
