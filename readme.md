# rotating n-cube projections using conformal geometric algebra and webgl
[demo](https://sph.mn/files/u/software/sourcecode/cga-hypercubes/src/main.html)
# formulas
## rotation
```
rotor = cos(step_angle / 2) - plane * sin(step_angle / 2)

p_next = rotor * p_current * inverse(rotor)
```
### variables
* `step_angle` = rotation angle per step (scalar)
* `plane` = unit euclidean bivector defining rotation plane
* `rotor` = rotor multivector for rotation
* `p_current` = conformal point multivector before rotation
* `p_next` = conformal point multivector after rotation

## perspective projection
projection is applied as a sequence of codimension-1 perspective stages.

for stage from dimension `m` to `m - 1`:
```
scale = depth[m] / (depth[m] - x_current[m])

x_next[i] = scale * x_current[i]
```
for `i` in `1 .. m - 1`.

apply for:
```
m = n, n - 1, ..., 3
```
final screen coordinates:
```
screen_point = [x_current[1], x_current[2]]
```
### variables
* `x_current` = euclidean coordinates of rotated point
* `x_next` = coordinates after one projection stage
* `depth[m]` = projection distance for stage `m`
* `scale` = perspective scale factor
* `n` = initial euclidean dimension

## orientation test
orientation is evaluated in final `2d` screen space.
```
signed_area = (b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1])

orientation = sign(signed_area)
```
### variables
* `a`, `b`, `c` = triangle vertices in `2d` screen coordinates
* `signed_area` = oriented area of triangle
* `sign(signed_area)` = signum of scalar (`+1`, `-1`, or `0`)

# info
* the compiled javascript files are under src/compiled/
* the source files are src/*.coffee (using [coffeescript](http://coffeescript.org/), "npm install coffeescript")
* deployment: make the project directory accessible via http using a web server then open main.html in a browser and an animation should appear

uses
* [sph-ga](https://github.com/sph-mn/sph-ga) (lgpl license)
* [crel](https://github.com/KoryNunn/crel) (mit license)
