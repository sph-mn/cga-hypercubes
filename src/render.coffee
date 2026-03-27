class renderer_class
  constructor: (canvas, options) ->
    @canvas = canvas
    @gl = @canvas.getContext "webgl2"
    unless @gl
      alert "unable to initialize webgl2."
      return
    @wire_program = webgl.create_program @gl, webgl.wire_vertex_shader_source, webgl.wire_fragment_shader_source
    @solid_program = webgl.create_program @gl, webgl.solid_vertex_shader_source, webgl.solid_fragment_shader_source
    @wire_vao = @gl.createVertexArray()
    @solid_vao = @gl.createVertexArray()
    @wire_position_buffer = @gl.createBuffer()
    @wire_index_buffer = @gl.createBuffer()
    @solid_position_buffer = @gl.createBuffer()
    @solid_color_buffer = @gl.createBuffer()
    unless @wire_program and @solid_program and @wire_vao and @solid_vao and @wire_position_buffer and @wire_index_buffer and @solid_position_buffer and @solid_color_buffer
      alert "unable to initialize required webgl resources."
      return
    @gl.clearColor 1, 1, 1, 1
    @gl.enable @gl.DEPTH_TEST
    @gl.depthFunc @gl.LEQUAL
    @gl.enable @gl.BLEND
    @gl.blendFunc @gl.SRC_ALPHA, @gl.ONE_MINUS_SRC_ALPHA
    @configure_wire_pipeline()
    @configure_solid_pipeline()
    @scene = 0
    @options = 0
    @phase_time = 0
    @previous_frame_time = -1e18
    @frame_id = 0
    @set_options options
    @on_frame = (time) =>
      if @options.refresh <= time - @previous_frame_time
        @previous_frame_time = time
        @draw time
      @frame_id = requestAnimationFrame @on_frame
    @frame_id = requestAnimationFrame @on_frame
  configure_wire_pipeline: ->
    gl = @gl
    gl.bindVertexArray @wire_vao
    gl.bindBuffer gl.ARRAY_BUFFER, @wire_position_buffer
    position_location = gl.getAttribLocation @wire_program, "position"
    gl.enableVertexAttribArray position_location
    gl.vertexAttribPointer position_location, 3, gl.FLOAT, false, 0, 0
    gl.bindBuffer gl.ELEMENT_ARRAY_BUFFER, @wire_index_buffer
    gl.bindVertexArray null
  configure_solid_pipeline: ->
    gl = @gl
    gl.bindVertexArray @solid_vao
    gl.bindBuffer gl.ARRAY_BUFFER, @solid_position_buffer
    position_location = gl.getAttribLocation @solid_program, "position"
    gl.enableVertexAttribArray position_location
    gl.vertexAttribPointer position_location, 3, gl.FLOAT, false, 0, 0
    gl.bindBuffer gl.ARRAY_BUFFER, @solid_color_buffer
    color_location = gl.getAttribLocation @solid_program, "color"
    if 0 <= color_location
      gl.enableVertexAttribArray color_location
      gl.vertexAttribPointer color_location, 4, gl.FLOAT, false, 0, 0
    gl.bindVertexArray null
  set_options: (options) ->
    @options =
      dimensions: options.dimensions
      rotation_dimensions: options.rotation_dimensions.slice()
      refresh: options.refresh
      rotation_speed: options.rotation_speed
      projection_depth: options.projection_depth
      display_scale: options.display_scale
      surface_alpha: options.surface_alpha
      area_epsilon: options.area_epsilon
      surfaces_enabled: options.surfaces_enabled
      wireframe_enabled: options.wireframe_enabled
    @scene = new scene_class @options
    @upload_static_data()
    @phase_time = performance.now()
    @previous_frame_time = -1e18
    @draw @phase_time
  upload_static_data: ->
    gl = @gl
    gl.bindBuffer gl.ELEMENT_ARRAY_BUFFER, @wire_index_buffer
    gl.bufferData gl.ELEMENT_ARRAY_BUFFER, @scene.edge_indices, gl.STATIC_DRAW
    gl.bindBuffer gl.ARRAY_BUFFER, @wire_position_buffer
    gl.bufferData gl.ARRAY_BUFFER, @scene.projected_positions.byteLength, gl.DYNAMIC_DRAW
    gl.bindBuffer gl.ARRAY_BUFFER, @solid_position_buffer
    gl.bufferData gl.ARRAY_BUFFER, @scene.solid_positions.byteLength, gl.DYNAMIC_DRAW
    gl.bindBuffer gl.ARRAY_BUFFER, @solid_color_buffer
    gl.bufferData gl.ARRAY_BUFFER, @scene.solid_colors, gl.STATIC_DRAW
  draw: (time) ->
    gl = @gl
    webgl.resize_canvas @canvas
    gl.viewport 0, 0, @canvas.width, @canvas.height
    @scene.update_frame_data (time - @phase_time) / 1000
    gl.clear gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT
    if @options.surfaces_enabled and @scene.solid_positions.length
      gl.useProgram @solid_program
      gl.bindVertexArray @solid_vao
      gl.bindBuffer gl.ARRAY_BUFFER, @solid_position_buffer
      gl.bufferSubData gl.ARRAY_BUFFER, 0, @scene.solid_positions
      gl.drawArrays gl.TRIANGLES, 0, @scene.solid_positions.length / 3
    if @options.wireframe_enabled
      gl.useProgram @wire_program
      gl.bindVertexArray @wire_vao
      gl.bindBuffer gl.ARRAY_BUFFER, @wire_position_buffer
      gl.bufferSubData gl.ARRAY_BUFFER, 0, @scene.projected_positions
      gl.drawElements gl.LINES, @scene.edge_indices.length, gl.UNSIGNED_SHORT, 0
    gl.bindVertexArray null
  stop: ->
    cancelAnimationFrame @frame_id if @frame_id
    @frame_id = 0
