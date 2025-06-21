# rotating hypercube projections using conformal geometric algebra on a webgl canvas

status: currently being migrated from canvas to webgl. the rotation axes controls are hidden because they are not migrated.

there is currently no point of reset, so the model might degenerate after a while because of floating point errors.

[demo](https://sph.mn/files/u/software/sourcecode/cga-hypercubes/src/main.html)

# formulas
currently used formulas.

## rotation
~~~
R = cos(ω/2) + B*sin(ω/2)
a′ = R a R^-1
~~~

### variables
* ω = rotation angle (scalar)
* B = unit bivector defining rotation plane
* R = rotor multivector for rotation
* a = multivector to be rotated

## perspective projection
~~~
R_persp = 1 + (1/(2 d)) * B′
P = R * R_persp
p_proj = P p P^-1
~~~

### variables
* d = projection distance (scalar)
* B′ = unit bivector normal to projection plane
* R_persp = rotor multivector for perspective projection
* P = combined rotor for rotation and projection
* p = conformal point multivector
* p_proj = projected point multivector

## orientation test
~~~
s = ((p1 ^ p2 ^ p3) . I)_0
orientation = sign(s)
~~~

### variables
* p1, p2, p3 = three conformal point multivectors
* ^ = exterior (wedge) product
* . = inner product
* I = pseudoscalar multivector (e1^e2^…^en^no^ni)
* (...)_0 = scalar part of a multivector
* sign(s) = signum of scalar s (±1 or 0)

# info
* the compiled javascript file is compiled/main.js
* the source file is main.coffee (using [coffeescript](http://coffeescript.org/), "npm install coffeescript")
* deployment: make the project directory accessible via http using a web server then open main.html in a browser and an animation should appear
* license: public domain

uses
* [sph-ga](https://github.com/sph-mn/sph-ga) (lgpl license)
* [crel](https://github.com/KoryNunn/crel) (mit license)
