sph_ga = require "./foreign/sph_ga.js" unless window?
class scene_class
  constructor: (options) ->
    @set_options options
  set_options: (options) ->
    @dimensions = options.dimensions
    @rotation_dimensions = @normalize_rotation_dimensions options.rotation_dimensions
    @rotation_speed = options.rotation_speed
    @projection_depth = options.projection_depth
    @display_scale = options.display_scale
    @surface_alpha = options.surface_alpha
    @metric = @make_metric()
    @cga = new sph_ga @metric, conformal: true
    @rotation_planes = @get_rotation_planes()
    @basis_ids = @build_basis_ids()
    @base_points = @build_base_points()
    @edge_indices = @build_edge_indices()
    @square_groups = @build_square_groups()
    @owner_colors = @build_owner_colors()
    @solid_colors = @build_solid_colors()
    @vertex_count = @base_points.length
    @square_count = @square_groups.square_count
    @projected_positions = new Float32Array @vertex_count * 3
    @solid_positions = new Float32Array @square_count * 18
    @coord_buffer = new Float64Array @dimensions
  make_metric: ->
    Array(@dimensions).fill 1
  get_rotation_planes: ->
    planes = []
    for axis_a in [1..@dimensions]
      for axis_b in [1..@dimensions]
        continue unless axis_a < axis_b
        planes.push [axis_a, axis_b]
    planes
  normalize_rotation_dimensions: (rotation_dimensions) ->
    plane_count = @dimensions * (@dimensions - 1) / 2
    result = rotation_dimensions.slice 0, plane_count
    result.push 1 while result.length < plane_count
    result
  build_basis_ids: ->
    basis_ids = new Array @dimensions + 1
    for dimension in [1..@dimensions]
      basis_ids[dimension] = @cga.id_from_indices [dimension]
    basis_ids
  bits_to_coords: (bits) ->
    [0...@dimensions].map (dimension_index) ->
      if bits & (1 << dimension_index) then 1 else -1
  build_base_points: ->
    vertex_count = 1 << @dimensions
    base_points = new Array vertex_count
    for vertex_index in [0...vertex_count]
      coords = @bits_to_coords vertex_index
      base_points[vertex_index] = @cga.point coords
    base_points
  build_edge_indices: ->
    vertex_count = 1 << @dimensions
    edge_count = @dimensions * (1 << (@dimensions - 1))
    indices = new Uint16Array edge_count * 2
    write_index = 0
    for vertex in [0...vertex_count]
      for dimension_index in [0...@dimensions]
        continue if vertex & (1 << dimension_index)
        indices[write_index] = vertex
        indices[write_index + 1] = vertex | (1 << dimension_index)
        write_index = write_index + 2
    indices
  build_square_groups: ->
    owner_count = @dimensions * 2
    if @dimensions < 2
      return
        square_count: 0
        square_vertices: new Uint16Array 0
        square_owners: new Uint16Array 0
        owner_count: owner_count
    square_count_per_owner =
      if 2 < @dimensions
        (@dimensions - 1) * (@dimensions - 2) * (1 << (@dimensions - 3)) / 2
      else
        1
    square_count = owner_count * square_count_per_owner
    square_vertices = new Uint16Array square_count * 4
    square_owners = new Uint16Array square_count
    all_dimensions = [0...@dimensions]
    square_index = 0
    for fixed_dimension in all_dimensions
      varying_dimensions = all_dimensions.filter (dimension) -> dimension isnt fixed_dimension
      for fixed_value in [0, 1]
        owner_id = fixed_dimension * 2 + fixed_value
        if @dimensions is 2
          base_vertex = 0
          base_vertex |= 1 << fixed_dimension if fixed_value
          other_dimension = varying_dimensions[0]
          write_base = square_index * 4
          square_vertices[write_base] = base_vertex
          square_vertices[write_base + 1] = base_vertex | (1 << other_dimension)
          square_vertices[write_base + 2] = base_vertex | (1 << other_dimension)
          square_vertices[write_base + 3] = base_vertex
          square_owners[square_index] = owner_id
          square_index = square_index + 1
          continue
        for first_index in [0...varying_dimensions.length]
          dimension_a = varying_dimensions[first_index]
          for second_index in [first_index + 1...varying_dimensions.length]
            dimension_b = varying_dimensions[second_index]
            remaining_dimensions = varying_dimensions.filter (dimension) ->
              dimension isnt dimension_a and dimension isnt dimension_b
            assignment_count = 1 << remaining_dimensions.length
            for assignment in [0...assignment_count]
              base_vertex = 0
              base_vertex |= 1 << fixed_dimension if fixed_value
              for remaining_index in [0...remaining_dimensions.length]
                dimension = remaining_dimensions[remaining_index]
                base_vertex |= 1 << dimension if assignment & (1 << remaining_index)
              write_base = square_index * 4
              square_vertices[write_base] = base_vertex
              square_vertices[write_base + 1] = base_vertex | (1 << dimension_a)
              square_vertices[write_base + 2] = base_vertex | (1 << dimension_a) | (1 << dimension_b)
              square_vertices[write_base + 3] = base_vertex | (1 << dimension_b)
              square_owners[square_index] = owner_id
              square_index = square_index + 1
    square_count: square_index
    square_vertices: square_vertices
    square_owners: square_owners
    owner_count: owner_count
  hsv_to_rgb: (hue, saturation, value) ->
    sector = Math.floor hue * 6
    fraction = hue * 6 - sector
    p = value * (1 - saturation)
    q = value * (1 - fraction * saturation)
    t = value * (1 - (1 - fraction) * saturation)
    switch sector % 6
      when 0 then [value, t, p]
      when 1 then [q, value, p]
      when 2 then [p, value, t]
      when 3 then [p, q, value]
      when 4 then [t, p, value]
      else [value, p, q]
  build_owner_colors: ->
    owner_count = @square_groups.owner_count
    [0...owner_count].map (owner_index) =>
      hue = owner_index / Math.max owner_count, 1
      [red, green, blue] = @hsv_to_rgb hue, 0.85, 0.75
      [red, green, blue, @surface_alpha]
  build_solid_colors: ->
    square_owners = @square_groups.square_owners
    solid_colors = new Float32Array square_owners.length * 24
    for owner_id, square_index in square_owners
      color = @owner_colors[owner_id]
      write_base = square_index * 24
      for vertex_index in [0...6]
        vertex_base = write_base + vertex_index * 4
        solid_colors[vertex_base] = color[0]
        solid_colors[vertex_base + 1] = color[1]
        solid_colors[vertex_base + 2] = color[2]
        solid_colors[vertex_base + 3] = color[3]
    solid_colors
  build_rotor_total: (time_seconds) ->
    rotor_total = @cga.s 1
    for enabled, plane_index in @rotation_dimensions
      continue unless enabled
      [axis_a, axis_b] = @rotation_planes[plane_index]
      half_angle = time_seconds * @rotation_speed * 0.5
      rotor_component = @cga.add(
        @cga.s(Math.cos half_angle),
        @cga.mv([[[axis_a, axis_b], -Math.sin half_angle]])
      )
      rotor_total = @cga.gp rotor_total, rotor_component
    rotor_total
  extract_coords: (point_mv) ->
    for dimension in [1..@dimensions]
      blade = @cga.get point_mv, @basis_ids[dimension]
      @coord_buffer[dimension - 1] = if blade then @cga.blade_coeff blade else 0
  project_coords_to_3d: ->
    for current_dimension in [@dimensions..4] by -1
      scale = @projection_depth / (@projection_depth - @coord_buffer[current_dimension - 1])
      for coord_index in [0...current_dimension - 1]
        @coord_buffer[coord_index] = @coord_buffer[coord_index] * scale
    x = if 0 < @dimensions then @coord_buffer[0] * @display_scale else 0
    y = if 1 < @dimensions then @coord_buffer[1] * @display_scale else 0
    z = if 2 < @dimensions then @coord_buffer[2] * @display_scale else 0
    [x, y, z]
  update_projected_positions: (time_seconds) ->
    rotor_total = @build_rotor_total time_seconds
    for point_mv, vertex_index in @base_points
      rotated_point = @cga.sp rotor_total, point_mv
      @extract_coords rotated_point
      [x, y, z] = @project_coords_to_3d()
      write_base = vertex_index * 3
      @projected_positions[write_base] = x
      @projected_positions[write_base + 1] = y
      @projected_positions[write_base + 2] = z
  write_triangle_3d: (target, write_base, ax, ay, az, bx, by_, bz, cx, cy, cz) ->
    target[write_base] = ax
    target[write_base + 1] = ay
    target[write_base + 2] = az
    target[write_base + 3] = bx
    target[write_base + 4] = by_
    target[write_base + 5] = bz
    target[write_base + 6] = cx
    target[write_base + 7] = cy
    target[write_base + 8] = cz
  update_solid_positions: ->
    source = @projected_positions
    target = @solid_positions
    square_vertices = @square_groups.square_vertices
    for square_index in [0...@square_count]
      source_base = square_index * 4
      target_base = square_index * 18
      vertex_a = square_vertices[source_base] * 3
      vertex_b = square_vertices[source_base + 1] * 3
      vertex_c = square_vertices[source_base + 2] * 3
      vertex_d = square_vertices[source_base + 3] * 3
      ax = source[vertex_a]
      ay = source[vertex_a + 1]
      az = source[vertex_a + 2]
      bx = source[vertex_b]
      by_ = source[vertex_b + 1]
      bz = source[vertex_b + 2]
      cx = source[vertex_c]
      cy = source[vertex_c + 1]
      cz = source[vertex_c + 2]
      dx = source[vertex_d]
      dy = source[vertex_d + 1]
      dz = source[vertex_d + 2]
      @write_triangle_3d target, target_base, ax, ay, az, bx, by_, bz, cx, cy, cz
      @write_triangle_3d target, target_base + 9, ax, ay, az, cx, cy, cz, dx, dy, dz
  update_frame_data: (time_seconds) ->
    @update_projected_positions time_seconds
    @update_solid_positions()
