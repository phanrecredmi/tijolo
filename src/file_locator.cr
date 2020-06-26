require "./locator_provider"
require "./project"

class FileLocator < LocatorProvider
  include ProjectListener

  # Number of file locator matches to show in the UI
  MAX_LOCATOR_ITEMS = 25

  getter model

  @last_results = [] of Fzy::Match
  @project_haystack : Fzy::PreparedHaystack

  def initialize(@project : Project)
    super()
    @project_haystack = if @project.load_finished?
                          Fzy::PreparedHaystack.new(@project.files.map(&.to_s))
                        else
                          Fzy::PreparedHaystack.new([] of String)
                        end
    @project.add_project_listener(self)
  end

  def project_file_added(_path : Path)
    project_load_finished # Lazy way... just reload all the things
  end

  def project_file_removed(_path : Path)
    project_load_finished # Lazy way... just reload all the things
  end

  def project_folder_renamed(_old_path : Path, _new_path : Path)
    project_load_finished # Lazy way... just reload all the things
  end

  def project_load_finished
    @project_haystack = Fzy::PreparedHaystack.new(@project.files.map(&.to_s))
  end

  def shortcut : Char
    'f' # not used, this is the default locator provider.
  end

  def results_size : Int32
    @last_results.size
  end

  def activate(locator, index : Int32)
    return if index >= @last_results.size

    file = @last_results[index].value
    locator.notify_locator_open_file(@project.root.join(file).to_s)
  end

  def search_changed(search_text : String) : Nil
    return if @project_haystack.haystack.empty?

    start_time = Time.monotonic
    @model.clear

    @last_results = Fzy.search(search_text, @project_haystack)
    @last_results.delete_at(MAX_LOCATOR_ITEMS..-1) if @last_results.size > MAX_LOCATOR_ITEMS

    iter = Gtk::TreeIter.new
    @last_results.each do |match|
      @model.append(iter)
      @model.set(iter, {LABEL_COLUMN}, {markup(match)})
    end

    end_time = Time.monotonic
    total = end_time - start_time
    Log.debug { "Locator found #{@last_results.size} in #{total}" }
  end

  def markup(match)
    value = match.value
    str_size = value.bytesize + match.positions.size * 7 # 7 is the size of the extra markup
    pos_iter = match.positions.each
    next_pos = pos_iter.next
    String.build(str_size) do |str|
      value.each_char_with_index do |char, i|
        if i == next_pos
          str << "<b>#{char}</b>"
          next_pos = pos_iter.next
        else
          str << char
        end
      end
    end
  end
end