class ui_class
  constructor: (draw) ->
    @canvas = document.getElementsByTagName("canvas")[0]
    @warning_shown = false
    @dom = {}
    @options = @get_default_options()
    @renderer = new renderer_class @canvas, @options
    @build_controls()
    @sync_rotation_plane_controls()
    @bind_events()
    @commit()
  get_default_options: ->
    dimensions = 4
    dimensions: dimensions
    rotation_dimensions: @get_default_rotation_dimensions dimensions
    refresh: 16
    rotation_speed: Math.PI * 0.08
    projection_depth: 10
    display_scale: 0.4
    surface_alpha: 0.65
    area_epsilon: 1e-7
    surfaces_enabled: true
    wireframe_enabled: true
  get_default_rotation_dimensions: (dimensions) ->
    Array(dimensions * (dimensions - 1) / 2).fill 1
  normalize_rotation_dimensions: (dimensions, rotation_dimensions) ->
    plane_count = dimensions * (dimensions - 1) / 2
    result = rotation_dimensions.slice 0, plane_count
    result.push 1 while result.length < plane_count
    result
  get_rotation_planes: (dimensions) ->
    planes = []
    for axis_a in [1..dimensions]
      for axis_b in [1..dimensions]
        continue unless axis_a < axis_b
        planes.push [axis_a, axis_b]
    planes
  label: (text, content) ->
    crel "label", text, content
  read_number: (input, fallback) ->
    value = parseFloat input.value
    if isNaN value then fallback else value
  build_controls: ->
    @dom.dimensions = crel "input",
      type: "number"
      min: "1"
      max: "7"
      value: @options.dimensions
    @dom.rotation_speed = crel "input",
      type: "number"
      min: "0"
      step: "0.01"
      value: @options.rotation_speed / Math.PI
    @dom.refresh = crel "input",
      type: "number"
      min: "1"
      value: @options.refresh
    @dom.projection_depth = crel "input",
      type: "number"
      min: "1"
      step: "1"
      value: @options.projection_depth
    @dom.display_scale = crel "input",
      type: "number"
      min: "0.01"
      step: "0.01"
      value: @options.display_scale
    @dom.surface_alpha = crel "input",
      type: "number"
      min: "0"
      max: "1"
      step: "0.01"
      value: @options.surface_alpha
    @dom.surfaces_enabled = crel "input", type: "checkbox"
    @dom.surfaces_enabled.checked = @options.surfaces_enabled
    @dom.wireframe_enabled = crel "input", type: "checkbox"
    @dom.wireframe_enabled.checked = @options.wireframe_enabled
    @dom.rotation_planes = crel "div"
    @dom.controls_root = crel "div"
    root = @dom.controls_root
    root.appendChild @label "dimensions", @dom.dimensions
    root.appendChild crel "div", "rotation_planes", @dom.rotation_planes
    root.appendChild @label "speed_pi_per_second", @dom.rotation_speed
    root.appendChild @label "refresh_ms", @dom.refresh
    root.appendChild @label "projection_depth", @dom.projection_depth
    root.appendChild @label "display_scale", @dom.display_scale
    root.appendChild @label "surface_alpha", @dom.surface_alpha
    root.appendChild @label "surfaces", @dom.surfaces_enabled
    root.appendChild @label "wireframe", @dom.wireframe_enabled
    document.getElementById("controls").appendChild root
  bind_events: ->
    @dom.dimensions.addEventListener "change", @on_dimensions_change
    @dom.rotation_speed.addEventListener "change", @commit
    @dom.refresh.addEventListener "change", @commit
    @dom.projection_depth.addEventListener "change", @commit
    @dom.display_scale.addEventListener "change", @commit
    @dom.surface_alpha.addEventListener "change", @commit
    @dom.surfaces_enabled.addEventListener "change", @commit
    @dom.wireframe_enabled.addEventListener "change", @commit
  on_dimensions_change: =>
    dimensions = Math.floor @read_number @dom.dimensions, @options.dimensions
    dimensions = Math.max 1, dimensions
    if 7 < dimensions
      alert "the current maximum number of dimensions is 7."
      dimensions = 7
    if not @warning_shown and 6 <= dimensions
      alert "increasing dimensions can easily overload the browser."
      @warning_shown = true
    @options.dimensions = dimensions
    @options.rotation_dimensions = @normalize_rotation_dimensions dimensions, @options.rotation_dimensions
    @dom.dimensions.value = dimensions
    @sync_rotation_plane_controls()
    @commit()
  sync_rotation_plane_controls: ->
    rotation_planes = @get_rotation_planes @options.dimensions
    @dom.rotation_planes.innerHTML = ""
    @dom.rotation_dimension_inputs = []
    for plane, plane_index in rotation_planes
      [axis_a, axis_b] = plane
      checkbox = crel "input", type: "checkbox"
      checkbox.checked = !!@options.rotation_dimensions[plane_index]
      checkbox.addEventListener "change", @commit
      wrapper = crel "label", "plane_#{axis_a}_#{axis_b}", checkbox
      @dom.rotation_planes.appendChild wrapper
      @dom.rotation_dimension_inputs.push checkbox
  commit: =>
    @options.dimensions = Math.floor @read_number @dom.dimensions, @options.dimensions
    @options.rotation_dimensions = @dom.rotation_dimension_inputs.map (checkbox) ->
      if checkbox.checked then 1 else 0
    @options.rotation_dimensions = @normalize_rotation_dimensions @options.dimensions, @options.rotation_dimensions
    @options.rotation_speed = Math.PI * @read_number @dom.rotation_speed, @options.rotation_speed / Math.PI
    @options.refresh = Math.max 1, Math.floor(@read_number @dom.refresh, @options.refresh)
    @options.projection_depth = Math.max 1, @read_number @dom.projection_depth, @options.projection_depth
    @options.display_scale = Math.max 0.01, @read_number @dom.display_scale, @options.display_scale
    @options.surface_alpha = Math.min 1, Math.max 0, @read_number(@dom.surface_alpha, @options.surface_alpha)
    @options.surfaces_enabled = @dom.surfaces_enabled.checked
    @options.wireframe_enabled = @dom.wireframe_enabled.checked
    @renderer.set_options @options
render_rotating_cube = (options) ->
  new renderer_class options.canvas, options
window.renderer_class = renderer_class if window?
window.ui_class = ui_class if window?
window.render_rotating_cube = render_rotating_cube if window?
