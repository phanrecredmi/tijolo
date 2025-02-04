class ProjectMonitor
  @monitors = Hash(String, Gio::FileMonitor).new
  @project : Project

  Log = ::Log.for("ProjectMonitor")

  def initialize(@project)
  end

  def project_load_finished
    @project.each_directory do |dir|
      create_monitor(dir.to_s)
    end
    Log.info { "Monitoring #{@monitors.size} directories for changes." }
  end

  private def create_monitor(dir : String)
    return if @monitors.has_key?(dir)

    @monitors[dir] = monitor = Gio::File.new_for_path(dir).monitor_directory(:none, nil)
    Log.debug { "Monitoring #{dir} for changes." }
    monitor.changed_signal.connect(&->dir_changed(Gio::File, Gio::File?, Gio::FileMonitorEvent))
  end

  private def destroy_monitor(dir : String)
    @monitors[dir]?.try(&.cancel)
    @monitors.delete(dir)
  end

  private def dir_changed(file : Gio::File, other_file : Gio::File?, event : Gio::FileMonitorEvent)
    file_path = Path.new(file.parse_name)
    other_path = Path.new(other_file.parse_name) if other_file

    Log.debug { "Got event! #{event}" }
    case event
    when .created?
      @project.add_path(file_path)
    when .deleted?
      @project.remove_path(file_path)
    when .renamed?
      @project.rename_path(file_path, other_path) if other_path
    end
  end
end
