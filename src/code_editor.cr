require "./code_buffer"
require "./code_cursor"

# Current state of text widget: Far from done.
#
# - [ ] Fix pango metrics crash on gi-crystal
# - [ ] Implement `gtk_widget_class_add_binding_signal` on gtk4 shard
# - [ ] Add a bunch of overloads to Gtk::Snapshot to avoid keep creating graphene points on stack
# - [ ] Draw grid
# - [x] Draw cursors
# - [ ] Make cursors blink
# - [ ] Hide mouse when typing
# - [ ] Move cursors
# - [ ] Add feature to implement interface properties on gi-crystal
# - [ ] Implement Scrollable interface
# - [ ] Study tree-sitter
# - [ ] Highlight code with tree sitter
# - [ ] Handle text input
# - [ ] Replace dummy text buffer by a piece table
class CodeEditor < Gtk::Widget
  private MARGIN        = 4.0_f32
  private DOUBLE_MARGIN = 8.0_f32

  @pango_ctx : Pango::Context
  getter buffer : CodeBuffer

  # Colors
  @bg_color : Gdk::RGBA
  @text_color : Gdk::RGBA
  @grid_color : Gdk::RGBA

  @font_height : Float32
  @font_width : Float32

  @cursors : CodeCursors
  @line_offset = 0

  # Widget width/height
  @width = 0.0_f32
  @height = 0.0_f32

  def initialize(resource : String? = nil)
    super(focusable: true)
    @buffer = CodeBuffer.new(resource)

    @pango_ctx = pango_context
    @pango_ctx.font_description = Pango::FontDescription.from_string("JetBrainsMono Nerd Font 9")

    # Colors
    @bg_color = Gdk::RGBA.new(0.14, 0.14, 0.14, 1.0)
    @text_color = Gdk::RGBA.new(1.0, 1.0, 1.0, 1.0)
    @grid_color = Gdk::RGBA.new(0.14, 0.14, 0.14, 1.0)

    # FIXME: Pango::FontMetrics is crashing with a double free!
    # metric = @pango_ctx.metrics(nil, nil)
    # @font_height = (metric.height / Pango::SCALE).to_f32
    # @font_width = (metric.approximate_char_width / Pango::SCALE).to_f32
    @font_height = 14.639648
    @font_width = 7.2001953

    @cursors = CodeCursors.new(@buffer)

    im_context = Gtk::IMMulticontext.new
    im_context.commit_signal.connect(&->commit_text(String))
    key_controller = Gtk::EventControllerKey.new(propagation_phase: :target)
    key_controller.im_context = im_context
    add_controller(key_controller)
    key_controller.key_pressed_signal.connect(&->key_pressed(UInt32, UInt32, Gdk::ModifierType))
  end

  private def commit_text(text : String)
    Log.info { "commit text: #{text}" }
  end

  private def key_pressed(keyval : UInt32, keycode : UInt32, state : Gdk::ModifierType) : Bool
    Log.info { "key pressed!" }
    return false unless state.none?

    case keyval
    when Gdk::KEY_Up, Gdk::KEY_KP_Up       then @cursors.move(:display_lines, -1)
    when Gdk::KEY_Down, Gdk::KEY_KP_Down   then @cursors.move(:display_lines, 1)
    when Gdk::KEY_Right, Gdk::KEY_KP_Right then @cursors.move(:visual_positions, 1)
    when Gdk::KEY_Left, Gdk::KEY_KP_Left   then @cursors.move(:visual_positions, -1)
    else
      return false
    end

    queue_draw
    true
  end

  @[GObject::Virtual]
  def snapshot(snapshot : Gtk::Snapshot)
    orig = Graphene::Point.new(0.0, 0.0)
    size = Graphene::Size.new(@width, @height)
    rect = Graphene::Rect.new(orig, size)

    Log.notice { "snapshot!" }

    snapshot.append_color(@bg_color, rect)

    draw_gutter(snapshot)
    draw_line_numbers(snapshot)
    draw_grid(snapshot)
    draw_text(snapshot)
  end

  @[GObject::Virtual]
  def size_allocate(width : Int32, height : Int32, baseline : Int32)
    Log.notice { "size_allocate! #{width}, #{height}, #{baseline}" }
    @width = width.to_f32
    @height = height.to_f32
  end

  private def digits_count(n : Int32) : Int32
    (Math.log(n.to_f + 1) / Math::LOG10).ceil.to_i
  end

  private def draw_grid(snapshot : Gtk::Snapshot)
  end

  private def draw_line_numbers(snapshot : Gtk::Snapshot)
    layout = Pango::Layout.new(@pango_ctx)

    snapshot.translate(Graphene::Point.new(MARGIN, 0.0))
    trans = Graphene::Point.new(0.0, @font_height)

    height_trans = 0.0_f32
    @line_offset.upto(@buffer.line_count - 1) do |i|
      i += 1
      layout.set_text(i.to_s, i.to_s.bytesize) # Maybe is worth to cache the strings with line numbers?
      snapshot.append_layout(layout, @text_color)
      snapshot.translate(trans)
      height_trans += @font_height
      break if height_trans > @height
    end
    snapshot.translate(Graphene::Point.new(-MARGIN, -height_trans))
  end

  private def draw_gutter(snapshot : Gtk::Snapshot)
  end

  private def draw_text(snapshot : Gtk::Snapshot)
    digits = digits_count(@buffer.line_count)
    trans = Graphene::Point.new(digits * @font_width + DOUBLE_MARGIN, 0.0)
    snapshot.translate(trans)

    trans = Graphene::Point.new(0.0, @font_height)
    layout = Pango::Layout.new(@pango_ctx)

    height_trans = 0.0_f32
    @buffer.each_line(offset: @line_offset) do |text, line|
      layout.set_text(text)
      snapshot.append_layout(layout, @text_color)

      @cursors.at_line(line) do |cursor|
        snapshot.render_insertion_cursor(style_context, 0.0, 0.0, layout, cursor.column, :ltr)
      end

      snapshot.translate(trans)
      height_trans += @font_height
      break if height_trans > @height
    end
  end
end