webgl =
  wire_vertex_shader_source: """
  #version 300 es
  precision highp float;
  in vec3 position;
  void main() {
    gl_Position = vec4(position, 1.0);
  }
  """
  wire_fragment_shader_source: """
  #version 300 es
  precision highp float;
  out vec4 fragment_color;
  void main() {
    fragment_color = vec4(0.08, 0.08, 0.08, 1.0);
  }
  """
  solid_vertex_shader_source: """
  #version 300 es
  precision highp float;
  in vec3 position;
  in vec4 color;
  out vec4 vertex_color;
  void main() {
    gl_Position = vec4(position, 1.0);
    vertex_color = color;
  }
  """
  solid_fragment_shader_source: """
  #version 300 es
  precision highp float;
  in vec4 vertex_color;
  out vec4 fragment_color;
  void main() {
    fragment_color = vertex_color;
  }
  """
  create_shader: (gl, type_name, source) ->
    shader = gl.createShader gl[type_name]
    gl.shaderSource shader, source
    gl.compileShader shader
    unless gl.getShaderParameter shader, gl.COMPILE_STATUS
      console.error gl.getShaderInfoLog shader
      gl.deleteShader shader
      return 0
    shader
  create_program: (gl, vertex_source, fragment_source) ->
    vertex_shader = @create_shader gl, "VERTEX_SHADER", vertex_source
    fragment_shader = @create_shader gl, "FRAGMENT_SHADER", fragment_source
    return 0 unless vertex_shader and fragment_shader
    program = gl.createProgram()
    gl.attachShader program, vertex_shader
    gl.attachShader program, fragment_shader
    gl.linkProgram program
    unless gl.getProgramParameter program, gl.LINK_STATUS
      console.error gl.getProgramInfoLog program
      gl.deleteProgram program
      return 0
    program
  resize_canvas: (canvas) ->
    ratio = window.devicePixelRatio or 1
    width = Math.floor canvas.clientWidth * ratio
    height = Math.floor canvas.clientHeight * ratio
    if canvas.width isnt width or canvas.height isnt height
      canvas.width = width
      canvas.height = height
window.scene_class = scene_class if window?
window.webgl = webgl if window?
