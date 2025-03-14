// Generated by CoffeeScript 2.7.0
var ui_class;

ui_class = (function() {
  class ui_class {
    label(text, content) {
      var label;
      return label = crel("label", text, content);
    }

    false_if_nan(a) {
      if (isNaN(a)) {
        return false;
      } else {
        return a;
      }
    }

    reset() {
      var count, rotation_axes;
      // start rendering with a new configuration
      this.options.dimensions = Math.max(1, this.false_if_nan(parseInt(this.dom.dimensions.value)) || this.options.dimensions);
      if (7 < this.options.dimensions) {
        alert("unfortunately, the current maximum number of dimensions 7 because of limitations in a support library");
        this.dom.dimensions.value = 7;
        return;
      }
      if (!this.warning_shown && 6 === this.options.dimensions) {
        count = 2 ** this.options.dimensions;
        alert("increasing dimensions can easily overload the browser. now continuing to create " + count + " vertices", "notice");
        this.warning_shown = true;
      }
      this.options.rotation_dimensions = this.dom.rotation_axes.map(function(a) {
        if (a.checked) {
          return 1;
        } else {
          return 0;
        }
      });
      rotation_axes = document.getElementById("rotation_axes");
      rotation_axes.innerHTML = "";
      this.dom.rotation_axes = this.rotation_axes_new();
      this.dom.rotation_axes.forEach(function(a) {
        return rotation_axes.appendChild(a);
      });
      this.options.rotation_speed = Math.PI * (this.false_if_nan(parseFloat(this.dom.rotation_speed.value)) || this.options.rotation_speed);
      this.options.canvas = document.getElementsByTagName("canvas")[0];
      this.cube_interval && clearInterval(this.cube_interval);
      return this.cube_interval = this.draw(this.options);
    }

    rotation_axes_new() {
      // create a new array of checkboxes
      return Array(this.options.dimensions).fill(0).map((a, index) => {
        a = crel("input", {
          type: "checkbox",
          value: index
        });
        a.checked = !(this.options.rotation_dimensions[index] === 0);
        a.addEventListener("change", this.reset);
        return a;
      });
    }

    constructor(draw) {
      var container, dimensions, dimensions_label, rotation_axes, rotation_axes_div, rotation_speed, rotation_speed_label;
      this.reset = this.reset.bind(this);
      this.rotation_axes_new = this.rotation_axes_new.bind(this);
      // create input fields and container
      this.draw = draw;
      dimensions = crel("input", {
        type: "number",
        value: this.options.dimensions
      });
      rotation_speed = crel("input", {
        type: "number",
        step: "0.001",
        value: this.options.rotation_speed
      });
      rotation_axes = this.rotation_axes_new();
      rotation_axes_div = crel("div", this.label("rotate"), crel("span", {
        id: "rotation_axes"
      }, rotation_axes));
      rotation_speed_label = this.label("speed", rotation_speed);
      dimensions_label = this.label("dimensions", dimensions);
      this.dom = {
        dimensions: dimensions,
        rotation_axes: rotation_axes,
        rotation_speed: rotation_speed
      };
      [dimensions, rotation_speed].forEach((a) => {
        return a.addEventListener("change", this.reset);
      });
      container = crel("div", dimensions_label, rotation_axes_div, rotation_speed_label);
      document.getElementById("controls").appendChild(container);
      this.reset();
    }

  };

  // creates the html for the controls and default options
  ui_class.prototype.options = {
    dimensions: 4,
    // zero elements are not rotated
    rotation_dimensions: [1, 0, 1, 1],
    // in milliseconds
    refresh: 150,
    // in radians
    rotation_speed: 0.02,
    canvas_width: 1000,
    canvas_height: 800,
    projection_distance: 3,
    projection_angle: Math.PI / 4,
    light_position: [0, -1, 0]
  };

  ui_class.prototype.dom = {};

  ui_class.prototype.warning_shown = false;

  return ui_class;

}).call(this);
