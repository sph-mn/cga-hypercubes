// Generated by CoffeeScript 2.7.0
var any, array_map_depth, array_sum, array_swap, bits_to_array, fragment_shader_defaults, fragment_shader_solid_source, fragment_shader_wireframe_source, get_bit_combinations, get_cells, get_cube, get_projector, get_rotator, gl_create_program, gl_create_shader, gl_initialize, group_n_cells, node_run, render_rotating_cube, sort_by_predicate, sort_edges_cyclically, sort_vertices, sph_ga, triangulate_squares, vertex_shader_source,
  indexOf = [].indexOf;

if (typeof window === "undefined" || window === null) {
  sph_ga = require("./foreign/sph_ga.js"); // allow it to be run in the browser and node.js
}

array_sum = function(a) {
  return a.reduce((function(a, b) {
    return a + b;
  }), 0);
};

bits_to_array = function(a, n) {
  return (function() {
    var results = [];
    for (var l = 0; 0 <= n ? l < n : l > n; 0 <= n ? l++ : l--){ results.push(l); }
    return results;
  }).apply(this).map(function(b, i) {
    if (0 === (a >> i & 1)) {
      return -1;
    } else {
      return 1;
    }
  });
};

any = function(a, f) {
  var b, c, l, len;
// array {any -> any} -> any
// like Array.some but returns the truthy result
  for (l = 0, len = a.length; l < len; l++) {
    b = a[l];
    c = f(b);
    if (c) {
      return c;
    }
  }
  return false;
};

array_swap = function(a, i, j) {
  var b;
  // array integer integer -> unspecified
  b = a[i];
  a[i] = a[j];
  return a[j] = b;
};

array_map_depth = function(a, depth, f) {
  return a.map(function(a) {
    if (depth) {
      return array_map_depth(a, depth - 1, f);
    } else {
      return f(a);
    }
  });
};

sort_by_predicate = function(a, predicate) {
  var adjacent, b, i, l, len, match_result, next_index, previous, sorted;
  // array {any any -> 0/1/2} -> array
  // 0: no-match, 1: acceptable, 2: optimal
  sorted = [a[0]];
  a = a.slice(1);
  while (a.length > 0) {
    previous = sorted[sorted.length - 1];
    next_index = 0;
    adjacent = null;
    for (i = l = 0, len = a.length; l < len; i = ++l) {
      b = a[i];
      match_result = predicate(previous, b);
      if (match_result) {
        next_index = i;
        if (2 === match_result) {
          break;
        }
      }
    }
    sorted.push(a[next_index]);
    a.splice(next_index, 1);
  }
  return sorted;
};

get_bit_combinations = function(n, k) {
  var a, b, c, result;
  // generate all k-combinations of a set of size n as binary bitvectors.
  // algorithm: gospers hack
  result = [];
  a = (1 << k) - 1;
  while (a < (1 << n)) {
    result.push(a);
    b = a & -a;
    c = a + b;
    a = (((c ^ a) >> 2) / b) | c;
  }
  return result;
};

sort_edges_cyclically = function(cells) {
  var i, is_adjacent, l, link, ref;
  // sort edge vertices to form a continuous line
  is_adjacent = function(a, b) {
    return a.some(function(a) {
      return indexOf.call(b, a) >= 0;
    });
  };
  cells = sort_by_predicate(cells, is_adjacent);
  link = cells[0].find(function(a) {
    return indexOf.call(cells[1], a) >= 0;
  });
  if (link !== cells[0][1]) {
    array_swap(cells[0], 0, 1);
  }
  for (i = l = 1, ref = cells.length; (1 <= ref ? l < ref : l > ref); i = 1 <= ref ? ++l : --l) {
    if (cells[i - 1][1] !== cells[i][0]) {
      array_swap(cells[i], 1, 0);
    }
  }
  return cells;
};

group_n_cells = function(vertices, indices, n, k, cell_length) {
  var cell_indices, cell_vertices, fixed, fixed_combinations, i, key, l, len, len1, m, new_cell_indices;
  fixed_combinations = get_bit_combinations(n, k);
  cell_indices = [];
  for (l = 0, len = fixed_combinations.length; l < len; l++) {
    fixed = fixed_combinations[l];
    cell_vertices = {};
    for (m = 0, len1 = indices.length; m < len1; m++) {
      i = indices[m];
      key = fixed & vertices[i];
      if (cell_vertices[key]) {
        cell_vertices[key].push(i);
      } else {
        cell_vertices[key] = [i];
      }
    }
    new_cell_indices = Object.values(cell_vertices).filter(function(a) {
      return cell_length === a.length;
    });
    cell_indices = cell_indices.concat(new_cell_indices);
  }
  return cell_indices;
};

get_cells = function(vertices, n) {
  var ref, subcells;
  // integer -> array
  // get indices of edges grouped by nested cells.
  subcells = function(indices, k) {
    var a, l, len, results;
    if (!(k < n)) {
      return indices;
    }
    indices = group_n_cells(vertices, indices, n, k, 2 ** (n - k));
    if (k === n - 1) {
      indices = sort_edges_cyclically(indices);
    }
    results = [];
    for (l = 0, len = indices.length; l < len; l++) {
      a = indices[l];
      results.push(subcells(a, k + 1));
    }
    return results;
  };
  return subcells((function() {
    var results = [];
    for (var l = 0, ref = vertices.length; 0 <= ref ? l < ref : l > ref; 0 <= ref ? l++ : l--){ results.push(l); }
    return results;
  }).apply(this), 1);
};

get_projector = function(space, projection_distance, projection_angle) {
  var coeff, cos_half, perspective, projection, rotation, sin_half;
  // perspective projection.
  cos_half = Math.cos(projection_angle / 2);
  sin_half = Math.sin(projection_angle / 2);
  rotation = space.rotor([cos_half, sin_half, space.normal, space.no(1)]);
  coeff = 1 / (2 * projection_distance);
  perspective = space.rotor([1, coeff, space.normal, space.ni(1)]);
  projection = space.gp(rotation, perspective);
  return function(point) {
    return space.sp(projection, point);
  };
};

get_rotator = function(space, n, rotation_dimensions, rotation_speed) {
  var a, bivector_magnitude, i, rotor_data, rotors;
  // object integer integer rational -> {multivector:vertex -> multivector:vertex}
  // rotation
  // R = cos(angle / 2) + B * sin(angle / 2)
  bivector_magnitude = Math.sin(rotation_speed / 2);
  rotor_data = Array(n + 1);
  rotor_data[0] = Math.cos(rotation_speed / 2);
  rotors = (function() {
    var l, len, results;
    results = [];
    for (i = l = 0, len = rotation_dimensions.length; l < len; i = ++l) {
      a = rotation_dimensions[i];
      if (!a) {
        continue;
      }
      rotor_data = rotor_data.fill(0, 1);
      rotor_data[i + 1] = bivector_magnitude;
      results.push(space.rotor(rotor_data));
    }
    return results;
  })();
  return function(a) {
    return rotators.reduce((function(a, r) {
      return a.sp(r);
    }), a);
  };
};

triangulate_squares = function(indices, n) {
  return array_map_depth(indices, n - 3, function(a) {
    return [[a[0][0], a[0][1], a[2][1]], [a[1][0], a[1][1], a[2][1]]];
  });
};

sort_vertices = function(space, n, vertices, cells) {
  var n0, ni, ps;
  // sort edges counter clockwise.
  // assumes that edges are already sorted cyclically.
  n0 = space.no(1);
  ni = space.ni(1);
  ps = space.pseudoscalar();
  return array_map_depth(cells, n - 2, function(a) {
    var blade_scalar, orientation, p1, p2, p3, scalar;
    [p1, p2, p3] = a.map(function(a) {
      return vertices[a];
    });
    scalar = space.ip(space.ep(p1, p2, p3, n0, ni), ps);
    blade_scalar = space.get(scalar, 0);
    orientation = blade_scalar != null ? space.blade_coeff(blade_scalar) : 0;
    console.log(orientation);
    if (orientation < 0) {
      return [p1, p3, p2];
    } else {
      return [p1, p2, p3];
    }
  });
};

get_cube = function(options) {
  var bit_vertices, cells, n, projector, ref, rotation_dimensions, rotator, space, vertices;
  n = options.dimensions;
  space = new sph_ga([1, 1, 1], {
    conformal: true
  });
  rotation_dimensions = options.rotation_dimensions.slice(0, n);
  rotator = get_rotator(space, n, rotation_dimensions, options.rotation_speed);
  projector = get_projector(space, options.projection_distance, options.projection_angle);
  bit_vertices = (function() {
    var results = [];
    for (var l = 0, ref = 2 ** n; 0 <= ref ? l < ref : l > ref; 0 <= ref ? l++ : l--){ results.push(l); }
    return results;
  }).apply(this);
  vertices = bit_vertices.map(function(a) {
    return space.point(bits_to_array(a, n));
  });
  cells = get_cells(bit_vertices, n);
  cells = triangulate_squares(cells, n);
  cells = sort_vertices(space, n, vertices, cells);
  return {space, rotator, projector, vertices};
};

vertex_shader_source = `#version 300 es
precision highp float;
in vec4 position;
void main() {
  gl_Position = position;
}`;

fragment_shader_defaults = `#version 300 es
precision highp float;
out vec4 fragment_color;`;

fragment_shader_wireframe_source = fragment_shader_defaults + `void main() {
  fragment_color = vec4(1.0, 0.0, 0.0, 1.0);
}`;

fragment_shader_solid_source = fragment_shader_defaults + `void main() {
  fragment_color = vec4(1.0, 1.0, 1.0, 1.0);
}`;

gl_create_shader = function(gl, type, source) {
  var a;
  a = gl.createShader(gl[type]);
  gl.shaderSource(a, source);
  gl.compileShader(a);
  if (!gl.getShaderParameter(a, gl.COMPILE_STATUS)) {
    console.error(gl.getShaderInfoLog(a));
    gl.deleteShader(a);
  }
  return a;
};

gl_create_program = function(gl, vertex_shader, fragment_shader) {
  var a;
  a = gl.createProgram();
  gl.attachShader(a, vertex_shader);
  gl.attachShader(a, fragment_shader);
  gl.linkProgram(a);
  if (!gl.getProgramParameter(a, gl.LINK_STATUS)) {
    console.error(gl.getProgramInfoLog(program));
    gl.deleteProgram(a);
  }
  return a;
};

gl_initialize = function(canvas) {
  var fragment_shader_solid, fragment_shader_wireframe, gl, position_attribute_location, program_solid, program_wireframe, vertex_shader;
  gl = canvas.getContext("webgl2");
  if (!gl) {
    alert("unable to initialize webgl2. your browser may not support it.");
    return;
  }
  gl.viewport(0, 0, gl.drawingBufferWidth, gl.drawingBufferHeight);
  gl.clearColor(0, 0, 0, 1);
  gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer());
  gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, gl.createBuffer());
  vertex_shader = gl_create_shader(gl, "VERTEX_SHADER", vertex_shader_source);
  fragment_shader_wireframe = gl_create_shader(gl, "FRAGMENT_SHADER", fragment_shader_wireframe_source);
  fragment_shader_solid = gl_create_shader(gl, "FRAGMENT_SHADER", fragment_shader_solid_source);
  program_wireframe = gl_create_program(gl, vertex_shader, fragment_shader_wireframe);
  program_solid = gl_create_program(gl, vertex_shader, fragment_shader_solid);
  // link position variable to array_buffer
  position_attribute_location = gl.getAttribLocation(program_wireframe, "position");
  gl.enableVertexAttribArray(position_attribute_location);
  gl.vertexAttribPointer(position_attribute_location, 3, gl.FLOAT, false, 0, 0);
  gl.enable(gl.CULL_FACE);
  return gl;
};

render_rotating_cube = function(options) {
  var cube, draw, final_vertices, gl, n, on_frame, previous_time;
  // object -> interval
  // repeatedly draw and rotate a cube.
  // various vector formats are used:
  // - cell finding: integer bitvectors
  // - transformations: sph-ga vectors
  // - vertex sorting: integer arrays
  // - webgl: float32arrays
  n = options.dimensions;
  cube = get_cube(options);
  return;
  gl = gl_initialize(options.canvas);
  gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, indices, gl.STATIC_DRAW);
  final_vertices = new Float32Array(vertices.length);
  draw = function() {
    var i, l, ref;
    for (i = l = 0, ref = vertices.length; (0 <= ref ? l < ref : l > ref); i = 0 <= ref ? ++l : --l) {
      vertices[i] = transform(vertices[i]);
      final_vertices[i] = project(vertices[i]);
    }
    gl.bufferData(gl.ARRAY_BUFFER, vertices, gl.DYNAMIC_DRAW);
    return gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
  };
  //gl.useProgram program_wireframe
  //gl.drawElements gl.LINES, indices.length, gl.UNSIGNED_SHORT, 0
  //if false
  //  gl.useProgram program_solid
  //  gl.drawElements gl.TRIANGLES, faces.length, gl.UNSIGNED_SHORT, 0
  draw();
  options.canvas.addEventListener("click", function(event) {
    return draw();
  });
  previous_time = -options.refresh;
  on_frame = function(time) {
    if (options.refresh <= time - previous_time) {
      previous_time = time;
      draw();
    }
    return requestAnimationFrame(on_frame);
  };
  return requestAnimationFrame(on_frame);
};

node_run = function() {
  var cube, options;
  options = {
    dimensions: 3,
    rotation_dimensions: [1, 0, 1, 1],
    rotation_speed: 0.2,
    projection_distance: 3,
    projection_angle: Math.PI / 4
  };
  cube = get_cube(options);
  return console.log(cube);
};

node_run();
